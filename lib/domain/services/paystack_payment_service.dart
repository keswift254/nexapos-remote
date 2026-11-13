import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/result.dart';
import '../../core/utils/money.dart';
import '../../data/payments/paystack_gateway.dart';
import '../entities/cart_item.dart';
import '../entities/sale.dart';
import 'checkout_service.dart';
import 'paystack_credentials_service.dart';

part 'paystack_payment_service.g.dart';

@Riverpod(keepAlive: true)
PaystackPaymentService paystackPaymentService(Ref ref) {
  return PaystackPaymentService(
    ref.watch(paystackGatewayProvider),
    ref.watch(paystackCredentialsServiceProvider),
    ref.watch(checkoutServiceProvider),
  );
}

class PaystackCheckoutSession {
  final Sale sale;

  /// The payment page to open - empty for an M-Pesa prompt, which goes straight to the customer's phone and opens
  /// no page at all ([viaPrompt]).
  final String authorizationUrl;
  final String reference;

  /// True when this sale was started by sending an M-Pesa prompt to [phone] instead of opening a payment page.
  final bool viaPrompt;
  final String phone;

  const PaystackCheckoutSession({
    required this.sale,
    required this.authorizationUrl,
    required this.reference,
    this.viaPrompt = false,
    this.phone = '',
  });
}

/// Paystack's words for a prompt that is over without being paid: the customer cancelled it, it ran out of time,
/// or it was reversed. (`ongoing` and `pay_offline` mean it is still waiting.)
const _promptEndedStatuses = {'failed', 'abandoned', 'reversed', 'cancelled'};

/// Whether [text] looks like a phone number that an M-Pesa prompt can be sent to (the server cleans it up and does
/// the final check): 9 to 13 digits once spaces, dashes and a leading + are ignored.
bool looksLikeMpesaNumber(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length >= 9 && digits.length <= 13;
}

sealed class PaystackPollOutcome {
  const PaystackPollOutcome();
}

class PaystackPollPaid extends PaystackPollOutcome {
  final Sale sale;
  const PaystackPollPaid(this.sale);
}

class PaystackPollWaiting extends PaystackPollOutcome {
  const PaystackPollWaiting();
}

/// An M-Pesa prompt that is over without being paid (see [_promptEndedStatuses]). The sale is still recorded as
/// pending with its stock reserved: only the cashier ends it, by sending the prompt again or cancelling the sale.
class PaystackPollEnded extends PaystackPollOutcome {
  const PaystackPollEnded();
}

/// What sending a declined prompt again came to.
sealed class PaystackRetryOutcome {
  const PaystackRetryOutcome();
}

/// The customer had approved it after all: the sale is paid and nothing is cancelled.
class PaystackRetryPaid extends PaystackRetryOutcome {
  final Sale sale;
  const PaystackRetryPaid(this.sale);
}

/// The prompt is not over (or could not be checked just now), so nothing was cancelled.
class PaystackRetryNotYet extends PaystackRetryOutcome {
  const PaystackRetryNotYet();
}

/// The first sale was cancelled (stock back) and its contents are handed back to put in the cart again.
class PaystackRetryRestored extends PaystackRetryOutcome {
  final List<CartItem> items;
  final Money discount;
  final String saleType;
  final Money? cashReceived;
  const PaystackRetryRestored({required this.items, required this.discount, required this.saleType, this.cashReceived});
}

class PaystackRetryFailed extends PaystackRetryOutcome {
  final String message;
  const PaystackRetryFailed(this.message);
}

/// What one reconcile pass found: sales still waiting on the customer, and
/// sales it just found paid.
typedef PaystackReconcileReport = ({List<Sale> stillPending, List<Sale> nowPaid});

/// Orchestrates a real Paystack payment: create the gateway checkout
/// first, and only reserve stock + record the sale (via CheckoutService)
/// once Paystack has actually accepted it - see beginPaystackSale's doc
/// comment for why the ordering matters. Never touches Drift directly;
/// all local persistence goes through CheckoutService so this class
/// stays about "talk to Paystack", not "what a sale is".
class PaystackPaymentService {
  final PaystackGateway _gateway;
  final PaystackCredentialsService _credentials;
  final CheckoutService _checkoutService;

  PaystackPaymentService(this._gateway, this._credentials, this._checkoutService);

