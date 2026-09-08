import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/app.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import 'package:nexapos_mobile/domain/services/app_lock_settings.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/features/settings/payment_settings_screen.dart'
    show currentPaymentCredentialsProvider;

const _testCredentials = PaystackCredentials(
  baseUrl: 'https://test.example/index.php',
  apiKey: 'test-api-key',
  currency: 'KES',
  defaultEmail: '',
);

const _checkInterval = Duration(seconds: 5);

class _TestLockSettings extends AppLockSettings {
  _TestLockSettings(this.minutes);
  final int minutes;
  @override
  int build() => minutes;
}

void main() {
  Future<FixedClock> pumpLoggedIn(
    WidgetTester tester, {
    int lockMinutes = 30,
  }) async {
    final clock = FixedClock(DateTime.utc(2026, 1, 1, 12));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) {
            final db = AppDatabase(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
          hasCachedLicenseProvider.overrideWith((ref) async => true),
          currentPaymentCredentialsProvider.overrideWith(
            (ref) async => _testCredentials,
          ),
          clockProvider.overrideWith((ref) => clock),
          appLockSettingsProvider.overrideWith(
            () => _TestLockSettings(lockMinutes),
          ),
        ],
        child: const NexaPosApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Your name'),
      'Felix Owner',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'felix',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'secret123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create admin account'));
    await tester.pumpAndSettle();

    expect(
      find.text('Felix Owner'),
      findsOneWidget,
      reason: 'setup should auto-login',
    );
    return clock;
  }

  testWidgets(
    'the default 30 minutes with zero interaction logs the user out',
    (tester) async {
      final clock = await pumpLoggedIn(tester);

      clock.advance(const Duration(minutes: 31));
      await tester.pump(_checkInterval);
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Felix Owner'), findsNothing);
    },
  );

  testWidgets('immediate mode locks when the app is left', (tester) async {
    await pumpLoggedIn(tester, lockMinutes: 0);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NexaPosApp)),
    );
    expect(container.read(appLockSettingsProvider), 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    expect(container.read(sessionProvider), isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Felix Owner'), findsNothing);
  });

  testWidgets(
    'a tap before the timeout resets the idle clock, so no logout happens',
    (tester) async {
      final clock = await pumpLoggedIn(tester);

      // 20 minutes in, still under the default 30-minute threshold - nothing
      // should happen yet, this is just advancing toward it.
      clock.advance(const Duration(minutes: 20));
      await tester.pump(_checkInterval);

      // A real interaction - anywhere on screen, the root Listener catches
      // it regardless of what's underneath (HitTestBehavior.translucent).
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();

      // Another 20 minutes (40 total since login, but only 20 since the
      // tap) - if the tap hadn't reset the clock, this would already be
      // well past the original login time, but not the most recent activity.
      clock.advance(const Duration(minutes: 20));
      await tester.pump(_checkInterval);
      await tester.pumpAndSettle();

      expect(find.text('Felix Owner'), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
    },
  );
}
