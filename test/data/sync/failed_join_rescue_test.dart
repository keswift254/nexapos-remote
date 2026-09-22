import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/data/payments/platform_onboarding_gateway.dart';
import 'package:nexapos_mobile/data/sync/platform_sync_gateway.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/services/paystack_credentials_service.dart';
import 'package:nexapos_mobile/domain/services/sync_service.dart';

/// A device that STARTS joining a shop (prepareInitialJoin) and then fails -
/// an expired or already-used invite code is the usual reason - has neither a
/// license nor a shop membership, so SyncService refuses to sync for it. Its
/// cleanup used to sit behind that same refusal, leaving the join screen
/// waiting on "the shop's data" forever. These pin down the rescue.
class _Credentials implements PaystackCredentialsService {
  PaystackCredentials credentials;
  _Credentials(this.credentials);
  @override
  Future<PaystackCredentials> load() async => credentials;
  @override
  Future<void> save(PaystackCredentials value) async => credentials = value;
  @override
  Future<String> loadDeviceLabel() async => '';
  @override
  Future<void> saveDeviceLabel(String label) async {}
  @override
  Future<void> clearRegistration() async {}
}

void main() {
  late AppDatabase db;
  late SyncMetadataService meta;
  var serverShop = 12; // the shop the SERVER says this device is in
  var serverSaysOwner = true;
  var serverDown = false;
  var statusChecks = 0;

  const configured = PaystackCredentials(
    baseUrl: 'https://example.com/index.php',
    apiKey: 'device-key',
    currency: 'KES',
    defaultEmail: '',
  );

  SyncService buildService({required bool hasAccess}) => SyncService(
    db,
    meta,
    PlatformSyncGateway(MockClient((_) async => http.Response('{"success":true}', 200))),
    _Credentials(configured),
    onboarding: PlatformOnboardingGateway(
      MockClient((_) async {
        statusChecks++;
        if (serverDown) throw http.ClientException('offline');
        return http.Response(
          jsonEncode({
            'success': true,
            'status': 'active',
            'shop_id': serverShop,
            'is_owner': serverSaysOwner,
          }),
          200,
        );
      }),
    ),
    canSync: () async => hasAccess,
  );

  Future<void> putCategory() => db.into(db.categories).insert(
    CategoriesCompanion.insert(
      id: 'pulled-1',
      name: 'Groceries',
      createdAt: '2026-09-20T00:00:00.000Z',
      updatedAt: '2026-09-20T00:00:00.000Z',
      localRev: 1,
      createdByDeviceId: 'other-device',
    ),
  );
  Future<int> categories() async => (await db.select(db.categories).get()).length;
  Future<bool> marker(String id) async => (await db
      .customSelect("SELECT id FROM local_safety_state WHERE id='$id'")
      .get()).isNotEmpty;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    meta = SyncMetadataService(db);
    serverShop = 12;
    serverSaysOwner = true;
    serverDown = false;
    statusChecks = 0;
  });
  tearDown(() => db.close());

  test(
    'a join that never took effect is undone even though the device has no access to sync',
    () async {
      final sync = buildService(hasAccess: false);
      await sync.prepareInitialJoin(12); // marks the device as "joining shop 12's replacement"
      expect(await sync.needsInitialPull, isTrue);

      // The invite code was rejected: the server still has the device in its own
      // original shop 12, as that shop's owner.
      await sync.runSyncCycle();

      expect(await sync.needsInitialPull, isFalse, reason: 'no longer stuck waiting for a shop it never joined');
      expect(await marker('initial_join'), isFalse);
      expect(await marker('shop_hydration'), isFalse);
      expect(sync.lastError, contains('Activate this device'), reason: 'still tells the person why it cannot sync');
    },
  );

  test('a join that DID take effect is left alone (no wipe, still hydrating)', () async {
    final sync = buildService(hasAccess: false);
    await sync.prepareInitialJoin(12);
    await putCategory(); // data already arriving from the joined shop
    serverShop = 99; // the server moved this device into the invited shop
    serverSaysOwner = false;

    await sync.runSyncCycle();

    expect(await sync.needsInitialPull, isTrue, reason: 'the join is real - it must finish hydrating');
    expect(await categories(), 1, reason: 'nothing pulled from the joined shop may be wiped');
    expect(await marker('initial_join'), isTrue);
  });

  test('offline during the rescue changes nothing and does not throw', () async {
    final sync = buildService(hasAccess: false);
    await sync.prepareInitialJoin(12);
    serverDown = true;

    await expectLater(sync.runSyncCycle(), completes);

    expect(await sync.needsInitialPull, isTrue, reason: 'try again next cycle rather than guess');
    expect(await marker('initial_join'), isTrue);
    expect(statusChecks, greaterThan(0));
  });

  test('a device with access is unaffected by the rescue path', () async {
    final sync = buildService(hasAccess: true);
    await sync.prepareInitialJoin(12);
    serverShop = 99;
    serverSaysOwner = false;

    await sync.runSyncCycle();

    // With access the normal cycle runs (it confirms the join and hydrates); the
    // rescue must not have fired and undone it.
    expect(statusChecks, greaterThan(0));
  });

  test('reconcileFailedInitialJoin (the Retry button) still works the same', () async {
    final sync = buildService(hasAccess: false);
    await sync.prepareInitialJoin(12);

    await sync.reconcileFailedInitialJoin();

    expect(await sync.needsInitialPull, isFalse);
    expect(await marker('initial_join'), isFalse);
  });

  test('nothing to undo when the device was never joining', () async {
    final sync = buildService(hasAccess: false);

    await sync.runSyncCycle();

    expect(statusChecks, 0, reason: 'no marker means no server call is needed');
    expect(await sync.needsInitialPull, isFalse);
  });
}
