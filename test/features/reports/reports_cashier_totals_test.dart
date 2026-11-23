import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/daos/reports_dao.dart';
import 'package:nexapos_mobile/domain/entities/business_settings.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/reports_service.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/features/reports/reports_screen.dart';

/// The owner, 2026-11-23, after the dashboard: cashiers "can still see the day's sales total and gross profit under
/// Reports" - "yes do this hide totals and profit". A cashier's Reports keeps the list of sales and refunds (each with
/// its own amount, to open a receipt, reprint it or refund it) and shows no totals, profit, expenses, Print or Export.
/// Admins and managers keep the whole report.

User _user(UserRole role) =>
    User(id: 'u-${role.name}', role: role, name: role.name, username: role.name, passwordHash: '', status: 'active');

class _Session extends SessionNotifier {
  _Session(this.first);
  final UserRole first;
  @override
  User? build() => _user(first);
  void become(UserRole role) => state = _user(role);
}

final _now = DateTime.now().toUtc().toIso8601String();

ReportData _data() => ReportData(
      sales: [
        ReportSaleRow(
          id: 'sale-1',
          saleNumber: 'RCPT-0001',
          cashierName: 'Wanjiru',
          saleType: 'retail',
          paymentMethod: 'cash',
          status: 'paid',
          totalCents: 12300,
          createdAt: _now,
          itemNames: 'Soda 500ml',
          cashReceivedCents: 15000,
        ),
        ReportSaleRow(
          id: 'sale-2',
          saleNumber: 'RCPT-0002',
          cashierName: 'Wanjiru',
          saleType: 'retail',
          paymentMethod: 'mpesa_manual',
          status: 'paid',
          totalCents: 45600,
          createdAt: _now,
          itemNames: 'Bread',
          cashReceivedCents: null,
        ),
      ],
      refunds: [
        ReportRefundRow(
          id: 'refund-1',
          saleNumber: 'RFND-0001',
          originalSaleNumber: 'RCPT-0001',
          processedByName: 'Owner',
          paymentMethod: 'cash',
          reason: 'Broken',
          totalCents: 2100,
          createdAt: _now,
          itemNames: 'Soda 500ml',
        ),
      ],
      expenses: [
        ReportExpenseRow(id: 'exp-1', title: 'Transport', note: null, amountCents: 3300, createdAt: _now, enteredByName: 'Owner'),
      ],
      salesTotal: const Money(55800),
      refundsTotal: const Money(2100),
      expensesTotal: const Money(3300),
      grossProfitTotal: const Money(20700),
      netProfit: const Money(17400),
      grandTotal: const Money(52500),
      transactionCount: 2,
      cashReceivedTotal: const Money(12300),
      mpesaTotal: const Money(45600),
    );

/// Every amount that is a total or a profit, as the screen would write it.
final _totals = {
  'paid sales': const Money(55800).format(),
  'refunds total': const Money(2100).format(),
  'expenses': const Money(3300).format(),
  'gross profit': const Money(20700).format(),
  'net profit': const Money(17400).format(),
  'grand total': const Money(52500).format(),
};

const _totalWords = [
  'Paid Sales',
  'Total Cash Received',
  'Total Paid by M-Pesa',
  'Total Expenses',
  'Gross Profit',
  'Net Profit',
  'Grand Total',
  'Transactions',
];

