import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/payments/payment_inbox_gateway.dart';
import 'package:nexapos_mobile/domain/services/till_matches.dart';

/// Which unused till payments fit a sale: only the ones of exactly the total are shown; the ONLY new one completes the sale
/// by itself; two or more are for the cashier to choose from. The same rule as NexaPOS Lite's core.tillMatches.
void main() {
  final now = DateTime.utc(2026, 11, 20, 10);

  TillPayment pay(String code, int? cents, {double? minutesAgo}) => TillPayment(
        code: code,
        messageReceived: true,
        amount: cents == null ? null : Money(cents),
        receivedAt: minutesAgo == null ? null : now.subtract(Duration(milliseconds: (minutesAgo * 60000).round())),
      );

  List<String> codes(List<TillPayment> list) => [for (final p in list) p.code];

  test('the window is 10 minutes, as in NexaPOS Lite', () {
    expect(tillAutoWindow, const Duration(minutes: 10));
  });

  test('only the sale total fits; other and unread amounts are the others, in order; the only new one completes the sale', () {
    final fit = tillMatches([pay('A1', 6000, minutesAgo: 1), pay('B1', 5000, minutesAgo: 0), pay('C1', null, minutesAgo: 0)], const Money(6000), now);
    expect(codes(fit.matches), ['A1']);
    expect(codes(fit.others), ['B1', 'C1']);
    expect(fit.auto?.code, 'A1');
  });

  test('two of the same amount: newest first, and the cashier chooses', () {
    final fit = tillMatches([pay('A2', 6000, minutesAgo: 0), pay('B2', 6000, minutesAgo: 3), pay('C2', 7000, minutesAgo: 0)], const Money(6000), now);
    expect(codes(fit.matches), ['A2', 'B2']);
    expect(fit.auto, isNull);
  });

  test("a lone payment 10 minutes old may be an earlier customer's: only suggested", () {
    final old = tillMatches([pay('A3', 6000, minutesAgo: 10)], const Money(6000), now);
    expect(codes(old.matches), ['A3']);
    expect(old.auto, isNull);
    expect(tillMatches([pay('A4', 6000, minutesAgo: 9.99)], const Money(6000), now).auto?.code, 'A4', reason: 'just under still counts');
  });

  test('a slow clock here: a payment from "the future" is new; no arrival time never completes by itself', () {
    expect(tillMatches([pay('A5', 6000, minutesAgo: -3)], const Money(6000), now).auto?.code, 'A5');
    expect(tillMatches([pay('A6', 6000)], const Money(6000), now).auto, isNull);
  });

  test('an older one of the same amount still makes two', () {
    expect(tillMatches([pay('A7', 6000, minutesAgo: 0), pay('B7', 6000, minutesAgo: 60)], const Money(6000), now).auto, isNull);
  });

  test('an empty sale fits nothing; no payments, nothing', () {
    final empty = tillMatches([pay('A8', 6000, minutesAgo: 0)], const Money.zero(), now);
    expect([empty.matches.length, empty.others.length, empty.auto], [0, 1, null]);
    final none = tillMatches(const [], const Money(6000), now);
    expect([none.matches.length, none.others.length, none.auto], [0, 0, null]);
  });

  test('a local time "now" compares with the shop\'s UTC times as instants', () {
    final local = now.toLocal();
    expect(tillMatches([pay('A9', 6000, minutesAgo: 2)], const Money(6000), local).auto?.code, 'A9');
  });
}
