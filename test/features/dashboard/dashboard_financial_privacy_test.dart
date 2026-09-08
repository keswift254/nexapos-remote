import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/reports_service.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/features/dashboard/dashboard_screen.dart';

class _Session extends SessionNotifier {
  @override
  User? build() => const User(
    id: 'admin-1',
    role: UserRole.admin,
    name: 'Admin',
    username: 'admin',
    passwordHash: '',
    status: 'active',
  );
}

DashboardData _dashboardData() => DashboardData(
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
    DailyPoint(
      date: DateTime(2026, 9, 7),
      salesTotal: const Money(12000),
      expensesTotal: const Money(2000),
      netProfit: const Money(5000),
    ),
  ],
  lowStockCount: 0,
  stockValue: const Money(30000),
);

void main() {
  testWidgets(
    'financial values start hidden, reveal for 60 seconds, and hide on refresh',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(_Session.new),
          dashboardDataProvider.overrideWith((ref) async => _dashboardData()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      Text value(String key) => tester.widget<Text>(find.byKey(Key(key)));
      expect(value('sales-today-value').data, '******');
      expect(value('net-profit-today-value').data, '******');
      expect(find.text('Back up data now'), findsNothing);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Back up data now'), findsOneWidget);
      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Show financial values').first);
      await tester.pump();
      expect(value('sales-today-value').data, isNot('******'));
      expect(value('net-profit-today-value').data, isNot('******'));

      await tester.pump(const Duration(seconds: 59));
      expect(value('sales-today-value').data, isNot('******'));
      await tester.pump(const Duration(seconds: 1));
      expect(value('sales-today-value').data, '******');

      await tester.tap(find.byTooltip('Show financial values').first);
      await tester.pump();
      container.invalidate(dashboardDataProvider);
      await tester.pumpAndSettle();
      expect(value('sales-today-value').data, '******');
      expect(value('net-profit-today-value').data, '******');
    },
  );
}
