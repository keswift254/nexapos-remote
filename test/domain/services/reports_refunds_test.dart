import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/domain/services/reports_service.dart';

import '../../support/shop_harness.dart';

/// Refunds in the Reports and on the dashboard: what customers paid, what went back, what the shop kept.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ShopHarness shop;
  final day = DateTime(2026, 11, 16);
  final nextDay = DateTime(2026, 11, 17);

  setUp(() async => shop = await ShopHarness.create());
  tearDown(() => shop.close());

  Future<ReportData> reportForDay([DateTime? from]) {
    final start = from ?? day;
    return shop.reports.reportForRange(start, start.add(const Duration(days: 1)));
  }

  test('a day with sales and a refund: paid sales, refunds and what the shop kept are three different figures', () async {
    final cash = await shop.sell([shop.line(shop.widgetId, 'Widget', 10000, 6000, 3)]); // 300.00
    final mpesa = await shop.sell([shop.line(shop.gadgetId, 'Gadget', 25050, 15000, 1)], method: 'mpesa_manual'); // 250.50
    await shop.mustRefund(cash, [await shop.choose(cash.id, shop.widgetId, 1)], reason: 'Bent');

    final report = await reportForDay();
    expect(report.salesTotal.cents, 55050, reason: 'what customers paid, refunds not taken off');
    expect(report.refundsTotal.cents, 10000);
    expect(report.grandTotal.cents, 45050, reason: 'paid - refunds - expenses');
    expect(report.cashReceivedTotal.cents, 30000, reason: 'cash and M-Pesa still add up to the paid sales');
    expect(report.mpesaTotal.cents, 25050);
    expect(report.transactionCount, 2, reason: 'a refund is not a transaction');
    expect(report.sales.map((s) => s.id).toSet(), {cash.id, mpesa.id}, reason: 'the refund is not listed among the sales');
    expect(report.refunds, hasLength(1));
    final row = report.refunds.single;
    expect(row.originalSaleNumber, cash.saleNumber);
    expect(row.reason, 'Bent');
    expect(row.processedByName, 'Manager');
    expect(row.paymentMethod, 'cash');
    expect(row.totalCents, 10000, reason: 'shown as a positive amount of money that went back');
    expect(row.itemNames, 'Widget x1');
  });

  test('the sale row says how much of it is refunded', () async {
    final sale = await shop.sell([shop.line(shop.widgetId, 'Widget', 10000, 6000, 2)]);
    var row = (await reportForDay()).sales.single;
    expect(row.refundedCents, 0);
    expect(row.statusLabel, 'paid');
    await shop.mustRefund(sale, [await shop.choose(sale.id, shop.widgetId, 1)]);
    row = (await reportForDay()).sales.single;
    expect(row.refundedCents, 10000);
    expect(row.statusLabel, 'part refunded');
    await shop.mustRefund(sale, [await shop.choose(sale.id, shop.widgetId, 1)]);
    row = (await reportForDay()).sales.single;
    expect(row.refundedCents, 20000);
    expect(row.statusLabel, 'refunded');
  });

  test('profit follows the goods: a refund that goes back on the shelf gives back the margin, one that cannot costs the whole price', () async {
    final sale = await shop.sell([shop.line(shop.widgetId, 'Widget', 10000, 6000, 2)]); // profit 80.00
    expect((await reportForDay()).grossProfitTotal.cents, 8000);
    await shop.mustRefund(sale, [await shop.choose(sale.id, shop.widgetId, 1)]);
    expect((await reportForDay()).grossProfitTotal.cents, 4000, reason: 'one widget back on the shelf: its 40.00 margin is gone');
    await shop.mustRefund(sale, [await shop.choose(sale.id, shop.widgetId, 1, restock: false)]);
    expect((await reportForDay()).grossProfitTotal.cents, -6000, reason: 'the second one is thrown away: 100.00 refunded, its 60.00 cost is lost');
  });

  test('a refund is counted on the day the money went back, not the day of the sale', () async {
    final sale = await shop.sell([shop.line(shop.widgetId, 'Widget', 10000, 6000, 1)]);
    shop.clock.value = ShopHarness.noon(17);
    await shop.mustRefund(sale, await shop.everything(sale.id));

    final first = await reportForDay(day);
    expect(first.salesTotal.cents, 10000);
    expect(first.refundsTotal.cents, 0);
    expect(first.grandTotal.cents, 10000, reason: 'that day is not rewritten');
    expect(first.sales.single.statusLabel, 'refunded', reason: 'but the sale itself shows it has since gone back');

    final second = await reportForDay(nextDay);
    expect(second.salesTotal.cents, 0);
    expect(second.transactionCount, 0);
    expect(second.refundsTotal.cents, 10000);
    expect(second.grandTotal.cents, -10000);
  });

  test('expenses come off as before', () async {
    final sale = await shop.sell([shop.line(shop.widgetId, 'Widget', 10000, 6000, 3)]);
    await shop.mustRefund(sale, [await shop.choose(sale.id, shop.widgetId, 1)]);
    await shop.expenses.create(
      expenseDate: day,
      title: 'Transport',
      amount: const Money(2500),
      userId: shop.owner.id,
    );
    final report = await reportForDay();
    expect(report.grandTotal.cents, 30000 - 10000 - 2500);
    expect(report.netProfit.cents, report.grossProfitTotal.cents - 2500);
  });

  test('the dashboard: sales today are net of refunds, transactions are real sales only, refunds are shown', () async {
    final sale = await shop.sell([shop.line(shop.widgetId, 'Widget', 10000, 6000, 3)]);
    await shop.sell([shop.line(shop.gadgetId, 'Gadget', 25050, 15000, 1)]);
    await shop.mustRefund(sale, [await shop.choose(sale.id, shop.widgetId, 2)]);

    final stats = await shop.reports.statsForLocalDate(day);
    expect(stats.salesTotal.cents, 30000 + 25050 - 20000);
    expect(stats.salesCount, 2);
    expect(stats.refundsTotal.cents, 20000);
    expect(stats.grossProfit.cents, 12000 + 10050 - 8000, reason: 'profit of both sales less the margin of the two widgets that came back');
  });

  test('a day with no refunds looks exactly as before', () async {
    await shop.sell([shop.line(shop.widgetId, 'Widget', 10000, 6000, 1)]);
    final report = await reportForDay();
    expect(report.refunds, isEmpty);
    expect(report.refundsTotal, const Money.zero());
    expect(report.grandTotal, report.salesTotal);
    expect(report.sales.single.statusLabel, 'paid');
    final stats = await shop.reports.statsForLocalDate(day);
    expect(stats.refundsTotal, const Money.zero());
  });

  test('refunds of several sales on the same day are all listed, newest first', () async {
    final a = await shop.sell([shop.line(shop.widgetId, 'Widget', 10000, 6000, 1)]);
    final b = await shop.sell([shop.line(shop.gadgetId, 'Gadget', 25050, 15000, 1)]);
    final first = await shop.mustRefund(a, await shop.everything(a.id), reason: 'one');
    shop.clock.value = shop.clock.value.add(const Duration(minutes: 5));
    final second = await shop.mustRefund(b, await shop.everything(b.id), reason: 'two');
    final report = await reportForDay();
    expect(report.refunds.map((r) => r.id), [second.id, first.id]);
    expect(report.refundsTotal.cents, 35050);
  });
}
