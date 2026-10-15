import 'dart:convert';

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
import 'package:nexapos_mobile/domain/entities/category.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/services/paystack_credentials_service.dart';
import 'package:nexapos_mobile/domain/services/sync_service.dart';

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

const _futureDated =
    "Could not record changes: Change is dated more than a day in the future - check this device's date and time.";

void main() {
  late AppDatabase db;
  late SyncMetadataService syncMeta;
  const configured = PaystackCredentials(
    baseUrl: 'http://localhost/nexapos_platform/public/index.php',
    apiKey: 'device_api_key_123',
    currency: 'KES',
    defaultEmail: 'customer@nexapos.co.ke',
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    syncMeta = SyncMetadataService(db);
  });
  tearDown(() => db.close());

  Future<List<String>> makeCategories(int count) async {
    final repository = CategoryRepositoryImpl(db, db.categoriesDao, syncMeta, const SystemClock(), UuidIdGenerator());
    final ids = <String>[];
    for (var i = 0; i < count; i++) {
      await repository.create(Category(id: '', name: 'Category $i', status: 'active'));
    }
    for (final row in await db.select(db.categories).get()) {
      ids.add(row.id);
    }
    return ids;
  }

  /// A server that refuses any batch containing a row in [poison], all or
  /// nothing, like the real push_changes does.
  ({SyncService service, List<List<String>> requests, Set<String> accepted}) build(
    Set<String> poison, {
    int? status,
    String message = _futureDated,
    bool offline = false,
  }) {
    final requests = <List<String>>[];
    final accepted = <String>{};
    final client = MockClient((request) async {
      final action = request.url.queryParameters['action'];
      if (action == 'pull_changes') {
        return http.Response(jsonEncode({'success': true, 'changes': [], 'next_cursor': 0, 'has_more': false}), 200);
      }
      if (action != 'push_changes') throw StateError('unexpected request: ${request.url}');
      if (offline) throw http.ClientException('no route to host');
      final changes = (jsonDecode(request.body)['changes'] as List).cast<Map<String, dynamic>>();
      final ids = changes.map((c) => c['row_id'] as String).toList();
      requests.add(ids);
      if (status != null) {
        return http.Response(jsonEncode({'success': false, 'message': message}), status);
      }
      if (ids.any(poison.contains)) {
        return http.Response(jsonEncode({'success': false, 'message': message}), 422);
      }
      accepted.addAll(ids);
      return http.Response(jsonEncode({'success': true, 'count': ids.length}), 200);
    });
    final service = SyncService(db, syncMeta, PlatformSyncGateway(client), _Credentials(configured));
    return (service: service, requests: requests, accepted: accepted);
  }

  Future<int> highestRev() async => await syncMeta.nextLocalRev() - 1;

  test('one refused row no longer holds back everything after it', () async {
    final ids = await makeCategories(12);
    final bad = ids[5];
    final server = build({bad});

    await server.service.pushLocalChanges(configured.baseUrl, configured.apiKey);

    final everything = (await db.select(db.categories).get()).map((c) => c.id).toSet();
    expect(server.accepted.containsAll(everything.difference({bad})), isTrue, reason: 'every other category reached the server');
    expect(server.accepted.contains(bad), isFalse);
    expect(await server.service.quarantinedCount(), 1);
    final groups = await server.service.quarantineGroups();
    expect(groups.single.tableName, 'categories');
    expect(groups.single.reason, startsWith('Change is dated more than a day in the future'), reason: 'shown without the technical prefix');
    expect(await syncMeta.lastPushedLocalRev(), await highestRev(), reason: 'the cursor moves past the set-aside row');
  });

  test('a refused row at the very END is not re-sent forever either', () async {
    await makeCategories(6);
    final rows = await db.select(db.categories).get();
    final lastRow = (rows..sort((a, b) => a.localRev.compareTo(b.localRev))).last;
    final server = build({lastRow.id});

    await server.service.pushLocalChanges(configured.baseUrl, configured.apiKey);
    expect(await server.service.quarantinedCount(), 1);
    expect(await syncMeta.lastPushedLocalRev(), await highestRev(), reason: 'the cursor must pass the last row too');

    server.requests.clear();
    await server.service.pushLocalChanges(configured.baseUrl, configured.apiKey);
    expect(server.requests, isEmpty, reason: 'nothing is left to send, so nothing is sent');
  });

  test('after that the same row is not sent again and nothing is pending', () async {
    final ids = await makeCategories(8);
    final server = build({ids[2]});
    await server.service.pushLocalChanges(configured.baseUrl, configured.apiKey);
    server.requests.clear();

    await server.service.pushLocalChanges(configured.baseUrl, configured.apiKey);

    expect(server.requests, isEmpty, reason: 'a second cycle has nothing to send');
    expect((await server.service.health()).pendingChanges, 0);
  });

  test('refused rows at the start, middle and end of a batch are all found', () async {
    final ids = await makeCategories(40);
    final bad = {ids.first, ids[20], ids.last};
    final server = build(bad);

    await server.service.pushLocalChanges(configured.baseUrl, configured.apiKey);

    expect(await server.service.quarantinedCount(), 3);
    expect(server.accepted.intersection(bad), isEmpty);
    final everything = (await db.select(db.categories).get()).map((c) => c.id).toSet();
    expect(server.accepted.containsAll(everything.difference(bad)), isTrue);
  });

  test('a clean batch costs exactly one request', () async {
    await makeCategories(30);
    final server = build({});
    await server.service.pushLocalChanges(configured.baseUrl, configured.apiKey);
    expect(server.requests.length, 1);
    expect(await server.service.quarantinedCount(), 0);
  });

  test('finding one bad row among 200 takes about two requests per halving, not 200', () async {
    await makeCategories(200);
    final ids = (await db.select(db.categories).get()).map((c) => c.id).toList();
    final server = build({ids[137]});
    await server.service.pushLocalChanges(configured.baseUrl, configured.apiKey);
    expect(server.requests.length, lessThan(30));
    expect(await server.service.quarantinedCount(), 1);
  });

  group('refusals that are NOT about a row are retried, never set aside', () {
    test("the server's generic 'Could not record changes.' (a database hiccup also says this)", () async {
      final ids = await makeCategories(6);
      final server = build({ids[1]}, message: 'Could not record changes.');
      final before = await syncMeta.lastPushedLocalRev();
      await expectLater(
        server.service.pushLocalChanges(configured.baseUrl, configured.apiKey),
        throwsA(isA<PaystackException>()),
      );
      expect(await server.service.quarantinedCount(), 0);
      expect(await syncMeta.lastPushedLocalRev(), before, reason: 'nothing was acknowledged, so the cursor stays');
    });

    test('a server error (500)', () async {
      await makeCategories(6);
      final server = build({}, status: 500, message: 'Internal error');
      await expectLater(server.service.pushLocalChanges(configured.baseUrl, configured.apiKey), throwsA(isA<PaystackException>()));
      expect(await server.service.quarantinedCount(), 0);
    });

    test('a rejected key (401)', () async {
      await makeCategories(6);
      final server = build({}, status: 401, message: 'Invalid or missing API key.');
      await expectLater(server.service.pushLocalChanges(configured.baseUrl, configured.apiKey), throwsA(isA<PaystackException>()));
      expect(await server.service.quarantinedCount(), 0);
    });

    test('no connection', () async {
      await makeCategories(6);
      final server = build({}, offline: true);
      await expectLater(
        server.service.pushLocalChanges(configured.baseUrl, configured.apiKey),
        throwsA(isA<PaystackOfflineException>()),
      );
      expect(await server.service.quarantinedCount(), 0);
    });
  });

  test('a server refusing EVERYTHING cannot make the app set a whole shop aside', () async {
    await makeCategories(80);
    final ids = (await db.select(db.categories).get()).map((c) => c.id).toSet();
    final server = build(ids);
    final before = await syncMeta.lastPushedLocalRev();

    await expectLater(
      server.service.pushLocalChanges(configured.baseUrl, configured.apiKey),
      throwsA(isA<PaystackException>()),
      reason: 'it gives up and reports the problem instead',
    );

    expect(await server.service.quarantinedCount(), lessThanOrEqualTo(25), reason: 'per-cycle limit');
    expect(await syncMeta.lastPushedLocalRev(), greaterThanOrEqualTo(before));
    final pendingAfter = (await server.service.health()).pendingChanges;
    expect(pendingAfter, greaterThan(0), reason: 'the rest stays queued for a later cycle');
  });

  test('set-aside rows are cleared by a fresh start', () async {
    final ids = await makeCategories(5);
    final server = build({ids[1]});
    await server.service.pushLocalChanges(configured.baseUrl, configured.apiKey);
    expect(await server.service.quarantinedCount(), 1);
    await db.resetForFreshStart();
    expect(await server.service.quarantinedCount(), 0);
  });

  group('health()', () {
    test('counts rows waiting to upload, then none after a successful upload', () async {
      await makeCategories(7);
      final server = build({});
      final before = await server.service.health();
      expect(before.pendingChanges, greaterThanOrEqualTo(7));
      expect(before.quarantined, 0);

      await server.service.pushLocalChanges(configured.baseUrl, configured.apiKey);
      expect((await server.service.health()).pendingChanges, 0);
    });

    test('a full sync cycle records when it last worked, and it survives a restart', () async {
      await makeCategories(2);
      final server = build({});
      expect((await server.service.health()).lastSuccess, isNull);

      await server.service.runSyncCycle();

      final recorded = (await server.service.health()).lastSuccess;
      expect(recorded, isNotNull);
      expect(DateTime.now().difference(recorded!).inMinutes.abs(), lessThan(2));
      // A brand-new service (the app restarted) still knows it.
      final restarted = build({});
      final stored = (await restarted.service.health()).lastSuccess;
      expect(stored, isNotNull, reason: 'read back from the database, not from memory');
    });

    test('the first look fixes a baseline so "no upload for a day" can be measured on a new device', () async {
      final server = build({});
      final first = await server.service.health();
      final second = await server.service.health();
      expect(second.baseline, first.baseline);
    });

    test('rows that were set aside are reported', () async {
      final ids = await makeCategories(4);
      final server = build({ids[0]});
      await server.service.pushLocalChanges(configured.baseUrl, configured.apiKey);
      expect((await server.service.health()).quarantined, 1);
    });
  });
}
