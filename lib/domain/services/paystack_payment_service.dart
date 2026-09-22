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
  final String authorizationUrl;
  final String reference;

  const PaystackCheckoutSession({required this.sale, required this.authorizationUrl, required this.reference});
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
  }) async {
    final credentials = await _credentials.load();
    if (!credentials.isConfigured) {
      return const Result.failure('Payment collection is not set up yet. Complete Payment Settings first.');
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

    final PaystackInitResult init;
    try {
      init = await _gateway.initialize(
        baseUrl: credentials.baseUrl,
        apiKey: credentials.apiKey,
        amount: chargeAmount,
        reference: saleNumber,
        email: credentials.defaultEmail,
        currency: credentials.currency,
      );
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
      customerPhone: customerPhone,
      saleType: saleType,
      userId: userId,
      saleNumber: saleNumber,
      paystackReference: init.reference,
      cashReceived: cashReceived,
    );

    return saleResult.when(
      ok: (sale) => Result.ok(PaystackCheckoutSession(
        sale: sale,
        authorizationUrl: init.authorizationUrl,
        reference: init.reference,
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
  Future<PaystackPollOutcome> poll(String saleId, String reference, Money expectedAmount) async {
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
      if (!verify.success) return const PaystackPollWaiting();
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
  Future<List<Sale>> reconcilePendingSales() async {
    // pendingPaystackSales() now also returns stranded intasend sales
    // (see that method's doc) - filtered out here since a Paystack
    // reference can't be verified against IntaSend's API.
    final pending = (await _checkoutService.pendingPaystackSales())
        .where((sale) => sale.paymentMethod == 'paystack')
        .toList();
    if (pending.isEmpty) return const [];

    // Polled in parallel, not sequentially - each sale is an independent
    // network round trip against an unrelated reference, so N pending
    // sales shouldn't cost N times the wait (especially painful right
    // after a cold start on the platform's Render free tier, where a
    // single poll can already take tens of seconds).
    final results = await Future.wait(
      pending.map((sale) async {
        final reference = await _checkoutService.paystackReferenceFor(sale.id);
        if (reference == null) return sale;
        final outcome = await poll(sale.id, reference, sale.gatewayPortion);
        return outcome is PaystackPollPaid ? null : sale;
      }),
    );
    return results.whereType<Sale>().toList();
  }
}
