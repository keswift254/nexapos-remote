import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/app.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import 'package:nexapos_mobile/features/settings/payment_settings_screen.dart' show currentPaymentCredentialsProvider;

const _testCredentials =
    PaystackCredentials(baseUrl: 'https://test.example/index.php', apiKey: 'test-api-key', currency: 'KES', defaultEmail: '');

void main() {
  testWidgets(
      'completing the setup wizard creates the admin, logs in, and lands on the dashboard',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) {
            final db = AppDatabase(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
          // Setup/login is what this test exercises - licensing is covered
          // separately by activation_flow_test.dart.
          hasCachedLicenseProvider.overrideWith((ref) async => true),
          currentPaymentCredentialsProvider.overrideWith((ref) async => _testCredentials),
        ],
        child: const NexaPosApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set up NexaPOS'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Your name'), 'Felix Owner');
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'felix');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret123');
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), 'secret123');

    await tester.tap(find.widgetWithText(FilledButton, 'Create admin account'));
    await tester.pumpAndSettle();

    // Setup wizard is gone, we landed on the dashboard, logged in as the
    // admin we just created - proving create -> bcrypt hash -> DB write
    // -> auto-login -> secure-storage persist -> router redirect all
    // work together, not just in isolation.
    expect(find.text('Set up NexaPOS'), findsNothing);
    expect(find.text('Felix Owner'), findsOneWidget);

    // Logging out should bounce back to the login screen, not setup -
    // the admin now exists, so setup must never show again.
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Set up NexaPOS'), findsNothing);

    // And logging back in with the account we just created should work.
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'felix');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Felix Owner'), findsOneWidget);
  });

  testWidgets('wrong password on an existing account is rejected with a clear message',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) {
            final db = AppDatabase(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
          hasCachedLicenseProvider.overrideWith((ref) async => true),
          currentPaymentCredentialsProvider.overrideWith((ref) async => _testCredentials),
        ],
        child: const NexaPosApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Your name'), 'Admin');
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'admin');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'correcthorse');
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), 'correcthorse');
    await tester.tap(find.widgetWithText(FilledButton, 'Create admin account'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'admin');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'wrongpassword');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect username or password.'), findsOneWidget);
    expect(find.text('Admin'), findsNothing);
  });
}
