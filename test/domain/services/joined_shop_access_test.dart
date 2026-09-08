import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/data/payments/platform_onboarding_gateway.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import 'package:nexapos_mobile/domain/services/paystack_credentials_service.dart';

import '../../support/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late AppDatabase db;
  late FixedClock clock;
  late LicenseService service;
  var owner = false;
  var shop = 12;
  var statusCode = 200;

  setUp(() async {
    installFakeSecureStorage();
    owner = false;
    shop = 12;
    statusCode = 200;
    clock = FixedClock(DateTime.utc(2026, 9, 8));
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        platformOnboardingGatewayProvider.overrideWithValue(
          PlatformOnboardingGateway(
            MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'success': statusCode == 200,
                  'status': 'active',
                  'shop_id': shop,
                  'is_owner': owner,
                  'message': 'Access denied',
                }),
                statusCode,
              ),
            ),
          ),
        ),
      ],
    );
    await container
        .read(paystackCredentialsServiceProvider)
        .save(
          const PaystackCredentials(
            baseUrl: 'https://example.com/index.php',
            apiKey: 'test',
            currency: 'KES',
            defaultEmail: '',
          ),
        );
    service = container.read(licenseServiceProvider);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('registration alone never unlocks a device', () async {
    owner = true;
    expect(await service.hasAppAccess(), false);
    await expectLater(service.confirmJoinedMembership(), throwsStateError);
    expect(await service.hasAppAccess(), false);
  });
  test('verified membership unlocks without a standalone license and expires offline', () async {
    await service.confirmJoinedMembership();
    expect(await service.hasValidCachedLicense(), false);
    expect(await service.hasAppAccess(), true);
    clock.advance(const Duration(hours: 23));
    expect(await service.hasAppAccess(), true);
    clock.advance(const Duration(hours: 1));
    expect(await service.hasAppAccess(), false);
    await service.verifyJoinedMembership();
    expect(await service.hasAppAccess(), true);
  });
  for (final code in [401, 403]) {
    test(
      'confirmed $code removal blocks access without erasing records or own license',
      () async {
        await service.confirmJoinedMembership();
        final storage = container.read(secureStorageProvider);
        await storage.write(
          key: 'nexapos.license.activationToken',
          value: 'own-license',
        );
        final before = await db.select(db.businessSettings).get();
        statusCode = code;
        await service.verifyJoinedMembership();
        expect(await service.hasAppAccess(), false);
        expect(await service.membershipBlocked, true);
        expect(await service.hasValidCachedLicense(), true);
        expect(
          (await db.select(db.businessSettings).get()).length,
          before.length,
        );
        await expectLater(service.confirmJoinedMembership(), throwsStateError);
      },
    );
  }
  test('server failure does not revoke membership', () async {
    await service.confirmJoinedMembership();
    statusCode = 503;
    await service.verifyJoinedMembership();
    expect(await service.membershipBlocked, false);
    expect(await service.hasAppAccess(), true);
  });
  test('changed shop cannot inherit the previous membership', () async {
    await service.confirmJoinedMembership();
    shop = 99;
    await service.verifyJoinedMembership();
    expect(await service.hasAppAccess(), false);
  });
  test(
    'leaving drops joined access but keeps a separately activated license',
    () async {
      await service.confirmJoinedMembership();
      await service.clearJoinedMembership();
      expect(await service.hasAppAccess(), false);
      await container
          .read(secureStorageProvider)
          .write(key: 'nexapos.license.activationToken', value: 'own-license');
      expect(await service.hasAppAccess(), true);
    },
  );
}