  Future<Result<PaystackCheckoutSession>> start({
    required List<CartItem> cart,
    required Money discount,
    String customerName = '',
    String customerPhone = '',
    required String saleType,
    required String userId,
    // Set only for a split cash+M-Pesa sale (cart_screen.dart's "Send
    // M-Pesa prompt for remaining balance") - Paystack is asked to
    // charge just the shortfall (total - cashReceived), never the full
    // total on top of cash already collected. Null for a plain
    // Paystack sale, which charges the full total exactly as before.
    Money? cashReceived,
    // When given, an M-Pesa prompt is sent to this number and NO payment page is used. Left empty, the payment page
    // (card or M-Pesa) is opened as before.
    String mpesaPhone = '',
  }) async {
    final prompt = mpesaPhone.trim();
    if (prompt.isNotEmpty && !looksLikeMpesaNumber(prompt)) {
      return const Result.failure('Enter the customer\'s M-Pesa number, like 0712 345 678.');
    }
    final credentials = await _credentials.load();
    if (!credentials.isConfigured) {
      return const Result.failure('Payment collection is not set up yet. Complete Payments & Payouts first.');
    }
    if (prompt.isNotEmpty && credentials.currency.toUpperCase() != 'KES') {
      return const Result.failure('M-Pesa prompts are only for payments in KES.');
    }

    final totalsResult = await _checkoutService.previewTotals(cart, discount);
    final CheckoutTotals totals;
    switch (totalsResult) {
      case Ok<CheckoutTotals>(:final value):
        totals = value;
      case Failure<CheckoutTotals>(:final message):
        return Result.failure(message);
    }
    if (totals.total.isZero) {
      return const Result.failure('Add at least one product to the sale.');
    }
    final chargeAmount = cashReceived == null ? totals.total : totals.total - cashReceived;
    if (cashReceived != null && !chargeAmount.isNegative && chargeAmount.isZero) {
      return const Result.failure('Cash received already covers the full total - complete the sale as cash instead.');
    }
    if (chargeAmount.isNegative) {
      return const Result.failure('Cash received is more than the total - complete the sale as cash instead.');
    }

    final saleNumber = await _checkoutService.generateSaleNumber();

    final String authorizationUrl;
    final String gatewayReference;
    try {
      if (prompt.isNotEmpty) {
        final charge = await _gateway.chargeMobileMoney(
          baseUrl: credentials.baseUrl,
          apiKey: credentials.apiKey,
          amount: chargeAmount,
          reference: saleNumber,
          currency: credentials.currency,
          phone: prompt,
        );
        authorizationUrl = '';
        gatewayReference = charge.reference;
      } else {
        final init = await _gateway.initialize(
          baseUrl: credentials.baseUrl,
          apiKey: credentials.apiKey,
          amount: chargeAmount,
          reference: saleNumber,
          email: credentials.defaultEmail,
          currency: credentials.currency,
        );
        authorizationUrl = init.authorizationUrl;
        gatewayReference = init.reference;
      }
    } on PaystackOfflineException catch (e) {
      // Not "check your internet connection" - a real report confirmed this
      // fires just as easily when the device's own connection is fine and
      // the payments SERVER is the one having trouble (its own backend was
      // unreachable, not this device), and telling someone to fix their
      // internet when it's actually fine helps nobody find the real cause.
      return Result.failure(
        e.timedOut
            ? 'The payments server is taking a while to respond. Try again in a moment.'
            : 'Could not reach the payments server right now. Try again in a moment.',
      );
    } on PaystackException catch (e) {
      return Result.failure(e.message);
    }

    final saleResult = await _checkoutService.beginPaystackSale(
      cart: cart,
      discount: discount,
      customerName: customerName,
      customerPhone: prompt.isNotEmpty ? prompt : customerPhone,
      saleType: saleType,
      userId: userId,
      saleNumber: saleNumber,
      paystackReference: gatewayReference,
      cashReceived: cashReceived,
    );

    return saleResult.when(
      ok: (sale) => Result.ok(PaystackCheckoutSession(
        sale: sale,
        authorizationUrl: authorizationUrl,
        reference: gatewayReference,
        viaPrompt: prompt.isNotEmpty,
        phone: prompt,
      )),
      failure: Result.failure,
    );
  }

  /// Polls Paystack once. With no webhook/callback infrastructure on a
  /// phone, the only trustworthy terminal state this method will ever
  /// declare on its own is "Paystack confirmed the payment" - anything
  /// else (still pending, or a transient network hiccup mid-poll) comes
  /// back as [PaystackPollWaiting] so the UI just tries again next tick.
  /// The only way to reach a cancelled/stock-restored state is the
  /// cashier explicitly calling [cancel].
  Future<PaystackPollOutcome> poll(String saleId, String reference, Money expectedAmount, {bool viaPrompt = false}) async {
    final credentials = await _credentials.load();
    if (!credentials.isConfigured) return const PaystackPollWaiting();

    try {
      final verify = await _gateway.verify(
        baseUrl: credentials.baseUrl,
        apiKey: credentials.apiKey,
        reference: reference,
        expectedAmount: expectedAmount,
        currency: credentials.currency,
      );
      if (!verify.success) {
        // Only an M-Pesa prompt can be "over": on a payment page the customer simply is not done yet.
        return viaPrompt && _promptEndedStatuses.contains(verify.status) ? const PaystackPollEnded() : const PaystackPollWaiting();
      }
      final result = await _checkoutService.finalizePaystackSale(saleId);
      final PaystackPollOutcome outcome =
          result.when(ok: PaystackPollPaid.new, failure: (_) => const PaystackPollWaiting());
      return outcome;
    } on PaystackOfflineException {
      return const PaystackPollWaiting();
    } on PaystackException {
      return const PaystackPollWaiting();
    }
  }

