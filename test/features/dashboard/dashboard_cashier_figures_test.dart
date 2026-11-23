import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/reports_service.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/features/dashboard/dashboard_screen.dart';

/// The owner, 2026-11-23: "make the cashier user not to be able to see daily sales or profits on the dashboard or stock
/// value". A cashier's dashboard has no Sales Today, Net Profit Today, Stock Value or Last 7 Days - not even as stars
/// behind the eye - only Low Stock and the New Sale button. Admins and managers keep everything.

User _user(UserRole role) =>
    User(id: 'u-${role.name}', role: role, name: role.name, username: role.name, passwordHash: '', status: 'active');

class _Session extends SessionNotifier {
  _Session(this.first);
  final UserRole first;
  @override
  User? build() => _user(first);
  void become(UserRole role) => state = _user(role);
}

DashboardData _data() => DashboardData(
      today: const DailyStats(
        salesTotal: Money(12000),
        salesCount: 3,
        expensesTotal: Money(2000),
        grossProfit: Money(7000),
        netProfit: Money(5000),
        refundsTotal: Money(1500),
      ),
      salesChange: const PercentChange(percent: 20, direction: 'up'),
      netProfitChange: const PercentChange(percent: 10, direction: 'up'),
      last7Days: [
        for (var day = 1; day <= 7; day++)
          DailyPoint(
            date: DateTime(2026, 11, 16 + day),
            salesTotal: Money(10000 * day),
            expensesTotal: const Money(2000),
            netProfit: Money(3000 * day),
          ),
      ],
      lowStockCount: 736,
      stockValue: const Money(30000),
    );

const _moneyLabels = ['Sales Today', 'Net Profit Today', 'Stock Value', 'Last 7 Days'];

void main() {
  Future<ProviderContainer> pumpAt(WidgetTester tester, Size size, UserRole role) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(() => _Session(role)),
        dashboardDataProvider.overrideWith((ref) async => _data()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: DashboardScreen()),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  /// Nothing about the shop's money anywhere on the screen.
  void noShopMoney(WidgetTester tester) {
    for (final label in [..._moneyLabels, 'Net Profit', 'Sales', 'Expenses']) {
      expect(find.text(label), findsNothing, reason: '$label is for the owner and managers');
    }
    expect(find.textContaining('KES'), findsNothing, reason: 'no amount of money at all');
    expect(find.textContaining('******'), findsNothing, reason: 'not even hidden behind stars');
    expect(find.textContaining('transaction'), findsNothing, reason: 'not the number of sales either');
    expect(find.textContaining('Gross'), findsNothing);
    expect(find.byTooltip('Show financial values'), findsNothing, reason: 'no eye to reveal them');
    expect(find.byTooltip('Hide financial values'), findsNothing);
    expect(find.byType(SalesTrendCard), findsNothing);
  }

  test('only admins and managers see the shop figures', () {
    expect(canSeeShopFigures(UserRole.admin), isTrue);
    expect(canSeeShopFigures(UserRole.manager), isTrue);
    expect(canSeeShopFigures(UserRole.cashier), isFalse);
  });

  for (final window in [const Size(400, 800), const Size(1366, 768)]) {
    final where = window.width < wideDashboardWidth ? 'a phone' : 'a PC';
    testWidgets('a cashier on $where sees no sales, profit, stock value or chart - only Low Stock and New Sale',
        (tester) async {
      await pumpAt(tester, window, UserRole.cashier);
      expect(tester.takeException(), isNull);
      noShopMoney(tester);
      expect(find.byKey(const Key('dashboard-cashier-figures')), findsOneWidget);
      expect(find.text('Low Stock'), findsOneWidget);
      expect(find.text('736'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('New Sale'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('New Sale'), findsOneWidget);
    });

    for (final role in [UserRole.admin, UserRole.manager]) {
      testWidgets('${role.name == 'admin' ? 'an admin' : 'a manager'} on $where still sees every figure and the chart',
          (tester) async {
        await pumpAt(tester, window, role);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('dashboard-cashier-figures')), findsNothing);
        for (final label in _moneyLabels) {
          await tester.scrollUntilVisible(find.text(label), 200, scrollable: find.byType(Scrollable).first);
          expect(find.text(label), findsOneWidget, reason: label);
        }
        expect(find.byType(SalesTrendCard), findsOneWidget);
        // and the eye still shows the amounts
        await tester.scrollUntilVisible(find.byKey(const Key('sales-today-value')), -200,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(find.byTooltip('Show financial values').first);
        await tester.pump();
        expect(find.text(const Money(12000).format()), findsOneWidget);
        expect(find.text(const Money(30000).format()), findsOneWidget);
      });
    }
  }

  testWidgets('an admin who showed the amounts, then a cashier signing in on the same screen: the cashier sees none of it',
      (tester) async {
    final container = await pumpAt(tester, const Size(1366, 768), UserRole.admin);
    await tester.tap(find.byTooltip('Show financial values').first);
    await tester.pump();
    expect(find.text(const Money(12000).format()), findsOneWidget);
    (container.read(sessionProvider.notifier) as _Session).become(UserRole.cashier);
    await tester.pumpAndSettle();
    noShopMoney(tester);
    expect(find.text('736'), findsOneWidget);
    // and back to the admin: the amounts start hidden again, behind the eye
    (container.read(sessionProvider.notifier) as _Session).become(UserRole.admin);
    await tester.pumpAndSettle();
    expect(find.text('Sales Today'), findsOneWidget);
    expect(find.text(const Money(12000).format()), findsNothing);
  });

  testWidgets('a cashier cannot open Inventory from the Low Stock card', (tester) async {
    await pumpAt(tester, const Size(1366, 768), UserRole.cashier);
    await tester.tap(find.text('Low Stock'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Low Stock'), findsOneWidget, reason: 'still on the dashboard');
  });
}
