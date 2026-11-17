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

sealed class TillSaleOutcome {
  const TillSaleOutcome();
}

/// The sale is saved. [payment] is the customer's payment as the shop received it.
class TillSaleDone extends TillSaleOutcome {
  const TillSaleDone(this.sale, this.payment);
  final Sale sale;
  final TillPayment payment;

  /// What to give back in cash when the customer paid more than the sale (zero otherwise).
  Money get change {
    final paid = payment.amount;
    if (paid == null || paid.cents <= sale.total.cents) return const Money.zero();
    return paid - sale.total;
  }
}

/// The customer paid MORE than the sale ([paid] > [total]), or the amount could not be read ([paid] null): nothing is sold
/// yet. Ask the cashier, then try again with acceptAmount.
class TillSaleNeedsConfirmation extends TillSaleOutcome {
  const TillSaleNeedsConfirmation({required this.paid, required this.total});
  final Money? paid;
  final Money total;
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
  }) async {
    final code = normalizeMpesaCode(typedCode);
    if (code == null) {
      return const TillSaleRefused(
        'Pick the customer\'s payment, or type its M-Pesa code (the 10 letters and numbers at the start of the message).',
      );
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
        amount: total,
        acceptAmount: acceptAmount,
      );
    } on PaystackOfflineException {
      return const TillSaleRefused(offlineMessage);
    } on TillClaimRefused catch (refused) {
      return _refusal(refused, total);
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
      saleId: saleId,
      saleNumber: saleNumber,
    );
    switch (saved) {
      case Ok(:final value):
        return TillSaleDone(value, payment);
      case Failure(:final message):
        // The shop holds the code for a sale that was not saved (stock ran out meanwhile, say): give it back.
        await gateway.release(baseUrl: credentials.baseUrl, apiKey: credentials.apiKey, code: code, saleId: saleId);
        return TillSaleRefused('$message Nothing was sold, and the M-Pesa payment can still be used.');
    }
  }

  TillSaleOutcome _refusal(TillClaimRefused refused, Money total) {
    switch (refused.reason) {
      case 'not_received':
        return const TillSaleRefused(
          'No M-Pesa payment with this code has reached the shop yet. Check the code, or wait a few seconds after the customer pays and try again.',
          refreshList: true,
        );
      case 'amount_differs':
        final paid = refused.paidAmount;
        if (paid != null && paid.cents < total.cents) {
          return TillSaleRefused(
            'The customer paid ${paid.format()}, which is ${(total - paid).format()} less than this sale (${total.format()}). '
            'Use a payment that covers the whole sale.',
          );
        }
        return TillSaleNeedsConfirmation(paid: paid, total: total);
      case 'amount_unknown':
        return TillSaleNeedsConfirmation(paid: null, total: total);
      case 'used':
        return TillSaleRefused(refused.message, refreshList: true);
      default:
        return TillSaleRefused(refused.message);
    }
  }
}