  Future<Result<void>> cancel(String saleId) => _checkoutService.cancelPaystackSale(saleId);

  /// "Send the prompt again": the customer declined or let the first one run out. One last look first - they may
  /// have approved just now, and then it is a paid sale and nothing is cancelled. Only when the prompt is really
  /// over is the first sale cancelled (stock back) and its contents handed back to put in the cart again, so the
  /// customer is never charged twice and nothing has to be typed again.
  Future<PaystackRetryOutcome> retryPrompt(Sale sale, String reference) async {
    final last = await poll(sale.id, reference, sale.gatewayPortion, viaPrompt: true);
    if (last is PaystackPollPaid) return PaystackRetryPaid(last.sale);
    if (last is! PaystackPollEnded) return const PaystackRetryNotYet();
    final items = await _checkoutService.cartItemsForSale(sale.id);
    final cancelled = await _checkoutService.cancelPaystackSale(sale.id);
    return cancelled.when<PaystackRetryOutcome>(
      ok: (_) => PaystackRetryRestored(
        items: items,
        discount: sale.discount,
        saleType: sale.saleType,
        cashReceived: sale.cashReceived,
      ),
      failure: PaystackRetryFailed.new,
    );
  }

  /// Re-polls a single sale found via [reconcilePendingSales] - for the
  /// pending-sales screen's per-row "Check now", so it only needs a
  /// [Sale] rather than also having to know about gateway references.
  Future<PaystackPollOutcome> checkPending(Sale sale) async {
    final reference = await _checkoutService.paystackReferenceFor(sale.id);
    if (reference == null) return const PaystackPollWaiting();
    return poll(sale.id, reference, sale.gatewayPortion);
  }

  /// Called once at app startup: a pending paystack sale can only be
  /// left stranded by the app being killed outright while
  /// PaystackWaitingScreen was still polling it (the PopScope guard
  /// catches ordinary back-navigation) - the most common real case is
  /// the customer actually paid and we just never found out. Silently
  /// re-polling and finalizing those here means the cashier usually
  /// never sees anything; only sales that still don't verify are handed
  /// back for the dashboard to surface, since those need a human
  /// decision (keep waiting vs. cancel and restore stock).
  Future<List<Sale>> reconcilePendingSales() async =>
      (await reconcileAndReport()).stillPending;

  /// [reconcilePendingSales], also reporting the sales this pass found paid -
  /// the cashier may have been away (the page reloaded after the payment
  /// page, the app restarted) and should be told, not left to wonder.
  Future<PaystackReconcileReport> reconcileAndReport() async {
    // pendingPaystackSales() now also returns stranded intasend sales
    // (see that method's doc) - filtered out here since a Paystack
    // reference can't be verified against IntaSend's API.
    final pending = (await _checkoutService.pendingPaystackSales())
        .where((sale) => sale.paymentMethod == 'paystack')
        .toList();
    if (pending.isEmpty) return (stillPending: const <Sale>[], nowPaid: const <Sale>[]);

    // Polled in parallel, not sequentially - each sale is an independent
    // network round trip against an unrelated reference, so N pending
    // sales shouldn't cost N times the wait (especially painful right
    // after a cold start on the platform's Render free tier, where a
    // single poll can already take tens of seconds).
    final results = await Future.wait(
      pending.map<Future<({Sale sale, bool resolved, Sale? paidSale})>>((sale) async {
        final reference = await _checkoutService.paystackReferenceFor(sale.id);
        if (reference == null) return (sale: sale, resolved: false, paidSale: null);
        final outcome = await poll(sale.id, reference, sale.gatewayPortion);
        return (
          sale: sale,
          resolved: outcome is PaystackPollPaid,
          // Only a sale that really is paid is announced; one that was
          // cancelled in the meantime is simply no longer pending.
          paidSale: outcome is PaystackPollPaid && outcome.sale.status == 'paid'
              ? outcome.sale
              : null,
        );
      }),
    );
    return (
      stillPending: [
        for (final result in results)
          if (!result.resolved) result.sale,
      ],
      nowPaid: [
        for (final result in results)
          if (result.paidSale != null) result.paidSale!,
      ],
    );
  }
}
