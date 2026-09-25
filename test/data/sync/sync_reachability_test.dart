import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/core/utils/id_generator.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Category;
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/data/repositories/category_repository_impl.dart';
import 'package:nexapos_mobile/data/sync/platform_sync_gateway.dart';
import 'package:nexapos_mobile/data/sync/server_reachability.dart';
import 'package:nexapos_mobile/domain/entities/category.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/services/paystack_credentials_service.dart';
import 'package:nexapos_mobile/domain/services/sync_service.dart';

const _configured = PaystackCredentials(
  baseUrl: 'https://sync.example/index.php', apiKey: 'device-key', currency: 'KES', defaultEmail: '',
);

class _Credentials implements PaystackCredentialsService {
  _Credentials(this.credentials);
  PaystackCredentials credentials;
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
  group('serverReachable', () {
    test('a server that is listening is reachable', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      expect(await serverReachable('http://127.0.0.1:${server.port}/index.php'), isTrue);
    });

    test('a port nothing is listening on is not reachable, and says so quickly', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await server.close();
      final started = DateTime.now();

      expect(await serverReachable('http://127.0.0.1:$port/index.php'), isFalse);
      expect(DateTime.now().difference(started), lessThan(const Duration(seconds: 3)));
    });

    test('an address that never answers gives up after the timeout instead of hanging', () async {
      final started = DateTime.now();

      // TEST-NET-3: reserved, never routed. Either nothing answers (times out) or
      // there is no route at all (fails at once) - both mean "not reachable".
      final result = await serverReachable(
        'http://203.0.113.1:81/index.php',
        timeout: const Duration(milliseconds: 300),
      );

      expect(result, isFalse);
      expect(DateTime.now().difference(started), lessThan(const Duration(seconds: 5)));
    });

    test('a name that does not resolve is not reachable', () async {
      expect(
        await serverReachable('https://no-such-host.invalid/index.php', timeout: const Duration(seconds: 2)),
        isFalse,
      );
    });