void main() {
  Future<ProviderContainer> pumpReports(WidgetTester tester, UserRole role, {Size size = const Size(1366, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(() => _Session(role)),
        reportDataProvider.overrideWith((ref, args) async => _data()),
        reportBusinessSettingsProvider.overrideWith(
          (ref) async => const BusinessSettings(businessName: 'Shop', currency: 'KES', paperWidthMm: 58),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ReportsScreen()),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  /// Scrolls the whole report through, collecting every piece of text it shows.
  Future<String> allText(WidgetTester tester) async {
    final seen = <String>{};
    final list = find.byType(Scrollable).first;
    for (var i = 0; i < 40; i++) {
      for (final widget in tester.widgetList<Text>(find.byType(Text))) {
        seen.add(widget.data ?? widget.textSpan?.toPlainText() ?? '');
      }
      final before = tester.state<ScrollableState>(list).position.pixels;
      await tester.drag(list, const Offset(0, -300));
      await tester.pumpAndSettle();
      if (tester.state<ScrollableState>(list).position.pixels == before) break;
    }
    return seen.join('\n');
  }

  for (final mode in ['Daily Sales', 'Monthly Sales', 'Selected Period']) {
    testWidgets('a cashier, $mode: the sales and refunds with their own amounts, and no total, profit or expense',
        (tester) async {
      await pumpReports(tester, UserRole.cashier);
      await tester.tap(find.text(mode));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final text = await allText(tester);
      // what a cashier needs: every receipt, with its amount, to open, reprint or refund
      for (final receipt in ['RCPT-0001', 'RCPT-0002', 'RFND-0001']) {
        expect(text, contains(receipt));
      }
      expect(text, contains(const Money(12300).format()), reason: 'a sale keeps its own amount');
      expect(text, contains(const Money(45600).format()));
      expect(text, contains(const Money(2100).format()), reason: 'a refund keeps its own amount');
      expect(text, contains('Tap a receipt to see it, reprint it or refund it.'));
      // and nothing that adds them up
      for (final word in _totalWords) {
        expect(text, isNot(contains(word)), reason: '"$word" is for the owner and managers');
      }
      expect(text, isNot(contains('Total Paid Sales')));
      expect(text, isNot(contains('Total Refunds')));
      _totals.forEach((what, amount) {
        if (what == 'refunds total') return; // the one refund's own amount is the same figure
        expect(text, isNot(contains(amount)), reason: 'the $what ($amount) must not show');
      });
      expect(text, isNot(contains('Transport')), reason: 'no expenses');
      expect(find.byKey(const Key('report-totals')), findsNothing);
    });
  }

  testWidgets('a cashier has no Expenses tab, no Print and no Export PDF', (tester) async {
    await pumpReports(tester, UserRole.cashier);
    expect(find.widgetWithText(ChoiceChip, 'Expenses'), findsNothing);
    expect(find.text('Print'), findsNothing);
    expect(find.text('Export PDF'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Daily Sales'), findsOneWidget);
    expect(find.text('View Report'), findsOneWidget);
  });

  testWidgets('a cashier can still open a receipt from the list (to reprint or refund it)', (tester) async {
    await pumpReports(tester, UserRole.cashier);
    final cell = find.text('RCPT-0002'); // (RCPT-0001 is also named on its refund's row)
    expect(cell, findsOneWidget);
    // the cell opens /receipt/<id>; with no router in this test the tap throws, which proves the cell is still a link
    await tester.tap(cell);
    await tester.pump();
    final error = tester.takeException();
    expect(error.toString(), contains('GoRouter'), reason: 'the receipt link is still there');
  });

  for (final role in [UserRole.admin, UserRole.manager]) {
    testWidgets('${role.name == 'admin' ? 'an admin' : 'a manager'} still gets the whole report', (tester) async {
      await pumpReports(tester, role);
      expect(find.widgetWithText(ChoiceChip, 'Expenses'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);
      expect(find.text('Export PDF'), findsOneWidget);
      expect(find.byKey(const Key('report-totals')), findsOneWidget);
      final text = await allText(tester);
      for (final word in ['Paid Sales', 'Total Cash Received', 'Total Paid by M-Pesa', 'Total Expenses', 'Grand Total', 'Transactions']) {
        expect(text, contains(word));
      }
      expect(text, contains('Total Paid Sales: ${const Money(55800).format()}'));
      expect(text, contains('Total Refunds: ${const Money(2100).format()}'));
      expect(text, contains('Transport'));
      expect(text, contains(const Money(52500).format()), reason: 'the grand total');
      expect(text, isNot(contains('Tap a receipt to see it, reprint it or refund it.')));
    });
  }

  testWidgets('a manager, Monthly Sales: the gross and net profit are there', (tester) async {
    await pumpReports(tester, UserRole.manager);
    await tester.tap(find.text('Monthly Sales'));
    await tester.pumpAndSettle();
    final text = await allText(tester);
    expect(text, contains('Gross Profit'));
    expect(text, contains('Net Profit'));
    expect(text, contains(const Money(20700).format()));
    expect(text, contains(const Money(17400).format()));
  });

  testWidgets('a cashier on a phone sees the same: receipts, no totals', (tester) async {
    await pumpReports(tester, UserRole.cashier, size: const Size(400, 800));
    expect(tester.takeException(), isNull);
    final text = await allText(tester);
    expect(text, contains('RCPT-0002'));
    for (final word in _totalWords) {
      expect(text, isNot(contains(word)));
    }
  });

  testWidgets('the same screen, an admin then a cashier signing in: the totals go', (tester) async {
    final container = await pumpReports(tester, UserRole.admin);
    expect(find.byKey(const Key('report-totals')), findsOneWidget);
    (container.read(sessionProvider.notifier) as _Session).become(UserRole.cashier);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-totals')), findsNothing);
    expect(find.text('Print'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Expenses'), findsNothing);
  });
}
