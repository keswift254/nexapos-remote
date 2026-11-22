import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/core/utils/id_generator.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Category, Product;
import 'package:nexapos_mobile/data/local/database.dart' as local show Product;
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/data/repositories/category_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/product_repository_impl.dart';
import 'package:nexapos_mobile/data/sync/platform_sync_gateway.dart';
import 'package:nexapos_mobile/domain/entities/category.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/entities/product.dart';
import 'package:nexapos_mobile/domain/services/paystack_credentials_service.dart';
import 'package:nexapos_mobile/domain/services/stock_service.dart';
import 'package:nexapos_mobile/domain/services/sync_service.dart';
import 'package:nexapos_mobile/features/dashboard/dashboard_screen.dart';

/// A shop PC stopped uploading for 27 days: "A source revision was already recorded with different content", 4,590
/// changes waiting, the dashboard refreshing all the time. These are the causes and their cure:
///  - a product's stock count moved its updated_at without a new change number, so a product sent again (relayed over
///    the LAN first, or after a lost answer) no longer matched the server's copy;
///  - a device whose change counter went back (its data restored from an older copy) re-used numbers the server holds;
///  - such clashes were set aside, and 500 set-aside rows stopped every upload of the device;
///  - every sync bookkeeping write recomputed the whole dashboard, which showed a spinner instead of its figures.

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

const _configured = PaystackCredentials(
  baseUrl: 'http://localhost/nexapos_platform/public/index.php',
  apiKey: 'device_api_key_123',
  currency: 'KES',
  defaultEmail: 'customer@nexapos.co.ke',
);

/// The shop server's push_changes as it really behaves: every (device, revision) it records is kept; the same revision
/// sent again is fine when it matches (for products: apart from stockQty, imagePath and updatedAt), refused otherwise -
/// the whole batch, nothing recorded. [reportsMax]: a server from 2026-11-23 on, which says the highest revision it holds
/// for the device in its refusal.
class _Server {
  _Server({this.reportsMax = true, this.claimedDevice});
  final bool reportsMax;

  /// When set, the refusal names this device instead of the one that pushed (a server answer about another device).
  final String? claimedDevice;
  final revisions = <String, Map<String, dynamic>>{};
  var requests = 0;

  /// What the server holds now for [rowId] (the newest revision of it).
  Map<String, dynamic>? latestOf(String rowId) {
    Map<String, dynamic>? best;
    for (final change in revisions.values) {
      if (change['row_id'] != rowId) continue;
      if (best == null || (change['local_rev'] as int) > (best['local_rev'] as int)) best = change;
    }
    return best;
  }

  /// Revisions 1..[upTo] of [device] that hold other rows: what a device whose counter went back clashes with.
  void holdOldRevisions(String device, int upTo) {
    for (var rev = 1; rev <= upTo; rev++) {
      revisions['$device/$rev'] = {
        'table_name': 'categories',
        'row_id': 'old-row-$rev',
        'local_rev': rev,
        'updated_at': '2026-10-01T00:00:00.000000Z',
        'payload': {'id': 'old-row-$rev', 'name': 'From before the restore'},
      };
    }
  }

  static const _deviceLocal = {
    'products': {'stockQty', 'imagePath', 'updatedAt'},
  };

  bool _same(Map<String, dynamic> held, Map<String, dynamic> sent) {
    final local = _deviceLocal[sent['table_name']] ?? const <String>{};
    if (held['table_name'] != sent['table_name'] || held['row_id'] != sent['row_id']) return false;
    if (!local.contains('updatedAt') && held['updated_at'] != sent['updated_at']) return false;
    Map<String, dynamic> strip(Map<String, dynamic> payload) =>
        {for (final entry in payload.entries) if (!local.contains(entry.key)) entry.key: entry.value};
    return jsonEncode(strip(held['payload'] as Map<String, dynamic>)) == jsonEncode(strip(sent['payload'] as Map<String, dynamic>));
  }