    test('an address it cannot make sense of is left to the real request to judge', () async {
      expect(await serverReachable(''), isTrue);
      expect(await serverReachable('not a url at all'), isTrue);
    });
  });

  group('the cloud sync cycle and the queue LAN changes wait in', () {
    late AppDatabase db;
    late SyncMetadataService meta;
    late int requests;
    late Completer<void> serverAnswers;

    setUp(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      db = AppDatabase(NativeDatabase.memory());
      meta = SyncMetadataService(db);
      requests = 0;
      serverAnswers = Completer<void>();
    });

    tearDown(() async {
      if (!serverAnswers.isCompleted) serverAnswers.complete();
      await db.close();
    });

    SyncService build({Future<bool> Function(String baseUrl)? isReachable, PaystackCredentials credentials = _configured}) {
      return SyncService(
        db,
        meta,
        PlatformSyncGateway(MockClient((request) async {
          requests++;
          await serverAnswers.future; // an internet request that is slow to give up
          return http.Response('{"success":true,"changes":[],"next_cursor":0}', 200);
        })),
        _Credentials(credentials),
        canSync: () async => true,
        isReachable: isReachable,
      );
    }

    /// One change made on another device, ready to be applied here.
    Future<List<LanSyncChange>> changeFromAnotherTill() async {
      final otherDb = AppDatabase(NativeDatabase.memory());
      addTearDown(otherDb.close);
      final otherMeta = SyncMetadataService(otherDb);
      await CategoryRepositoryImpl(otherDb, otherDb.categoriesDao, otherMeta, const SystemClock(), UuidIdGenerator())
          .create(const Category(id: 'from-till-2', name: 'Made on till 2', status: 'active'));
      final other = SyncService(
        otherDb, otherMeta, PlatformSyncGateway(MockClient((_) async => throw StateError('unused'))), _Credentials(_configured),
      );
      final changes = await other.exportLanChanges({});
      return changes.where((c) => c.rowId == 'from-till-2').toList();
    }

    test('with no route to the server the cycle is not started at all', () async {
      final service = build(isReachable: (_) async => false);

      await service.runSyncCycle();

      expect(requests, 0, reason: 'no request was even attempted');
      expect(service.lastError, startsWith('Offline.'));
    });

    test('...so a change arriving over the LAN is applied at once, not queued behind it', () async {
      final service = build(isReachable: (_) async => false);
      final changes = await changeFromAnotherTill();

      unawaited(service.runSyncCycle());
      await service.applyLanChanges(changes).timeout(
        const Duration(seconds: 2),
        onTimeout: () => fail('the LAN change was stuck behind a cloud cycle that cannot succeed'),
      );

      final rows = await db.select(db.categories).get();
      expect(rows.where((r) => r.id == 'from-till-2'), hasLength(1));
    });

    test('the server is asked about using the address this device syncs with', () async {
      String? asked;
      final service = build(isReachable: (baseUrl) async {
        asked = baseUrl;
        return false;
      });

      await service.runSyncCycle();

      expect(asked, _configured.baseUrl);
    });

    test('with a route to the server the cycle goes ahead as before', () async {
      serverAnswers.complete();
      final service = build(isReachable: (_) async => true);

      await service.runSyncCycle();

      expect(requests, greaterThan(0));
    });

    test('a device that is not set up to sync is not probed at all', () async {
      var probes = 0;
      final service = build(
        credentials: _configured.copyWith(baseUrl: '', apiKey: ''),
        isReachable: (_) async {
          probes++;
          return false;
        },
      );

      await service.runSyncCycle();

      expect(probes, 0);
      expect(requests, 0);
    });

    test('without a probe (as in every other test) nothing changes', () async {
      serverAnswers.complete();
      final service = build();

      await service.runSyncCycle();

      expect(requests, greaterThan(0));
    });

    test('a slow server that IS reachable no longer holds a LAN change: the waiting cloud request steps aside', () async {
      // A route that exists but answers slowly (a server waking up). The change from
      // the till next to this one must not wait for it.
      final service = build(isReachable: (_) async => true);
      final changes = await changeFromAnotherTill();

      final cycle = service.runSyncCycle();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(requests, greaterThan(0), reason: 'the cloud cycle is out waiting on the server');

      var applied = false;
      final apply = service.applyLanChanges(changes).then((_) => applied = true);
      await apply.timeout(const Duration(seconds: 2)); // the server has NOT answered
      expect(applied, isTrue);
      expect((await db.select(db.categories).get()).any((r) => r.id == 'from-till-2'), isTrue);

      await cycle.timeout(const Duration(seconds: 2)); // and the cycle itself ended, not left hanging
      expect(service.lastError, isNull, reason: 'setting aside for a nearby device is not "offline"');
      expect(service.progress.value.message, isNot(contains('Offline')));
      expect(service.progress.value.busy, isFalse);
    });

    test('after a LAN change took priority the next cloud cycle works normally', () async {
      final service = build(isReachable: (_) async => true);
      final changes = await changeFromAnotherTill();
      final cycle = service.runSyncCycle();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await service.applyLanChanges(changes).timeout(const Duration(seconds: 2));
      await cycle.timeout(const Duration(seconds: 2));

      serverAnswers.complete();
      final before = requests;
      await service.runSyncCycle().timeout(const Duration(seconds: 5));

      expect(requests, greaterThan(before), reason: 'requests are allowed again once the change is in');
      expect(service.lastError, isNull);
      expect(service.lastSuccess, isNotNull);
    });

    test('a LAN change with nothing in it does not disturb a cloud cycle', () async {
      final service = build(isReachable: (_) async => true);
      final cycle = service.runSyncCycle();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await service.applyLanChanges(const []).timeout(const Duration(milliseconds: 500));
      serverAnswers.complete();
      await cycle.timeout(const Duration(seconds: 5));

      expect(service.lastSuccess, isNotNull, reason: 'the cycle was not set aside for a no-op');
    });

    test('joining a shop and its first download are NOT set aside - a LAN change waits for them', () async {
      await db.customStatement("INSERT INTO local_safety_state(id, value) VALUES('shop_hydration', 'pending')");
      final service = build(isReachable: (_) async => true);
      final changes = await changeFromAnotherTill();

      final cycle = service.runSyncCycle();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(requests, greaterThan(0), reason: 'the first download is out waiting on the server');
      var applied = false;
      final apply = service.applyLanChanges(changes).then((_) => applied = true);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(applied, isFalse, reason: 'the first download runs to the end before anything else');

      serverAnswers.complete();
      await cycle;
      await apply;
      expect(applied, isTrue);
    });

    test('offline, repeated cycles and LAN changes together never pile up', () async {
      final service = build(isReachable: (_) async => false);
      final changes = await changeFromAnotherTill();

      for (var i = 0; i < 5; i++) {
        await service.runSyncCycle();
      }
      await service.applyLanChanges(changes).timeout(const Duration(seconds: 2));

      expect(requests, 0);
      expect((await db.select(db.categories).get()).any((r) => r.id == 'from-till-2'), isTrue);
    });
  });
}
