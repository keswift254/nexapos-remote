import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:otp/otp.dart';
import 'package:nexapos_mobile/core/utils/id_generator.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/data/payments/platform_onboarding_gateway.dart';
import 'package:nexapos_mobile/data/repositories/user_repository_impl.dart';
import 'package:nexapos_mobile/data/sync/platform_sync_gateway.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/auth_service.dart';
import 'package:nexapos_mobile/domain/services/paystack_credentials_service.dart';
import 'package:nexapos_mobile/domain/services/sensitive_action_service.dart';
import 'package:nexapos_mobile/domain/services/shop_safety_service.dart';
import 'package:nexapos_mobile/domain/services/sync_service.dart';

import '../../support/fake_secure_storage.dart';
import 'sensitive_action_service_test.dart' show TestClock;

class FakeMembership extends PlatformOnboardingGateway {
  int shop = 1;
  bool fail = false;
  int calls = 0;
  @override
  Future<ClientStatus> getClientStatus({
    required String baseUrl,
    required String apiKey,
  }) async => ClientStatus(
    shopId: shop,
    status: 'active',
    businessName: '',
    settlementType: '',
    bankCode: '',
    accountNumber: '',
    accountName: '',
    subaccountCode: '',
    isVerified: false,
    isOwner: true,
  );
  @override
  Future<void> leaveShop({
    required String baseUrl,
    required String apiKey,
  }) async {
    calls++;
    if (fail) throw StateError('Connection lost');
    shop = 2;
  }

  @override
  Future<void> joinShop({
    required String baseUrl,
    required String apiKey,
    required String inviteCode,
  }) => leaveShop(baseUrl: baseUrl, apiKey: apiKey);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  const credentials = PaystackCredentials(
    baseUrl: 'http://localhost/platform',
    apiKey: 'test',
    currency: 'KES',
    defaultEmail: '',
  );
  const secret = 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP';
  late AppDatabase db;
  late TestClock clock;
  late SensitiveActionService security;
  late SyncService sync;
  late FakeMembership gateway;
  late ShopSafetyService service;
  late List<String?> requests;
  setUp(() async {
    installFakeSecureStorage();
    db = AppDatabase(NativeDatabase.memory());
    clock = TestClock();
    final meta = SyncMetadataService(db);
    final auth = AuthService(
      UserRepositoryImpl(db, db.usersDao, meta, clock, UuidIdGenerator()),
      UuidIdGenerator(),
    );
    final owner = await auth.createUser(
      name: 'Owner',
      username: 'owner',
      password: 'long-password',
      role: UserRole.admin,
    );
    final id = owner.when(ok: (u) => u.id, failure: (e) => throw StateError(e));
    security = SensitiveActionService(
      auth,
      const FlutterSecureStorage(),
      clock,
      () => id,
    );
    final stored = PaystackCredentialsService(const FlutterSecureStorage());
    await stored.save(credentials);
    requests = [];
    gateway = FakeMembership();
    sync = SyncService(
      db,
      meta,
      PlatformSyncGateway(
        MockClient((request) async {
          requests.add(request.url.queryParameters['action']);
          return http.Response(
            jsonEncode({
              'success': true,
              'changes': [],
              'next_cursor': 0,
              'has_more': false,
            }),
            200,
          );
        }),
      ),
      stored,
      onboarding: gateway,
    );
    service = ShopSafetyService(db, sync, security, gateway);
  });
  tearDown(() => db.close());

  test('initial join rejects a device that already has business data', () async {
    await expectLater(sync.prepareInitialJoin(1), throwsStateError);
    expect(await sync.needsInitialPull, isFalse);
    expect(await db.select(db.users).get(), hasLength(1));
  });

