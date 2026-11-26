import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/result.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/money.dart';
import '../../data/payments/payment_inbox_gateway.dart';
import '../../data/payments/platform_http_client.dart';
import '../entities/cart_item.dart';
import '../entities/paystack_credentials.dart';
import '../entities/sale.dart';
import 'checkout_service.dart';
import 'paystack_credentials_service.dart';

/// "M-Pesa Till/Paybill" at checkout: the customer paid the shop's OWN till or paybill, and the cashier picked their payment
/// (or typed its M-Pesa code). The sale is given its id and number first; the shop's server is asked to USE the code on that
/// sale - it says no when no such payment arrived, when it was for another amount, or when another sale already used it - and
/// only then is the sale saved, as an "M-Pesa (Manual)" sale with the code as its reference. One payment can never pay for two
/// sales, so this needs the internet. The same flow as the Lite till's (lite-core.js sellTill).
final tillSaleServiceProvider = Provider<TillSaleService>(
  (ref) => TillSaleService(
    loadCredentials: () => ref.read(paystackCredentialsServiceProvider).load(),
    gateway: ref.read(paymentInboxGatewayProvider),
    checkout: ref.read(checkoutServiceProvider),
    ids: ref.read(idGeneratorProvider),
  ),
);

/// The most M-Pesa payments one sale may be paid with (a customer who sent part of the money, then the rest).
const maxTillPaymentsPerSale = 5;

/// The M-Pesa codes in what the cashier typed or tapped: one, or several separated by commas or "+" (spaces and dashes
/// inside a code are left out, as for one code). Each once, in the order given. Empty when nothing was given; null when a
/// part is not a code.
List<String>? mpesaCodesIn(String typed) {
  final codes = <String>[];
  for (final part in typed.split(RegExp(r'[,+;\n]'))) {
    if (part.trim().isEmpty) continue;
    final code = normalizeMpesaCode(part);
    if (code == null) return null;
    if (!codes.contains(code)) codes.add(code);
  }
  return codes;
}

sealed class TillSaleOutcome {
  const TillSaleOutcome();
}

/// The sale is saved. [payments]: the customer's payment as the shop received it - two or more when they paid in parts.
class TillSaleDone extends TillSaleOutcome {
  const TillSaleDone(this.sale, this.payments);
  final Sale sale;
  final List<TillPayment> payments;

  /// What the customer paid in all; null when an amount could not be read.
  Money? get paid {
    var cents = 0;
    for (final payment in payments) {
      final amount = payment.amount;
      if (amount == null) return null;
      cents += amount.cents;
    }
    return Money(cents);
  }

  /// What to give back in cash when the customer paid more than the till part of the sale (the whole sale, or what the cash
  /// did not cover in a split sale); zero otherwise.
  Money get change {
    final paid = this.paid;
    final due = sale.gatewayPortion;
    if (paid == null || paid.cents <= due.cents) return const Money.zero();
    return paid - due;
  }
}

/// The customer paid MORE than the till part ([paid] > [total]), or the amount could not be read ([paid] null): nothing is
/// sold yet. Ask the cashier, then try again with acceptAmount. [total] is what the till payment had to cover: the whole sale,
/// or in a split sale ([split]) what the cash did not. [payments]: how many payments [paid] adds up.
class TillSaleNeedsConfirmation extends TillSaleOutcome {
  const TillSaleNeedsConfirmation({required this.paid, required this.total, this.split = false, this.payments = 1});
  final Money? paid;
  final Money total;
  final bool split;
  final int payments;
}

/// Nothing is sold; [message] says why in the cashier's words. [refreshList]: the list of payments has changed (the code
/// is used, or not there) and is worth loading again.
class TillSaleRefused extends TillSaleOutcome {
  const TillSaleRefused(this.message, {this.refreshList = false});
  final String message;
  final bool refreshList;
}

class TillSaleService {
  TillSaleService({
    required this.loadCredentials,
    required this.gateway,
    required this.checkout,
    required this.ids,
  });

  final Future<PaystackCredentials> Function() loadCredentials;
  final PaymentInboxGateway gateway;
  final CheckoutService checkout;
  final IdGenerator ids;

  static const offlineMessage =
      'Checking an M-Pesa payment needs the internet. Nothing was sold. Try again when this device is online, or take Cash.';

