import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:nexapos_mobile/app.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import 'package:nexapos_mobile/features/settings/payment_settings_screen.dart' show currentPaymentCredentialsProvider;

void main() {
  testWidgets(
    'popping the receipt screen always lands on the dashboard, even with an unrelated route left on the stack beneath it',
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
            currentPaymentCredentialsProvider.overrideWith(
              (ref) async => const PaystackCredentials(
                  baseUrl: 'https://test.example/index.php', apiKey: 'test-api-key', currency: 'KES', defaultEmail: ''),
            ),
          ],
          child: const NexaPosApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Your name'), 'Owner');
      await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'owner');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'ownerpass');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), 'ownerpass');
      await tester.tap(find.widgetWithText(FilledButton, 'Create admin account'));
      await tester.pumpAndSettle();

      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));

      // Simulate "something got left on the stack beneath the receipt" -
      // stands in for whatever a go()+push() race, or the real-world
      // trigger this bug was actually reported from (backgrounding the
      // app to an external browser for Paystack checkout, then
      // resuming - a genuine edge case for how the OS/engine restores
      // navigation state), might leave behind. See receipt_screen.dart's
      // PopScope doc comment for why it must not matter which one it is.
      router.push('/products');
      await tester.pumpAndSettle();
      expect(find.text('Inventory'), findsOneWidget);

      router.push('/receipt/does-not-exist');
      await tester.pumpAndSettle();
      expect(find.text('Receipt'), findsOneWidget);

      // What the user's bug report actually described doing.
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Must land on the dashboard - never on the '/products' debris,
      // and never stuck back on the receipt itself.
      expect(find.text('Inventory'), findsNothing);
      expect(find.text('Receipt'), findsNothing);
    },
  );
}
