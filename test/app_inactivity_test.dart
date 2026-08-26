import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/app.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';

const _checkInterval = Duration(seconds: 30);

void main() {
  Future<FixedClock> pumpLoggedIn(WidgetTester tester) async {
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
          clockProvider.overrideWith((ref) => clock),
        ],
        child: const NexaPosApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Your name'), 'Felix Owner');
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'felix');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret123');
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Create admin account'));
    await tester.pumpAndSettle();

    expect(find.text('Felix Owner'), findsOneWidget, reason: 'setup should auto-login');
    return clock;
  }

  testWidgets('28 minutes with zero interaction logs the user out automatically', (tester) async {
    final clock = await pumpLoggedIn(tester);

    clock.advance(const Duration(minutes: 29));
    await tester.pump(_checkInterval);
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Felix Owner'), findsNothing);
  });

  testWidgets('a tap before the timeout resets the idle clock, so no logout happens', (tester) async {
    final clock = await pumpLoggedIn(tester);

    // 20 minutes in, still under the 28-minute threshold - nothing
    // should happen yet, this is just advancing toward it.
    clock.advance(const Duration(minutes: 20));
    await tester.pump(_checkInterval);

    // A real interaction - anywhere on screen, the root Listener catches
    // it regardless of what's underneath (HitTestBehavior.translucent).
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();

    // Another 20 minutes (40 total since login, but only 20 since the
    // tap) - if the tap hadn't reset the clock, this would already be
    // well past the 28-minute threshold and logged out.
    clock.advance(const Duration(minutes: 20));
    await tester.pump(_checkInterval);
    await tester.pumpAndSettle();

    expect(find.text('Felix Owner'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });
}