  Future<TillSaleOutcome> complete({
    required List<CartItem> cart,
    required Money discount,
    required String saleType,
    required String userId,
    required String typedCode,
    bool acceptAmount = false,
    // A split sale (the cart's "Till/Paybill" for the rest): the cash the customer already paid. The till payment then has
    // to cover only the rest. Null: the till payment covers the whole sale.
    Money? cashReceived,
    // The amounts of the payments that reached the shop, by code (the list in the cart). Needed when the customer paid in
    // two or more payments: each is then used on the sale for exactly what it was.
    Map<String, Money> knownAmounts = const {},
  }) async {
    final codes = mpesaCodesIn(typedCode);
    if (codes == null || codes.isEmpty) {
      return const TillSaleRefused(
        'Pick the customer\'s payment, or type its M-Pesa code (the 10 letters and numbers at the start of the message).',
      );
    }
    if (codes.length > maxTillPaymentsPerSale) {
      return const TillSaleRefused('One sale can be paid with at most $maxTillPaymentsPerSale M-Pesa payments.');
    }
    final credentials = await loadCredentials();
    if (!credentials.isConfigured) {
      return const TillSaleRefused(
        'This device is not connected to the shop sync service yet, so M-Pesa payments cannot be checked. '
        'Open Settings > Sync & Invites while online, then try again.',
      );
    }
    // Everything a sale needs is checked before the shop is asked: a cart that cannot be sold never takes a code.
    final totals = await checkout.previewTotals(cart, discount);
    if (totals case Failure(:final message)) return TillSaleRefused(message);
    final total = (totals as Ok<CheckoutTotals>).value.total;
    if (total.cents < 1) {
      return const TillSaleRefused('The total is zero, so there is nothing to charge.');
    }
    if (cashReceived != null && (cashReceived.cents < 1 || cashReceived.cents >= total.cents)) {
      return const TillSaleRefused('The cash part must be more than zero and less than the total.');
    }
    final due = cashReceived == null ? total : total - cashReceived;
    if (codes.length > 1) {
      return _completeWithSeveral(
        codes: codes,
        knownAmounts: knownAmounts,
        credentials: credentials,
        due: due,
        acceptAmount: acceptAmount,
        save: (saleId, saleNumber) => checkout.checkout(
          cart: cart,
          discount: discount,
          saleType: saleType,
          paymentMethod: 'mpesa_manual',
          referenceNote: codes.join(', '),
          userId: userId,
          cashReceived: cashReceived,
          saleId: saleId,
          saleNumber: saleNumber,
        ),
        split: cashReceived != null,
      );
    }
    final code = codes.single;

    final saleId = ids.newId();
    final saleNumber = await checkout.generateSaleNumber();
    final TillPayment payment;
    try {
      payment = await gateway.claim(
        baseUrl: credentials.baseUrl,
        apiKey: credentials.apiKey,
        code: code,
        saleId: saleId,
        saleNumber: saleNumber,
        amount: due,
        acceptAmount: acceptAmount,
      );
    } on PaystackOfflineException {
      return const TillSaleRefused(offlineMessage);
    } on TillClaimRefused catch (refused) {
      return _refusal(refused, due, split: cashReceived != null);
    } on PaystackException catch (e) {
      // The answer could not be read: the code may be held for this sale or not. Give it back so it can be used again.
      await gateway.release(baseUrl: credentials.baseUrl, apiKey: credentials.apiKey, code: code, saleId: saleId);
      return TillSaleRefused('${e.message} Nothing was sold. Try again.');
    }

    final saved = await checkout.checkout(
      cart: cart,
      discount: discount,
      saleType: saleType,
      paymentMethod: 'mpesa_manual',
      referenceNote: code,
      userId: userId,
      cashReceived: cashReceived,
      saleId: saleId,
      saleNumber: saleNumber,
    );
    switch (saved) {
      case Ok(:final value):
        return TillSaleDone(value, [payment]);
      case Failure(:final message):
        // The shop holds the code for a sale that was not saved (stock ran out meanwhile, say): give it back.
        await gateway.release(baseUrl: credentials.baseUrl, apiKey: credentials.apiKey, code: code, saleId: saleId);
        return TillSaleRefused('$message Nothing was sold, and the M-Pesa payment can still be used.');
    }
  }