  http.Client client(String device) => MockClient((request) async {
        final action = request.url.queryParameters['action'];
        if (action == 'pull_changes') {
          return http.Response(jsonEncode({'success': true, 'changes': [], 'next_cursor': 0, 'has_more': false}), 200);
        }
        if (action != 'push_changes') throw StateError('unexpected request: ${request.url}');
        requests++;
        final changes = (jsonDecode(request.body)['changes'] as List).cast<Map<String, dynamic>>();
        final fresh = <String, Map<String, dynamic>>{};
        for (final change in changes) {
          final key = '$device/${change['local_rev']}';
          final held = revisions[key] ?? fresh[key];
          if (held != null) {
            if (_same(held, change)) continue;
            final max = revisions.keys
                .where((k) => k.startsWith('$device/'))
                .map((k) => int.parse(k.substring(device.length + 1)))
                .fold<int>(0, (a, b) => a > b ? a : b);
            return http.Response(
              jsonEncode({
                'success': false,
                'message': 'Could not record changes: A source revision was already recorded with different content.',
                if (reportsMax) ...{
                  'reason': 'revision_clash',
                  'source_device_id': claimedDevice ?? device,
                  'local_rev': change['local_rev'],
                  'max_local_rev': max,
                },
              }),
              422,
            );
          }
          fresh[key] = change;
        }
        revisions.addAll(fresh);
        return http.Response(jsonEncode({'success': true, 'count': changes.length}), 200);
      });
}

