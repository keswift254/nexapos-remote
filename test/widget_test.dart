import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/app.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import 'package:nexapos_mobile/features/settings/payment_settings_screen.dart' show currentPaymentCredentialsProvider;

void main() {
  testWidgets('fresh install with no users lands on the setup screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) {
            final db = AppDatabase(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
          // Setup/login is what this test exercises - licensing and
          // device-sync registration are covered separately.
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

    expect(find.text('Set up NexaPOS'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });
}
