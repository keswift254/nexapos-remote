import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/result.dart';
import '../../core/utils/money.dart';
import '../../data/payments/intasend_gateway.dart';
import '../entities/cart_item.dart';
import '../entities/sale.dart';
import 'checkout_service.dart';
import 'paystack_credentials_service.dart';

part 'intasend_payment_service.g.dart';

@Riverpod(keepAlive: true)
IntaSendPaymentService intaSendPaymentService(Ref ref) {
  return IntaSendPaymentService(
    ref.watch(intaSendGatewayProvider),
    ref.watch(paystackCredentialsServiceProvider),
    ref.watch(checkoutServiceProvider),
  );
}

class IntaSendCheckoutSession {
  final Sale sale;
  final String reference;
  final String phoneNumber;

  const IntaSendCheckoutSession({required this.sale, required this.reference, required this.phoneNumber});
}

sealed class IntaSendPollOutcome {
  const IntaSendPollOutcome();
}

class IntaSendPollPaid extends IntaSendPollOutcome {
  final Sale sale;
  const IntaSendPollPaid(this.sale);
}

class IntaSendPollWaiting extends IntaSendPollOutcome {
  const IntaSendPollWaiting();
}

/// IntaSend's sibling of PaystackPaymentService: collects a payment via
/// a direct M-Pesa STK push (no checkout page to open - the prompt goes
/// straight to the customer's phone), reserving stock only once IntaSend
/// has actually accepted the request. Reuses PaystackCredentialsService
/// for baseUrl/apiKey since both gateways are proxied through the same
/// operator backend with the same device Bearer token - see that
/// class's doc. Also reuses CheckoutService's finalize/cancel/pending
/// lookups, which are gateway-agnostic despite their paystack-flavored
/// names (see checkout_service.dart's doc comments on each).
class IntaSendPaymentService {
  final IntaSendGateway _gateway;
  final PaystackCredentialsService _credentials;
  final CheckoutService _checkoutService;

  IntaSendPaymentService(this._gateway, this._credentials, this._checkoutService);

  Future<Result<IntaSendCheckoutSession>> start({
    required List<CartItem> cart,
    required Money discount,
    String customerName = '',
    required String customerPhone,
    required String saleType,
    required String userId,
  }) async {
    final credentials = await _credentials.load();
    if (!credentials.isConfigured) {
      return const Result.failure('Payments are not set up yet. Complete Payment Settings first.');
    }

    final phone = _normalizeKenyanPhone(customerPhone);
    if (phone == null) {
      return const Result.failure('Enter the customer\'s M-Pesa number (e.g. 07XX XXX XXX) to send the prompt.');
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

    final saleNumber = await _checkoutService.generateSaleNumber();

    final IntaSendCollectResult collected;
    try {
      collected = await _gateway.collect(
        baseUrl: credentials.baseUrl,
        apiKey: credentials.apiKey,
        amount: totals.total,
        reference: saleNumber,
        phoneNumber: phone,
        name: customerName.trim().isEmpty ? null : customerName.trim(),
      );
    } on PaystackOfflineException {
      return const Result.failure('Could not reach the payments server. Check your internet connection and try again.');
    } on PaystackException catch (e) {
      return Result.failure(e.message);
    }

    final saleResult = await _checkoutService.beginIntaSendSale(
      cart: cart,
      discount: discount,
      customerName: customerName,
      customerPhone: phone,
      saleType: saleType,
      userId: userId,
      saleNumber: saleNumber,
      intasendReference: collected.reference,
    );

    return saleResult.when(
      ok: (sale) => Result.ok(IntaSendCheckoutSession(sale: sale, reference: collected.reference, phoneNumber: phone)),
      failure: Result.failure,
    );
  }

  /// Same "only a real confirmed payment is ever treated as final"
  /// contract as PaystackPaymentService.poll - see that method's doc.
  Future<IntaSendPollOutcome> poll(String saleId, String reference, Money expectedAmount) async {
    final credentials = await _credentials.load();
    if (!credentials.isConfigured) return const IntaSendPollWaiting();

    try {
      final verify = await _gateway.verify(
        baseUrl: credentials.baseUrl,
        apiKey: credentials.apiKey,
        reference: reference,
        expectedAmount: expectedAmount,
      );
      if (!verify.success) return const IntaSendPollWaiting();
      final result = await _checkoutService.finalizePaystackSale(saleId);
      final IntaSendPollOutcome outcome =
          result.when(ok: IntaSendPollPaid.new, failure: (_) => const IntaSendPollWaiting());
      return outcome;
    } on PaystackOfflineException {
      return const IntaSendPollWaiting();
    } on PaystackException {
      return const IntaSendPollWaiting();
    }
  }

  Future<Result<void>> cancel(String saleId) =>
      _checkoutService.cancelPaystackSale(saleId, reason: 'IntaSend payment not completed');

  Future<IntaSendPollOutcome> checkPending(Sale sale) async {
    final reference = await _checkoutService.intasendReferenceFor(sale.id);
    if (reference == null) return const IntaSendPollWaiting();
    return poll(sale.id, reference, sale.total);
  }

  /// Same startup-recovery role as PaystackPaymentService.
  /// reconcilePendingSales, filtered to this gateway's own sales - the
  /// shared pendingPaystackSales() query now returns both gateways'
  /// stranded sales, and a Paystack reference can't be verified against
  /// IntaSend's API or vice versa.
  Future<List<Sale>> reconcilePendingSales() async {
    final pending = (await _checkoutService.pendingPaystackSales())
        .where((sale) => sale.paymentMethod == 'intasend')
        .toList();
    if (pending.isEmpty) return const [];

    final results = await Future.wait(
      pending.map((sale) async {
        final reference = await _checkoutService.intasendReferenceFor(sale.id);
        if (reference == null) return sale;
        final outcome = await poll(sale.id, reference, sale.total);
        return outcome is IntaSendPollPaid ? null : sale;
      }),
    );
    return results.whereType<Sale>().toList();
  }
}

/// IntaSend's M-Pesa STK push needs a real Kenyan MSISDN in 254...
/// international form. Accepts the shapes a cashier is likely to type
/// (07xx..., 01xx..., +254 7xx..., with spaces/dashes) and normalizes
/// them; returns null for anything that still doesn't look like a valid
/// number, so [start] can reject before ever calling the gateway.
String? _normalizeKenyanPhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.startsWith('+')) digits = digits.substring(1);
  if (digits.startsWith('0')) digits = '254${digits.substring(1)}';
  if (digits.startsWith('7') || digits.startsWith('1')) digits = '254$digits';
  if (!RegExp(r'^254\d{9}$').hasMatch(digits)) return null;
  return digits;
}