  test('interrupted initial join to the same server shop safely returns to setup', () async {
    await db.resetForFreshStart();
    await sync.prepareInitialJoin(1);
    expect(await sync.needsInitialPull, isTrue);
    await sync.runSyncCycle();
    expect(await sync.needsInitialPull, isFalse);
    expect(await db.select(db.businessSettings).get(), hasLength(1));
    expect(await db.select(db.users).get(), isEmpty);
    expect(requests.first, 'push_changes');
  });

  Future<ActionApproval> approve(String action) {
    clock.value = clock.value.add(const Duration(seconds: 30));
    return security.approve(
      username: 'owner',
      password: 'long-password',
      action: action,
      enrollmentSecret: secret,
      code: OTP.generateTOTPCodeString(
        secret,
        clock.now().millisecondsSinceEpoch,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      ),
    );
  }

  test(
    'cancelling backup retains data and never mutates server membership',
    () async {
      final result = await service.changeShop(
        approval: await approve('Leave this shop'),
        credentials: credentials,
        saveRecovery: (_) async => false,
      );
      expect(result, isFalse);
      expect(gateway.calls, 0);
      expect(await sync.hasPendingShopChange, isFalse);
      expect(await db.select(db.users).get(), hasLength(1));
    },
  );

  test('writes are blocked while backup is saved; failed backup unlocks intact data', () async {
    await expectLater(
      service.changeShop(
        approval: await approve('Leave this shop'),
        credentials: credentials,
        saveRecovery: (archive) async {
          expect(archive.tables['users'], hasLength(1));
          await expectLater(db.delete(db.users).go(), throwsA(anything));
          throw StateError('Disk full');
        },
      ),
      throwsStateError,
    );
    expect(await sync.hasPendingShopChange, isFalse);
    expect(gateway.calls, 0);
    expect(await db.select(db.users).get(), hasLength(1));
  });

  test('ambiguous network failure retains data, blocks writes and sync, unchanged membership can recover', () async {
    gateway.fail = true;
    await expectLater(
      service.changeShop(
        approval: await approve('Leave this shop'),
        credentials: credentials,
        saveRecovery: (_) async => true,
      ),
      throwsStateError,
    );
    expect(await sync.hasPendingShopChange, isTrue);
    await sync.runSyncCycle();
    expect(requests, isEmpty);
    await expectLater(db.delete(db.users).go(), throwsA(anything));
    expect(
      await service.resolveChange(
        await approve('Resolve shop change'),
        credentials,
      ),
      isFalse,
    );
    expect(await sync.hasPendingShopChange, isFalse);
    expect(await db.select(db.users).get(), hasLength(1));
  });

  test(
    'resolved remote switch resets data once and downloads before any upload',
    () async {
      gateway.fail = true;
      await expectLater(
        service.changeShop(
          approval: await approve('Switch shop'),
          credentials: credentials,
          inviteCode: 'TESTCODE',
          saveRecovery: (_) async => true,
        ),
        throwsStateError,
      );
      gateway.shop = 2;
      expect(
        await service.resolveChange(
          await approve('Resolve shop change'),
          credentials,
        ),
        isTrue,
      );
      expect(await db.select(db.users).get(), isEmpty);
      expect(await db.select(db.businessSettings).get(), isEmpty);
      expect(await sync.needsInitialPull, isTrue);
      await sync.runSyncCycle();
      expect(requests, ['pull_changes']);
      expect(await sync.needsInitialPull, isTrue);
      expect(sync.lastError, contains('Waiting for the joined shop'));
    },
  );

  test('successful leave requires saved backup and removes only local business rows', () async {
    final identity = await db.select(db.deviceMeta).getSingle();
    expect(
      await service.changeShop(
        approval: await approve('Leave this shop'),
        credentials: credentials,
        saveRecovery: (_) async => true,
      ),
      isTrue,
    );
    expect(await db.select(db.users).get(), isEmpty);
    expect(await db.select(db.roles).get(), hasLength(3));
    expect(
      (await db.select(db.deviceMeta).getSingle()).deviceId,
      identity.deviceId,
    );
    expect(await sync.hasPendingShopChange, isFalse);
  });
}
