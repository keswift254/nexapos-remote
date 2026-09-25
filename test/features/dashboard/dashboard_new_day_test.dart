import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide User;
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

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late ProviderContainer container;
  late List<DateTime> computedFor;

  // 11:58 pm on 25 September, the shop's local time.
  final beforeMidnight = DateTime(2026, 9, 25, 23, 58).toUtc();

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(beforeMidnight);
    computedFor = [];
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
      clockProvider.overrideWith((ref) => clock),
      sessionProvider.overrideWith(_Session.new),
      // The real provider graph would need products and sales; what matters here is WHEN
      // the figures are recomputed and for which day.
      dashboardDataProvider.overrideWith((ref) async {
        final day = ref.read(reportsServiceProvider).today;
        computedFor.add(day);
        return DashboardData(
          day: day,
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
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: DashboardScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('the figures are for the day the dashboard opened on, and stay while the day does not change', (tester) async {
    await open(tester);

    expect(computedFor, [DateTime(2026, 9, 25)]);
    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(seconds: 15));
    expect(computedFor, hasLength(1), reason: 'same day: nothing is recomputed just because time passed');

    await close(tester);
  });

  testWidgets('at midnight the dashboard turns over to the new day by itself, with no sale and no tap', (tester) async {
    await open(tester);
    expect(computedFor, [DateTime(2026, 9, 25)]);

    clock.set(DateTime(2026, 9, 26, 0, 0, 5).toUtc());
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();

    expect(computedFor, [DateTime(2026, 9, 25), DateTime(2026, 9, 26)]);

    await close(tester);
  });

  testWidgets('it turns over only once, not on every check afterwards', (tester) async {
    await open(tester);
    clock.set(DateTime(2026, 9, 26, 0, 1).toUtc());
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(seconds: 15));

    expect(computedFor, hasLength(2));

    await close(tester);
  });

  testWidgets('a PC that slept through midnight shows the new day the moment the app resumes', (tester) async {
    await open(tester);

    clock.set(DateTime(2026, 9, 26, 7, 30).toUtc()); // woke up in the morning, no timer ever fired
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(computedFor.last, DateTime(2026, 9, 26));

    await close(tester);
  });

  testWidgets('changing the date on the device (forward or back) is noticed too', (tester) async {
    await open(tester);

    clock.set(DateTime(2026, 9, 24, 12).toUtc());
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();

    expect(computedFor.last, DateTime(2026, 9, 24));

    await close(tester);
  });

  testWidgets('coming back to the dashboard after midnight shows the new day at once', (tester) async {
    await open(tester);
    // Leave the dashboard (its figures are kept), pass midnight, come back.
    await close(tester);
    clock.set(DateTime(2026, 9, 26, 0, 30).toUtc());

    await open(tester);

    expect(computedFor.last, DateTime(2026, 9, 26));

    await close(tester);
  });

  testWidgets('figures built by hand without a day (as some tests do) never trigger a refresh loop', (tester) async {
    final other = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
      clockProvider.overrideWith((ref) => clock),
      sessionProvider.overrideWith(_Session.new),
      dashboardDataProvider.overrideWith((ref) async {
        computedFor.add(DateTime(1970));
        return const DashboardData(
          today: DailyStats(
            salesTotal: Money(0),
            salesCount: 0,
            expensesTotal: Money(0),
            grossProfit: Money(0),
            netProfit: Money(0),
          ),
          salesChange: PercentChange(percent: 0, direction: 'flat'),
          netProfitChange: PercentChange(percent: 0, direction: 'flat'),
          last7Days: [],
          lowStockCount: 0,
          stockValue: Money(0),
        );
      }),
    ]);
    addTearDown(other.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: other, child: const MaterialApp(home: DashboardScreen())));
    await tester.pumpAndSettle();
    clock.set(DateTime(2026, 9, 27).toUtc());
    await tester.pump(const Duration(seconds: 30));

    expect(computedFor, hasLength(1));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
