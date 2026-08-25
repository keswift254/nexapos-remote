import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nexapos_mobile/app.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/data/licensing/license_gateway.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import '../../support/fake_secure_storage.dart';

void main() {
  // hasCachedLicenseProvider awaits a real read - see
  // fake_secure_storage.dart for why that needs a channel mock here.
  setUp(installFakeSecureStorage);

  Future<void> pumpApp(WidgetTester tester, {required http.Client licenseClient}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) {
            final db = AppDatabase(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
          licenseGatewayProvider.overrideWith((ref) => LicenseGateway(licenseClient)),
        ],
        child: const NexaPosApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a valid code activates the app and reveals setup', (tester) async {
    await pumpApp(
      tester,
      licenseClient: MockClient((request) async {
        expect(request.url.queryParameters['action'], 'activate');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['code'], 'L3RLFCH5KA');
        return http.Response(jsonEncode({'success': true, 'activation_token': 'a' * 64}), 200);
      }),
    );

    expect(find.text('Activate NexaPOS'), findsOneWidget);
    expect(find.text('Set up NexaPOS'), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, 'License key'), 'L3RLFCH5KA');
    await tester.tap(find.widgetWithText(FilledButton, 'Activate'));
    await tester.pumpAndSettle();

    // The gate opened - proving activate() -> secure-storage write ->
    // LicenseChangeSignal bump -> router redirect all work together,
    // landing on the very next gate (setup, since the DB is fresh).
    expect(find.text('Activate NexaPOS'), findsNothing);
    expect(find.text('Set up NexaPOS'), findsOneWidget);
  });

  testWidgets('a rejected code shows the backend message and stays on the gate', (tester) async {
    await pumpApp(
      tester,
      licenseClient: MockClient((request) async {
        return http.Response(jsonEncode({'success': false, 'message': 'Invalid license key.'}), 422);
      }),
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'License key'), 'BADCODE123');
    await tester.tap(find.widgetWithText(FilledButton, 'Activate'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid license key.'), findsOneWidget);
    expect(find.text('Activate NexaPOS'), findsOneWidget);
    expect(find.text('Set up NexaPOS'), findsNothing);
  });

  testWidgets('an unreachable license server shows a clear offline message', (tester) async {
    await pumpApp(
      tester,
      licenseClient: MockClient((request) async {
        throw http.ClientException('Connection failed');
      }),
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'License key'), 'L3RLFCH5KA');
    await tester.tap(find.widgetWithText(FilledButton, 'Activate'));
    await tester.pumpAndSettle();

    expect(find.text('Could not reach the license server. Check your internet connection and try again.'),
        findsOneWidget);
    expect(find.text('Activate NexaPOS'), findsOneWidget);
  });
}
