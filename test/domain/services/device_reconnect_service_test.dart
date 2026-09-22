import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/data/payments/platform_onboarding_gateway.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/auth_service.dart';
import 'package:nexapos_mobile/domain/services/device_reconnect_service.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import 'package:nexapos_mobile/domain/services/paystack_credentials_service.dart';
import 'package:nexapos_mobile/domain/services/sync_service.dart';

import '../../support/fake_secure_storage.dart';

/// A device that already belongs to a shop but lost its local sign-in used to
/// be told "This device was already registered ... tap below to reconnect" and
/// then be made to type a fresh invite code anyway. These pin the no-code
/// reconnect: it keeps the device's place in its shop, never lets an owner
/// device in without its license, and never strands a half-reconnected device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late AppDatabase db;
  late DeviceReconnectService service;
  var isOwner = false;
  var deviceStatus = 'active';
  Object? networkFailure;
  final calls = <String>[];

  setUp(() {
    installFakeSecureStorage();
    isOwner = false;
    deviceStatus = 'active';
    networkFailure = null;
    calls.clear();
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026, 9, 21))),
        platformOnboardingGatewayProvider.overrideWithValue(
          PlatformOnboardingGateway(
            MockClient((http.Request request) async {
              final action = request.url.queryParameters['action'] ?? '';
              calls.add(action);
              if (networkFailure != null) throw networkFailure!;
              switch (action) {
                case 'register_device':
                  return http.Response(jsonEncode({'success': true, 'api_key': 'recovered-key'}), 201);
                case 'client_status':
                  return http.Response(
                    jsonEncode({
                      'success': true,
                      'status': deviceStatus,
                      'shop_id': 12,
                      'is_owner': isOwner,
                    }),
                    200,
                  );
              }
              return http.Response(jsonEncode({'success': false, 'message': 'unexpected $action'}), 404);
            }),
          ),
        ),
      ],
    );
    service = container.read(deviceReconnectServiceProvider);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('a joined device with no data goes back in with no invite code and is set to download the shop', () async {
    final result = await service.reconnect(deviceLabel: 'iPhone test');

    expect(result.isOk, isTrue, reason: result.when(ok: (_) => '', failure: (m) => m));
    expect(result.when(ok: (needsDownload) => needsDownload, failure: (_) => null), isTrue);
    expect(calls, isNot(contains('join_shop')), reason: 'no invite code is used or needed');
    expect(await container.read(licenseServiceProvider).hasAppAccess(), isTrue);
    expect(await container.read(syncServiceProvider).needsInitialPull, isTrue);
    final credentials = await container.read(paystackCredentialsServiceProvider).load();
    expect(credentials.isConfigured, isTrue);
    expect(credentials.apiKey, 'recovered-key');
    expect(await container.read(paystackCredentialsServiceProvider).loadDeviceLabel(), 'iPhone test');
  });

  test('a joined device that still holds its data keeps it and just catches up', () async {
    await container.read(authServiceProvider).createUser(
      name: 'Owner',
      username: 'owner',
      password: 'long-password',
      role: UserRole.admin,
    );

    final result = await service.reconnect(deviceLabel: 'Counter 2');

    expect(result.when(ok: (needsDownload) => needsDownload, failure: (_) => null), isFalse);
    expect(await container.read(syncServiceProvider).needsInitialPull, isFalse,
        reason: 'no wipe and no re-download of data the device already has');
    expect(await container.read(licenseServiceProvider).hasAppAccess(), isTrue);
    expect((await container.read(authServiceProvider).hasAnyUsers()), isTrue);
  });

  test('an OWNER device is not let in by reconnecting - it needs its license key', () async {
    isOwner = true;

    final result = await service.reconnect(deviceLabel: 'Main till');

    expect(result.isFailure, isTrue);
    expect(result.when(ok: (_) => '', failure: (m) => m), contains('license key'));
    expect(await container.read(licenseServiceProvider).hasAppAccess(), isFalse);
    expect(await container.read(syncServiceProvider).needsInitialPull, isFalse);
  });

  test('a device the shop disabled cannot reconnect', () async {
    deviceStatus = 'disabled';

    final result = await service.reconnect(deviceLabel: 'Old phone');

    expect(result.isFailure, isTrue);
    expect(result.when(ok: (_) => '', failure: (m) => m), contains('disabled'));
    expect(await container.read(licenseServiceProvider).hasAppAccess(), isFalse);
  });

  test('no connection gives a clear message and changes nothing', () async {
    networkFailure = const SocketException('Failed host lookup');

    final result = await service.reconnect(deviceLabel: 'iPhone test');

    expect(result.when(ok: (_) => '', failure: (m) => m), contains('Could not reach the server'));
    expect(await container.read(licenseServiceProvider).hasAppAccess(), isFalse);
    expect(await container.read(syncServiceProvider).needsInitialPull, isFalse,
        reason: 'must not be left half-prepared waiting for a shop it never re-entered');
  });

  test('a slow server says so instead of claiming the device is offline', () async {
    networkFailure = TimeoutException('no answer');

    final result = await service.reconnect(deviceLabel: 'iPhone test');

    expect(result.when(ok: (_) => '', failure: (m) => m), contains('slow to answer'));
  });

  test('an empty label is refused before anything is sent', () async {
    final result = await service.reconnect(deviceLabel: '   ');

    expect(result.isFailure, isTrue);
    expect(calls, isEmpty);
  });
}