void main() {
  late AppDatabase db;
  late SyncMetadataService meta;
  late String deviceId;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    meta = SyncMetadataService(db);
    deviceId = await meta.deviceId();
  });
  tearDown(() => db.close());

  SyncService serviceFor(_Server server) =>
      SyncService(db, meta, PlatformSyncGateway(server.client(deviceId)), _Credentials(_configured));

  Future<void> makeCategories(int count) async {
    final repository = CategoryRepositoryImpl(db, db.categoriesDao, meta, const SystemClock(), UuidIdGenerator());
    for (var i = 0; i < count; i++) {
      await repository.create(Category(id: '', name: 'Category $i', status: 'active'));
    }
  }

  /// Every row this device made, by id: its revision and time.
  Future<Map<String, ({int rev, String updatedAt})>> ownRows() async {
    final out = <String, ({int rev, String updatedAt})>{};
    for (final table in ['roles', 'business_settings', 'categories', 'products', 'stock_movements']) {
      final rows = await db
          .customSelect('SELECT id, local_rev, updated_at FROM "$table" WHERE created_by_device_id = ?',
              variables: [Variable<String>(deviceId)])
          .get();
      for (final row in rows) {
        out[row.read<String>('id')] = (rev: row.read<int>('local_rev'), updatedAt: row.read<String>('updated_at'));
      }
    }
    return out;
  }

  Future<int> highestLocalRev() async => await meta.nextLocalRev() - 1;

  group('a device whose change counter went back (its data restored from an older copy)', () {
    test('every unsent change is numbered above the highest the server holds and goes up in the same upload', () async {
      await makeCategories(30);
      final before = await ownRows();
      final server = _Server()..holdOldRevisions(deviceId, await highestLocalRev() + 50);
      final heldBefore = server.revisions.length;
      final service = serviceFor(server);

      await service.pushLocalChanges(_configured.baseUrl, _configured.apiKey);

      final after = await ownRows();
      expect(after.keys, before.keys);
      for (final id in before.keys) {
        expect(after[id]!.rev, greaterThan(heldBefore), reason: '$id is numbered above every revision the server held');
        expect(after[id]!.updatedAt, before[id]!.updatedAt, reason: '$id keeps its own time: only its number changed');
        expect(server.latestOf(id), isNotNull, reason: '$id reached the server');
      }
      expect(after.values.map((r) => r.rev).toSet(), hasLength(before.length), reason: 'no two rows share a number');
      final order = before.keys.toList()..sort((a, b) => before[a]!.rev.compareTo(before[b]!.rev));
      final newOrder = before.keys.toList()..sort((a, b) => after[a]!.rev.compareTo(after[b]!.rev));
      expect(newOrder, order, reason: 'the changes keep the order they were made in');
      expect(await service.quarantinedCount(), 0, reason: 'nothing set aside');
      expect((await service.health()).pendingChanges, 0, reason: 'nothing left to upload');
      expect(server.requests, lessThanOrEqualTo(3), reason: 'one refusal, then the renumbered changes: not a split per row');
      expect(await highestLocalRev(), greaterThanOrEqualTo(after.values.map((r) => r.rev).reduce((a, b) => a > b ? a : b)),
          reason: 'the counter is past every number given out, so new changes do not clash either');
    });

    test('650 clashing changes (more than the 500 that used to be set aside before every upload stopped) all go up', () async {
      await makeCategories(650);
      final server = _Server()..holdOldRevisions(deviceId, await highestLocalRev() + 10);
      final service = serviceFor(server);

      await service.pushLocalChanges(_configured.baseUrl, _configured.apiKey);

      expect((await service.health()).pendingChanges, 0);
      expect(await service.quarantinedCount(), 0);
      final categories = await db.select(db.categories).get();
      expect(categories, hasLength(650));
      for (final category in categories) {
        expect(server.latestOf(category.id), isNotNull, reason: '${category.name} reached the server');
      }
    });

    test('new sales made afterwards upload normally', () async {
      await makeCategories(5);
      final server = _Server()..holdOldRevisions(deviceId, await highestLocalRev() + 20);
      final service = serviceFor(server);
      await service.pushLocalChanges(_configured.baseUrl, _configured.apiKey);
      await makeCategories(3);
      final requests = server.requests;

      await service.pushLocalChanges(_configured.baseUrl, _configured.apiKey);

      expect(server.requests, requests + 1, reason: 'one batch, accepted at once');
      expect((await service.health()).pendingChanges, 0);
    });

    test('an older server that names no highest revision: rows take new numbers cycle after cycle until all are up', () async {
      await makeCategories(12);
      final before = await ownRows();
      final server = _Server(reportsMax: false)..holdOldRevisions(deviceId, await highestLocalRev() + 15);
      final service = serviceFor(server);

      for (var cycle = 0; cycle < 10 && (await service.health()).pendingChanges > 0; cycle++) {
        await service.pushLocalChanges(_configured.baseUrl, _configured.apiKey);
      }

      expect((await service.health()).pendingChanges, 0);
      expect(await service.quarantinedCount(), 0, reason: 'never set aside');
      final after = await ownRows();
      for (final id in before.keys) {
        expect(after[id]!.updatedAt, before[id]!.updatedAt);
        expect(server.latestOf(id), isNotNull);
      }
    });

    test('an answer about ANOTHER device is not taken as this one\'s highest revision', () async {
      await makeCategories(4);
      final server = _Server(claimedDevice: 'some-other-device')..holdOldRevisions(deviceId, await highestLocalRev() + 3);
      final service = serviceFor(server);

      for (var cycle = 0; cycle < 6 && (await service.health()).pendingChanges > 0; cycle++) {
        await service.pushLocalChanges(_configured.baseUrl, _configured.apiKey);
      }

      expect((await service.health()).pendingChanges, 0, reason: 'it falls back to one row at a time, and still gets there');
      expect(await service.quarantinedCount(), 0);
    });
  });

  group('a product\'s stock count is not an edit of the product', () {
    late ProductRepositoryImpl products;
    late StockService stock;
    late String productId;

    setUp(() async {
      final categories = CategoryRepositoryImpl(db, db.categoriesDao, meta, const SystemClock(), UuidIdGenerator());
      await categories.create(const Category(id: 'cat-1', name: 'General', status: 'active'));
      products = ProductRepositoryImpl(db, db.productsDao, meta, const SystemClock(), UuidIdGenerator());
      stock = StockService(db, db.productsDao, db.stockMovementsDao, meta, const SystemClock(), UuidIdGenerator());
      productId = await products.create(const Product(
        id: '',
        sku: 'SODA',
        name: 'Soda',
        categoryId: 'cat-1',
        retailPrice: Money(6000),
        wholesalePrice: Money(5000),
        costPrice: Money(4000),
        stockQty: 0,
        reorderLevel: 2,
        status: 'active',
      ));
    });

    Future<local.Product> productRow() async => (db.select(db.products)..where((p) => p.id.equals(productId))).getSingle();

    test('a sale (or any stock movement) changes the count only: same time, same change number', () async {
      await stock.applyMovement(productId: productId, movementType: 'purchase', delta: 10);
      final before = await productRow();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await stock.applyMovement(productId: productId, movementType: 'sale', delta: -3);

      final after = await productRow();
      expect(after.stockQty, before.stockQty - 3);
      expect(after.updatedAt, before.updatedAt, reason: 'a sale is not an edit of the product');
      expect(after.localRev, before.localRev);
    });

    test('a product sent again after a sale matches the server copy, so the upload goes on', () async {
      final server = _Server();
      final service = serviceFor(server);
      await service.pushLocalChanges(_configured.baseUrl, _configured.apiKey);
      // the answer was lost: the device still thinks the product is unsent, and sells some meanwhile
      await meta.setLastPushedLocalRev(0);
      await stock.applyMovement(productId: productId, movementType: 'purchase', delta: 5);

      await service.pushLocalChanges(_configured.baseUrl, _configured.apiKey);

      expect((await service.health()).pendingChanges, 0);
      expect(await service.quarantinedCount(), 0);
      expect((await productRow()).localRev, isNot(0));
    });

    test('the recount after changes from another device keeps the product\'s time too', () async {
      final otherDb = AppDatabase(NativeDatabase.memory());
      addTearDown(otherDb.close);
      final otherMeta = SyncMetadataService(otherDb);
      final other = SyncService(otherDb, otherMeta, PlatformSyncGateway(_Server().client('x')), _Credentials(_configured));
      final here = serviceFor(_Server());
      // the other till gets the product and its stock over the LAN
      await other.applyLanChanges(await here.exportLanChanges(await other.lanRevisionCursors()));
      await stock.applyMovement(productId: productId, movementType: 'purchase', delta: 7);
      final source = await productRow();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await other.applyLanChanges(await here.exportLanChanges(await other.lanRevisionCursors()));

      final there = await (otherDb.select(otherDb.products)..where((p) => p.id.equals(productId))).getSingle();
      expect(there.stockQty, 7, reason: 'the count is worked out from the movement');
      expect(there.updatedAt, source.updatedAt, reason: 'and the recount did not stamp the product as edited now');
    });
  });

  group('the updated_at safety net', () {
    Future<String> categoryTime(String id) async =>
        (await (db.select(db.categories)..where((c) => c.id.equals(id))).getSingle()).updatedAt;

    test('still stamps an edit that forgot updated_at, outside keepingUpdatedAt', () async {
      await makeCategories(1);
      final id = (await db.select(db.categories).getSingle()).id;
      final before = await categoryTime(id);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await db.customStatement('UPDATE categories SET name = ? WHERE id = ?', ['Renamed', id]);
      expect((await categoryTime(id)).compareTo(before), greaterThan(0));
    });

    test('is held off inside keepingUpdatedAt, and back on afterwards - even when the work fails', () async {
      await makeCategories(1);
      final id = (await db.select(db.categories).getSingle()).id;
      final before = await categoryTime(id);
      await db.keepingUpdatedAt(() => db.customStatement('UPDATE categories SET local_rev = local_rev + 1000 WHERE id = ?', [id]));
      expect(await categoryTime(id), before, reason: 'held off');
      await expectLater(
        db.keepingUpdatedAt<void>(() async => throw StateError('boom')),
        throwsStateError,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await db.customStatement('UPDATE categories SET name = ? WHERE id = ?', ['Again', id]);
      expect((await categoryTime(id)).compareTo(before), greaterThan(0), reason: 'back on after a failure');
    });

    test('a flag left behind by a write that never finished is cleared when the database opens', () async {
      final dir = await Directory.systemTemp.createTemp('nexapos-flag');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/shop.sqlite');
      final first = AppDatabase(NativeDatabase(file));
      await first.customSelect('SELECT 1').get();
      await first.customStatement("INSERT OR REPLACE INTO local_safety_state(id, value) VALUES('keep_updated_at', '1')");
      await first.close();

      final second = AppDatabase(NativeDatabase(file));
      addTearDown(second.close);
      final flag = await second
          .customSelect("SELECT COUNT(*) AS n FROM local_safety_state WHERE id = 'keep_updated_at'")
          .getSingle();
      expect(flag.read<int>('n'), 0);
    });
  });

  group('the dashboard', () {
    test('sync bookkeeping does not refresh it; a burst of shop changes refreshes it once', () async {
      final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);
      var ticks = 0;
      final listening = container.listen(dashboardChangeTickerProvider, (_, next) {
        if (next.hasValue) ticks++;
      });
      addTearDown(listening.close);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      for (var i = 0; i < 30; i++) {
        await meta.setLastPushedLocalRev(i); // what a refused, retried upload writes over and over
        await meta.nextLocalRev();
      }
      await Future<void>.delayed(dashboardRefreshGap + const Duration(milliseconds: 300));
      expect(ticks, 0, reason: 'nothing the dashboard shows changed');

      await makeCategories(25);
      await Future<void>.delayed(dashboardRefreshGap + const Duration(milliseconds: 300));
      expect(ticks, 1, reason: 'one refresh for the whole burst');
    });
  });
}
