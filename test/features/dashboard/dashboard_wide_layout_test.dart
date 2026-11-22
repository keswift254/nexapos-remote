import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/reports_service.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/features/dashboard/dashboard_screen.dart';

/// The owner, 2026-11-22: on a PC the dashboard should "show all its contents at a glance - I don't have to scroll down
/// to access New Sale or Inventory". A wide window gets the buttons at the top and the four figures in one row; a phone
/// keeps the long page it had.

class _Session extends SessionNotifier {
  _Session(this.role);
  final UserRole role;
  @override
  User? build() => User(id: 'u-1', role: role, name: 'Owner', username: 'owner', passwordHash: '', status: 'active');
}

DashboardData _data() => DashboardData(
      today: const DailyStats(
        salesTotal: Money(12000),
        salesCount: 3,
        expensesTotal: Money(2000),
        grossProfit: Money(7000),
        netProfit: Money(5000),
      ),
      salesChange: const PercentChange(percent: 20, direction: 'up'),
      netProfitChange: const PercentChange(percent: 10, direction: 'up'),
      last7Days: [
        for (var day = 1; day <= 7; day++)
          DailyPoint(
            date: DateTime(2026, 11, 15 + day),
            salesTotal: Money(10000 * day),
            expensesTotal: const Money(2000),
            netProfit: Money(3000 * day),
          ),
      ],
      lowStockCount: 736,
      stockValue: const Money(30000),
    );

/// The button whose label is [label] (any kind of Material button).
Finder button_(String label) =>
    find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton));

void main() {
  Future<void> pumpAt(WidgetTester tester, Size size, {UserRole role = UserRole.admin}) async {
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
  }

  /// Wholly inside the window, with nothing scrolled.
  void onScreen(WidgetTester tester, Finder finder, Size window, String what) {
    expect(finder, findsOneWidget, reason: what);
    final box = tester.getRect(finder);
    expect(box.top, greaterThanOrEqualTo(0), reason: '$what top');
    expect(box.bottom, lessThanOrEqualTo(window.height), reason: '$what is below the bottom of the window');
  }

  for (final window in [const Size(1366, 768), const Size(1920, 1080), const Size(1024, 768)]) {
    testWidgets('a PC window ${window.width.toInt()}x${window.height.toInt()}: New Sale, Inventory, Categories, Expenses, '
        'the four figures and the chart are all on screen without scrolling', (tester) async {
      await pumpAt(tester, window);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('dashboard-actions-top')), findsOneWidget);
      for (final button in ['New Sale', 'Inventory', 'Categories', 'Expenses']) {
        onScreen(tester, button_(button), window, '$button button');
      }
      for (final figure in ['Sales Today', 'Net Profit Today', 'Low Stock', 'Stock Value', 'Last 7 Days']) {
        onScreen(tester, find.text(figure), window, figure);
      }
      // the four figures share one row
      final tops = ['Sales Today', 'Net Profit Today', 'Low Stock', 'Stock Value']
          .map((label) => tester.getTopLeft(find.ancestor(of: find.text(label), matching: find.byType(Card)).first).dy)
          .toSet();
      expect(tops, hasLength(1), reason: 'one row of four cards');
      // the buttons come before the figures
      expect(tester.getTopLeft(find.text('New Sale')).dy, lessThan(tester.getTopLeft(find.text('Sales Today')).dy));
    });
  }

  testWidgets('a cashier on a PC sees New Sale at the top, and no management buttons', (tester) async {
    await pumpAt(tester, const Size(1366, 768), role: UserRole.cashier);
    onScreen(tester, button_('New Sale'), const Size(1366, 768), 'New Sale');
    expect(button_('Inventory'), findsNothing);
  });

  testWidgets('a phone keeps the long page: figures in two rows, the buttons after them', (tester) async {
    await pumpAt(tester, const Size(400, 800));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('dashboard-actions-top')), findsNothing);
    expect(find.byKey(const Key('dashboard-figures-one-row')), findsNothing);
    double cardTop(String label) => tester.getTopLeft(find.ancestor(of: find.text(label), matching: find.byType(Card)).first).dy;
    expect(cardTop('Sales Today'), isNot(cardTop('Low Stock')), reason: 'two rows of figures');
    await tester.scrollUntilVisible(find.text('New Sale'), 200, scrollable: find.byType(Scrollable).first);
    expect(tester.getTopLeft(find.text('New Sale')).dy, greaterThan(tester.getTopLeft(find.text('Sales Today')).dy),
        reason: 'below the figures, as before');
  });
}
