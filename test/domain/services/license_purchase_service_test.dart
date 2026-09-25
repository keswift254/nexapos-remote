import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/secure_storage_provider.dart';
import 'package:nexapos_mobile/data/licensing/license_gateway.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/domain/services/license_purchase_service.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';

import '../../support/fake_license_server.dart';
import '../../support/fake_secure_storage.dart';

class _FixedDevice extends SyncMetadataService {
  _FixedDevice(super.db);
  @override
  Future<String> deviceId() async => 'test-device';
}

const _m6 = PurchasePlan(id: 'm6', label: '6 months', months: 6, amountKes: 3000);
const _pendingKey = 'nexapos.purchase.pending';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLicenseServer server;
  late AppDatabase db;
  late ProviderContainer container;
  late List<Uri> opened;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    installFakeSecureStorage();
    server = FakeLicenseServer();
    opened = [];
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
      syncMetadataProvider.overrideWithValue(_FixedDevice(db)),
      licenseGatewayProvider.overrideWith((ref) => LicenseGateway(server.client)),
      urlOpenerProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return true;
      }),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  LicensePurchaseService service() => container.read(licensePurchaseServiceProvider);
  Future<String?> stored(String key) => container.read(secureStorageProvider).read(key: key);

  group('start', () {
    test('asks the server for a checkout, and remembers the purchase', () async {
      final purchase = await service().start(_m6, ' buyer@example.com ');

      expect(server.lastStart, {'device_id': 'test-device', 'plan_id': 'm6', 'email': 'buyer@example.com'});
      expect(purchase.reference, 'nxl-test0001');
      expect(purchase.planLabel, '6 months');
      expect(purchase.amountKes, 3000);
      expect(purchase.paymentUrl, 'https://checkout.paystack.com/test0001');
      final again = await service().pending();
      expect(again!.reference, 'nxl-test0001');
      expect(again.amountKes, 3000);
    });

    test('remembers the email to offer next time', () async {
      expect(await service().lastEmail(), isNull);

      await service().start(_m6, 'buyer@example.com');

      expect(await service().lastEmail(), 'buyer@example.com');
    });

    test('a refusal throws the server\'s own words and remembers nothing', () async {
      server.startAnswer = http.Response(
        jsonEncode({'success': false, 'message': 'Too many payment attempts from this device. Try again in a little while.'}),
        429,
      );

      await expectLater(
        service().start(_m6, 'buyer@example.com'),
        throwsA(isA<LicenseException>().having((e) => e.message, 'message', contains('Too many payment attempts'))),
      );
      expect(await service().pending(), isNull);
      expect(await service().lastEmail(), isNull);
    });

    test('offline is an offline error and remembers nothing', () async {
      server.offline = true;

      await expectLater(service().start(_m6, 'buyer@example.com'), throwsA(isA<LicenseOfflineException>()));
      expect(await service().pending(), isNull);
    });
  });

  group('pending', () {
    test('nothing in progress, nothing returned', () async {
      expect(await service().pending(), isNull);
    });

    test('a purchase left for more than a day is forgotten', () async {
      await service().start(_m6, 'buyer@example.com');
      final raw = jsonDecode((await stored(_pendingKey))!) as Map<String, dynamic>;
      raw['startedAt'] = DateTime.now().toUtc().subtract(pendingPurchaseLifetime + const Duration(minutes: 1)).toIso8601String();
      await container.read(secureStorageProvider).write(key: _pendingKey, value: jsonEncode(raw));

      expect(await service().pending(), isNull);
      expect(await stored(_pendingKey), isNull, reason: 'and the stale record is cleared');
    });

    test('one just under a day old is still there', () async {
      await service().start(_m6, 'buyer@example.com');
      final raw = jsonDecode((await stored(_pendingKey))!) as Map<String, dynamic>;
      raw['startedAt'] = DateTime.now().toUtc().subtract(pendingPurchaseLifetime - const Duration(minutes: 5)).toIso8601String();
      await container.read(secureStorageProvider).write(key: _pendingKey, value: jsonEncode(raw));

      expect(await service().pending(), isNotNull);
    });

    test('an unreadable record is ignored and cleared, not a crash', () async {
      await container.read(secureStorageProvider).write(key: _pendingKey, value: '{not json');

      expect(await service().pending(), isNull);
      expect(await stored(_pendingKey), isNull);
    });
  });

  group('check', () {
    test('nothing in progress: nothing to check, and the server is not asked', () async {
      final result = await service().check();

      expect(result.kind, PurchaseCheckKind.none);
      expect(server.statusCalls, 0);
    });

    test('not paid yet: keep waiting, keep the purchase', () async {
      await service().start(_m6, 'buyer@example.com');

      final result = await service().check();

      expect(result.kind, PurchaseCheckKind.pending);
      expect(await service().pending(), isNotNull);
    });

    test('paid: activates this device with the license the server issued, then forgets the purchase', () async {
      await service().start(_m6, 'buyer@example.com');
      server.statusScript = [{'success': true, 'status': 'issued', 'code': FakeLicenseServer.licenseCode}];

      final result = await service().check();

      expect(result.kind, PurchaseCheckKind.activated);
      expect(server.activatedCodes, [FakeLicenseServer.licenseCode]);
      expect(await container.read(licenseServiceProvider).hasValidCachedLicense(), isTrue);
      expect(await service().pending(), isNull);
    });

    test('failed: the purchase is forgotten and the reason is passed on', () async {
      await service().start(_m6, 'buyer@example.com');
      server.statusScript = [{'success': true, 'status': 'failed', 'message': 'The payment did not go through.'}];

      final result = await service().check();

      expect(result.kind, PurchaseCheckKind.failed);
      expect(result.message, contains('did not go through'));
      expect(await service().pending(), isNull);
      expect(server.activateCalls, 0, reason: 'nothing to activate');
    });

    test('a payment the server does not know is dropped with an explanation', () async {
      await service().start(_m6, 'buyer@example.com');
      server.statusScript = [http.Response(jsonEncode({'success': false, 'message': 'Unknown payment.'}), 404)];

      final result = await service().check();

      expect(result.kind, PurchaseCheckKind.failed);
      expect(result.message, contains('could not be found'));
      expect(await service().pending(), isNull);
    });

    test('offline: the payment is not in doubt, and stays in progress', () async {
      await service().start(_m6, 'buyer@example.com');
      server.statusScript = [const SocketException('no internet')];

      final result = await service().check();

      expect(result.kind, PurchaseCheckKind.offline);
      expect(result.message, contains('safe'));
      expect(await service().pending(), isNotNull);
    });

    test('a server hiccup is a problem to retry, not an ending', () async {
      await service().start(_m6, 'buyer@example.com');
      server.statusScript = [
        http.Response(jsonEncode({'success': false, 'message': 'Your payment went through, but the license could not be created yet. Try again in a moment.'}), 500),
      ];

      final result = await service().check();

      expect(result.kind, PurchaseCheckKind.problem);
      expect(result.message, contains('went through'));
      expect(await service().pending(), isNotNull);
    });

    test('paid but this device could not take the license yet: kept, and retried successfully next time', () async {
      await service().start(_m6, 'buyer@example.com');
      server.statusScript = [{'success': true, 'status': 'issued', 'code': FakeLicenseServer.licenseCode}];
      server.activateAnswer = http.Response(jsonEncode({'success': false, 'message': 'Server busy.'}), 503);

      final first = await service().check();
      expect(first.kind, PurchaseCheckKind.problem);
      expect(await service().pending(), isNotNull, reason: 'the payment is not lost');
      expect(await container.read(licenseServiceProvider).hasValidCachedLicense(), isFalse);

      server.activateAnswer = null;
      final second = await service().check();

      expect(second.kind, PurchaseCheckKind.activated);
      expect(server.activatedCodes, [FakeLicenseServer.licenseCode, FakeLicenseServer.licenseCode], reason: 'the same license both times');
      expect(await service().pending(), isNull);
    });
  });

  group('the payment page', () {
    test('opens the address the server gave', () async {
      final purchase = await service().start(_m6, 'buyer@example.com');

      expect(await service().openPaymentPage(purchase), isTrue);

      expect(opened, [Uri.parse('https://checkout.paystack.com/test0001')]);
    });

    test('a browser that cannot be opened is reported, not thrown', () async {
      final purchase = await service().start(_m6, 'buyer@example.com');
      container.dispose();
      container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWith((ref) => db),
        syncMetadataProvider.overrideWithValue(_FixedDevice(db)),
        licenseGatewayProvider.overrideWith((ref) => LicenseGateway(server.client)),
        urlOpenerProvider.overrideWithValue((uri) async => throw StateError('no browser')),
      ]);

      expect(await service().openPaymentPage(purchase), isFalse);
    });
  });

  group('restoring a license', () {
    test('asking for a code sends this device and the email, and remembers the email', () async {
      final outcome = await service().requestRestoreCode(' me@shop.co.ke ');

      expect(outcome.ok, isTrue);
      expect(outcome.message, contains('6-digit code'));
      expect(server.lastRestoreStart, {'device_id': 'test-device', 'email': 'me@shop.co.ke'});
      expect(await service().lastEmail(), 'me@shop.co.ke', reason: 'offered next time, also when buying');
    });

    test('a refusal is a message, not an exception, and remembers nothing', () async {
      server.restoreStartAnswer = http.Response(
        jsonEncode({'success': false, 'message': 'Too many attempts. Wait a little while, then try again.'}),
        429,
      );

      final outcome = await service().requestRestoreCode('me@shop.co.ke');

      expect(outcome.ok, isFalse);
      expect(outcome.message, contains('Too many attempts'));
      expect(await service().lastEmail(), isNull);
    });

    test('no internet while asking for a code says so', () async {
      server.offline = true;

      final outcome = await service().requestRestoreCode('me@shop.co.ke');

      expect(outcome.ok, isFalse);
      expect(outcome.message, contains('Could not reach the server'));
    });

    test('the right code brings the license to this device and activates it', () async {
      final outcome = await service().restore(' me@shop.co.ke ', '123456');

      expect(outcome.ok, isTrue);
      expect(server.lastRestoreConfirm, {'device_id': 'test-device', 'email': 'me@shop.co.ke', 'code': '123456'});
      expect(server.activatedCodes, [FakeLicenseServer.restoredLicenseCode]);
      expect(await container.read(licenseServiceProvider).hasValidCachedLicense(), isTrue);
    });

    test('a wrong code is refused in the server\'s words and activates nothing', () async {
      final outcome = await service().restore('me@shop.co.ke', '000000');

      expect(outcome.ok, isFalse);
      expect(outcome.message, contains('not right'));
      expect(server.activateCalls, 0);
      expect(await container.read(licenseServiceProvider).hasValidCachedLicense(), isFalse);
    });

    test('no internet while confirming says so and activates nothing', () async {
      server.offline = true;

      final outcome = await service().restore('me@shop.co.ke', '123456');

      expect(outcome.ok, isFalse);
      expect(outcome.message, contains('Could not reach the server'));
      expect(server.activateCalls, 0);
    });

    test('a license the server restored but this device could not take yet is reported, not hidden', () async {
      server.activateAnswer = http.Response(jsonEncode({'success': false, 'message': 'This license has expired. Ask support to extend it first.'}), 422);

      final outcome = await service().restore('me@shop.co.ke', '123456');

      expect(outcome.ok, isFalse);
      expect(outcome.message, contains('expired'));
      expect(await container.read(licenseServiceProvider).hasValidCachedLicense(), isFalse);
    });
  });

  test('cancel forgets the purchase on this device', () async {
    await service().start(_m6, 'buyer@example.com');

    await service().cancel();

    expect(await service().pending(), isNull);
  });

  test('plans come from the server', () async {
    final catalog = await service().loadPlans();

    expect(catalog.plans.map((p) => p.id), ['m3', 'm6', 'm12']);
    expect(catalog.purchasingEnabled, isTrue);
  });
}
