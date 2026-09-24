import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/clock_health_service.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/features/settings/clock_health_banner.dart';

class _Session extends SessionNotifier {
  _Session(this.role);
  final UserRole role;

  @override
  User? build() => User(
    id: 'u', role: role, name: 'Test User', username: 'tester', passwordHash: '', status: 'active',
  );
}

void main() {
  late ProviderContainer container;
  late List<String> pushed;

  Future<void> show(WidgetTester tester, UserRole role, ClockHealth? health) async {
    pushed = [];
    container = ProviderContainer(overrides: [
      sessionProvider.overrideWith(() => _Session(role)),
    ]);
    container.read(clockHealthProvider.notifier).debugSet(health);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: ClockHealthBanner())),
      GoRoute(path: '/region-time', builder: (_, _) {
        pushed.add('/region-time');
        return const Scaffold(body: Text('Region and Time page'));
      }),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  }

  const bannerKey = Key('clock-health-banner');
  ClockHealth health({Duration? skew, bool zoneDiffers = false}) => ClockHealth(
    checkedAt: Duration.zero,
    skew: skew,
    zoneDiffers: zoneDiffers,
    regionSet: true,
    deviceOffset: const Duration(hours: 3),
  );

  testWidgets('shows nothing before any check', (tester) async {
    await show(tester, UserRole.admin, null);

    expect(find.byKey(bannerKey), findsNothing);

    await close(tester);
  });

  testWidgets('shows nothing while the clock is fine', (tester) async {
    await show(tester, UserRole.admin, health(skew: const Duration(seconds: 20)));

    expect(find.byKey(bannerKey), findsNothing);

    await close(tester);
  });

  testWidgets('shows nothing when the clock could not be checked (offline)', (tester) async {
    await show(tester, UserRole.admin, health(skew: null));

    expect(find.byKey(bannerKey), findsNothing);

    await close(tester);
  });

  testWidgets('an admin is told how far off the clock is and taps through to fix it', (tester) async {
    await show(tester, UserRole.admin, health(skew: const Duration(hours: -3, minutes: -5)));

    expect(find.text("This device's clock looks wrong"), findsOneWidget);
    expect(find.textContaining('3 hours 5 minutes behind the real time'), findsOneWidget);
    expect(find.textContaining('Tap to fix it.'), findsOneWidget);

    await tester.tap(find.byKey(bannerKey));
    await tester.pumpAndSettle();

    expect(find.text('Region and Time page'), findsOneWidget);

    await close(tester);
  });

  testWidgets('anyone else is told to ask the admin, and the banner does not lead to the settings', (tester) async {
    await show(tester, UserRole.cashier, health(skew: const Duration(days: 2)));

    expect(find.textContaining('2 days ahead of the real time'), findsOneWidget);
    expect(find.textContaining('Ask the shop admin to fix it.'), findsOneWidget);

    await tester.tap(find.byKey(bannerKey));
    await tester.pumpAndSettle();

    expect(pushed, isEmpty);

    await close(tester);
  });

  testWidgets('a wrong time zone alone is reported as that', (tester) async {
    await show(tester, UserRole.admin, health(skew: Duration.zero, zoneDiffers: true));

    expect(find.textContaining("time zone does not match your shop's region"), findsOneWidget);

    await close(tester);
  });
}