  /// The customer paid in two or more payments (say 200, then 50 for a sale of 250). Each must be one of the payments that
  /// reached the shop, so its amount is known; together they must cover [due], with none the sale does not need; more than
  /// [due] is asked about first (the rest goes back in cash). Each code is then used on the sale for exactly its own amount
  /// - the shop refuses a code another sale used - and only then is the sale saved, with every code as its reference. When
  /// any code is refused, or the sale cannot be saved, the codes already used are given back: nothing is sold, and the
  /// payments can still be used.
  Future<TillSaleOutcome> _completeWithSeveral({
    required List<String> codes,
    required Map<String, Money> knownAmounts,
    required PaystackCredentials credentials,
    required Money due,
    required bool acceptAmount,
    required Future<Result<Sale>> Function(String saleId, String saleNumber) save,
    required bool split,
  }) async {
    final amounts = <Money>[];
    for (final code in codes) {
      final amount = knownAmounts[code];
      if (amount == null) {
        return TillSaleRefused(
          '$code is not one of the payments in the list (or its amount could not be read). When the customer paid in two '
          'or more payments, tap each of them in the list.',
          refreshList: true,
        );
      }
      amounts.add(amount);
    }
    final paid = Money(amounts.fold(0, (sum, amount) => sum + amount.cents));
    final owed = split ? 'the ${due.format()} still owed' : 'this sale (${due.format()})';
    if (paid.cents < due.cents) {
      return TillSaleRefused(
        'These ${codes.length} payments add up to ${paid.format()}, which is ${(due - paid).format()} less than $owed. '
        'Tap the customer\'s other payment too.',
      );
    }
    for (var i = 0; i < codes.length; i++) {
      if (paid.cents - amounts[i].cents >= due.cents) {
        return TillSaleRefused(
          'This sale does not need all of these payments: without ${codes[i]} (${amounts[i].format()}) they still cover '
          '$owed. Tap it again to leave it out.',
        );
      }
    }
    if (paid.cents > due.cents && !acceptAmount) {
      return TillSaleNeedsConfirmation(paid: paid, total: due, split: split, payments: codes.length);
    }

    final saleId = ids.newId();
    final saleNumber = await checkout.generateSaleNumber();
    final used = <String>[];
    final payments = <TillPayment>[];
    Future<void> giveBack() async {
      for (final code in used) {
        try {
          await gateway.release(baseUrl: credentials.baseUrl, apiKey: credentials.apiKey, code: code, saleId: saleId);
        } on Object {
          // Best effort: a code still held shows as used on a sale that does not exist, and the shop can free it.
        }
      }
    }

    for (var i = 0; i < codes.length; i++) {
      final code = codes[i];
      try {
        payments.add(await gateway.claim(
          baseUrl: credentials.baseUrl,
          apiKey: credentials.apiKey,
          code: code,
          saleId: saleId,
          saleNumber: saleNumber,
          amount: amounts[i],
        ));
        used.add(code);
      } on PaystackOfflineException {
        await giveBack();
        return const TillSaleRefused(offlineMessage);
      } on TillClaimRefused catch (refused) {
        await giveBack();
        return switch (refused.reason) {
          'not_received' => TillSaleRefused(
              'No M-Pesa payment with the code $code has reached the shop yet. Check the code, or tap the payments in the '
              'list.',
              refreshList: true,
            ),
          'amount_differs' || 'amount_unknown' => TillSaleRefused(
              'The payment $code is not for the amount the list showed. Refresh the list and tap the payments again.',
              refreshList: true,
            ),
          'used' => TillSaleRefused(refused.message, refreshList: true),
          _ => TillSaleRefused(refused.message),
        };
      } on PaystackException catch (e) {
        // The answer could not be read: this code may be held for the sale or not. Give it back with the others.
        used.add(code);
        await giveBack();
        return TillSaleRefused('${e.message} Nothing was sold. Try again.');
      }
    }

    switch (await save(saleId, saleNumber)) {
      case Ok(:final value):
        return TillSaleDone(value, payments);
      case Failure(:final message):
        await giveBack();
        return TillSaleRefused('$message Nothing was sold, and the M-Pesa payments can still be used.');
    }
  }

  TillSaleOutcome _refusal(TillClaimRefused refused, Money total, {required bool split}) {
    switch (refused.reason) {
      case 'not_received':
        return const TillSaleRefused(
          'No M-Pesa payment with this code has reached the shop yet. Check the code, or wait a few seconds after the customer pays and try again.',
          refreshList: true,
        );
      case 'amount_differs':
        final paid = refused.paidAmount;
        if (paid != null && paid.cents < total.cents) {
          return TillSaleRefused(split
              ? 'The customer paid ${paid.format()}, which is ${(total - paid).format()} less than the ${total.format()} '
                  'still owed. Use a payment that covers the rest of the sale.'
              : 'The customer paid ${paid.format()}, which is ${(total - paid).format()} less than this sale (${total.format()}). '
                  'Use a payment that covers the whole sale.');
        }
        return TillSaleNeedsConfirmation(paid: paid, total: total, split: split);
      case 'amount_unknown':
        return TillSaleNeedsConfirmation(paid: null, total: total, split: split);
      case 'used':
        return TillSaleRefused(refused.message, refreshList: true);
      default:
        return TillSaleRefused(refused.message);
    }
  }
}
