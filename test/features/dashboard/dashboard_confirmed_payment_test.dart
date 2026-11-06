import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Sale, User;
import 'package:nexapos_mobile/domain/entities/sale.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/pending_sales_notifier.dart';
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

Sale _paidSale(String id, String number) => Sale(
  id: id,
  saleNumber: number,
  userId: 'cashier-1',
  customerName: 'Walk-in',
  saleType: 'retail',
  paymentMethod: 'paystack',
  subtotal: const Money(25000),
  discount: const Money.zero(),
  total: const Money(25000),
  status: 'paid',
  createdAt: DateTime(2026, 11, 3, 12),
);

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
      sessionProvider.overrideWith(_Session.new),
      dashboardDataProvider.overrideWith((ref) async {
        return DashboardData(
          day: ref.read(reportsServiceProvider).today,
          today: const DailyStats(
            salesTotal: Money(0),
            salesCount: 0,
            expensesTotal: Money(0),
            grossProfit: Money(0),
            netProfit: Money(0),
          ),
          salesChange: const PercentChange(percent: 0, direction: 'flat'),
          netProfitChange: const PercentChange(percent: 0, direction: 'flat'),
          last7Days: const [],
          lowStockCount: 0,
          stockValue: const Money(0),
        );
      }),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
        GoRoute(
          path: '/receipt/:id',
          builder: (_, state) =>
              Scaffold(body: Text('receipt ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('a payment confirmed while the cashier was away is announced, with its receipt one tap away', (tester) async {
    container
        .read(confirmedOnlineSalesProvider.notifier)
        .add([_paidSale('sale-9', 'S-0009')]);
    await open(tester);

    expect(find.text('Payment received for S-0009'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirmed-online-payment-sale-9')));
    await tester.pumpAndSettle();

    expect(find.text('receipt sale-9'), findsOneWidget);
    expect(container.read(confirmedOnlineSalesProvider), isEmpty,
        reason: 'opening the receipt is also the acknowledgement');

    await close(tester);
  });

  testWidgets('it can be dismissed without opening the receipt', (tester) async {
    container
        .read(confirmedOnlineSalesProvider.notifier)
        .add([_paidSale('sale-9', 'S-0009')]);
    await open(tester);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.text('Payment received for S-0009'), findsNothing);
    expect(find.text('receipt sale-9'), findsNothing);

    await close(tester);
  });

  testWidgets('nothing is shown when no payment was confirmed in the background', (tester) async {
    await open(tester);

    expect(find.textContaining('Payment received for'), findsNothing);

    await close(tester);
  });

  test('the same sale is never announced twice', () {
    final notifier = container.read(confirmedOnlineSalesProvider.notifier);
    notifier.add([_paidSale('sale-9', 'S-0009')]);
    notifier.add([_paidSale('sale-9', 'S-0009'), _paidSale('sale-10', 'S-0010')]);

    expect(
      container.read(confirmedOnlineSalesProvider).map((sale) => sale.id),
      ['sale-9', 'sale-10'],
    );
  });
}
