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

Future<void> _createAdminAndSignIn(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Your name'), 'Owner');
  await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'owner');
  await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'ownerpass');
  await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), 'ownerpass');
  await tester.tap(find.widgetWithText(FilledButton, 'Create admin account'));
  await tester.pumpAndSettle();
}

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
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
            (ref) async => const PaystackCredentials(
                baseUrl: 'https://test.example/index.php', apiKey: 'test-api-key', currency: 'KES', defaultEmail: ''),
          ),
        ],
        child: const NexaPosApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('admin can add a cashier, who then signs in with the new account', (tester) async {
    await pumpApp(tester);
    await _createAdminAndSignIn(tester);

    // Admin-only icon should be visible; open Users & Roles.
    expect(find.byIcon(Icons.manage_accounts), findsOneWidget);
    await tester.tap(find.byIcon(Icons.manage_accounts));
    await tester.pumpAndSettle();

    expect(find.text('Owner'), findsOneWidget, reason: 'the admin itself should be listed');

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add User'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Cashier One');
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'cashier1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'cashierpass');
    // Role defaults to cashier already - leave as is.
    await tester.tap(find.widgetWithText(FilledButton, 'Create user'));
    await tester.pumpAndSettle();

    expect(find.text('Cashier One'), findsOneWidget);

    // Log out as admin, sign in as the newly created cashier.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'cashier1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'cashierpass');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Cashier One'), findsOneWidget);
    // A cashier must not see the admin-only Users & Roles entry point.
    expect(find.byIcon(Icons.manage_accounts), findsNothing);
  });

  testWidgets('an admin cannot disable their own account', (tester) async {
    await pumpApp(tester);
    await _createAdminAndSignIn(tester);

    await tester.tap(find.byIcon(Icons.manage_accounts));
    await tester.pumpAndSettle();

    // The only row is the admin itself - flip its own active switch off.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('You cannot disable your own account.'), findsOneWidget);
    // Still active - the switch should not have flipped.
    final Switch toggledSwitch = tester.widget(find.byType(Switch));
    expect(toggledSwitch.value, isTrue);
  });

  testWidgets('a disabled cashier cannot sign back in', (tester) async {
    await pumpApp(tester);
    await _createAdminAndSignIn(tester);

    await tester.tap(find.byIcon(Icons.manage_accounts));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add User'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Temp Worker');
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'tempworker');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'temppass1');
    await tester.tap(find.widgetWithText(FilledButton, 'Create user'));
    await tester.pumpAndSettle();

    // Disable the cashier we just created (the second row's switch).
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'tempworker');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'temppass1');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('This account has been disabled.'), findsOneWidget);
  });
}
