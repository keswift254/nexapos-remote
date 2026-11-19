import '../../core/utils/money.dart';
import '../../data/payments/payment_inbox_gateway.dart';

/// A payment newer than this may complete a sale by itself; an older one is only suggested (it may be an earlier
/// customer's). The same rule as NexaPOS Lite's (lite-core.js TILL_AUTO_MINUTES).
const tillAutoWindow = Duration(minutes: 10);

/// Which of the unused payments fit a sale (see [tillMatches]).
class TillMatches {
  const TillMatches({required this.matches, required this.others, this.auto});

  /// The payments of exactly the sale total, newest first (shown at checkout).
  final List<TillPayment> matches;

  /// Every other payment: another amount, or an amount that could not be read (shown only when asked for).
  final List<TillPayment> others;

  /// The payment the sale completes with by itself, or null: the ONLY one of the sale total, and new.
  final TillPayment? auto;
}

/// Sorts the unused [payments] (newest first, as the shop sends them) for a sale of [total] at [now].
///
/// Two or more payments of the same amount are for the cashier to choose from; a lone payment older than
/// [tillAutoWindow] may be an earlier customer's, so it is only suggested. A payment that looks newer than [now] (this
/// device's clock is slow) counts as new; one with no arrival time never completes a sale by itself.
TillMatches tillMatches(List<TillPayment> payments, Money total, DateTime now) {
  final matches = <TillPayment>[];
  final others = <TillPayment>[];
  for (final payment in payments) {
    final amount = payment.amount;
    if (total.cents > 0 && amount != null && amount.cents == total.cents) {
      matches.add(payment);
    } else {
      others.add(payment);
    }
  }
  TillPayment? auto;
  if (matches.length == 1) {
    final arrived = matches.single.receivedAt;
    if (arrived != null && now.difference(arrived) < tillAutoWindow) auto = matches.single;
  }
  return TillMatches(matches: matches, others: others, auto: auto);
}
