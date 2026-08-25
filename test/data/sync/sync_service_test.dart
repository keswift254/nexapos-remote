import 'dart:convert';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/core/utils/id_generator.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Category;
import 'package:nexapos_mobile/data/local/database.dart' as drift_db show Category;
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/data/repositories/business_settings_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/category_repository_impl.dart';
import 'package:nexapos_mobile/data/sync/platform_sync_gateway.dart';
import 'package:nexapos_mobile/domain/entities/category.dart';
import 'package:nexapos_mobile/domain/services/paystack_credentials_service.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/services/sync_service.dart';

class _FakeCredentialsService implements PaystackCredentialsService {
  PaystackCredentials credentials;
  String deviceLabel = '';
  _FakeCredentialsService(this.credentials);

  @override
  Future<PaystackCredentials> load() async => credentials;

  @override
  Future<void> save(PaystackCredentials value) async => credentials = value;

  @override
  Future<String> loadDeviceLabel() async => deviceLabel;

  @override
  Future<void> saveDeviceLabel(String label) async => deviceLabel = label;

  @override
  Future<void> clearRegistration() async => credentials = credentials.copyWith(baseUrl: '', apiKey: '');
}

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

  tearDown(() async {
    await db.close();
  });

  SyncService buildService(http.Client client) {
    return SyncService(db, syncMeta, PlatformSyncGateway(client), _FakeCredentialsService(configured));
  }

  group('pushLocalChanges', () {
    test('does nothing when not configured, without touching the network', () async {
      var called = false;
      final service = SyncService(
        db,
        syncMeta,
        PlatformSyncGateway(MockClient((request) async {
          called = true;
          throw StateError('should never be called');
        })),
        _FakeCredentialsService(const PaystackCredentials(baseUrl: '', apiKey: '', currency: 'KES', defaultEmail: 'x@y.com')),
      );

      await service.runSyncCycle();

      expect(called, isFalse);
    });

    test('sends pending rows across tables in ascending local_rev order, not table-iteration order', () async {
      final categoryRepository =
          CategoryRepositoryImpl(db, db.categoriesDao, syncMeta, const SystemClock(), UuidIdGenerator());
      final settingsRepository = BusinessSettingsRepositoryImpl(db, db.businessSettingsDao, syncMeta, const SystemClock());

      // business_settings is seeded once at onCreate (an earlier rev
      // than anything created here) - update it again so it gets a
      // fresh, later rev than the category about to be created next.
      final settings = await settingsRepository.get();
      await settingsRepository.update(settings.copyWith(businessName: 'Updated Name'));
      await categoryRepository.create(const Category(id: '', name: 'Drinks', status: 'active'));

      // 'categories' iterates before 'business_settings' in
      // syncTableAdapters (insertion order), but business_settings was
      // updated FIRST here, so it has the lower local_rev - a naive
      // per-table loop would emit categories first regardless, which is
      // exactly the bug this test guards against.
      List<Map<String, dynamic>>? pushedBatch;
      final service = buildService(MockClient((request) async {
        if (request.url.queryParameters['action'] == 'push_changes') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          pushedBatch = (body['changes'] as List).cast<Map<String, dynamic>>();
          return http.Response(jsonEncode({'success': true, 'count': pushedBatch!.length}), 200);
        }
        throw StateError('unexpected request: ${request.url}');
      }));

      await service.pushLocalChanges(configured.baseUrl, configured.apiKey);

      expect(pushedBatch, isNotNull);
      final revs = pushedBatch!.map((c) => c['local_rev'] as int).toList();
      expect(revs, equals([...revs]..sort()), reason: 'push batch must be in ascending local_rev order');
      final tableOrder = pushedBatch!.map((c) => c['table_name']).toList();
      expect(tableOrder.indexOf('business_settings'), lessThan(tableOrder.indexOf('categories')),
          reason: 'business_settings has the lower local_rev here and must be sent first despite iterating later');
    });

    test('advances the push cursor to the highest rev actually sent', () async {
      final categoryRepository =
          CategoryRepositoryImpl(db, db.categoriesDao, syncMeta, const SystemClock(), UuidIdGenerator());
      await categoryRepository.create(const Category(id: '', name: 'Drinks', status: 'active'));
      final expectedRev = await syncMeta.nextLocalRev() - 1;

      final service = buildService(MockClient((request) async {
        return http.Response(jsonEncode({'success': true, 'count': 1}), 200);
      }));
      await service.pushLocalChanges(configured.baseUrl, configured.apiKey);

      expect(await syncMeta.lastPushedLocalRev(), expectedRev);
    });
  });

  group('pullRemoteChanges - last-write-wins', () {
    Future<drift_db.Category> seedLocalCategory() async {
      final repo = CategoryRepositoryImpl(db, db.categoriesDao, syncMeta, const SystemClock(), UuidIdGenerator());
      final id = UuidIdGenerator().newId();
      await repo.create(Category(id: id, name: 'Original', status: 'active'));
      final query = db.select(db.categories)..where((t) => t.id.equals(id));
      return query.getSingle();
    }

    PullResult onePage(Map<String, dynamic> payload, {int id = 1}) {
      return PullResult(
        changes: [PulledChange(id: id, tableName: 'categories', rowId: payload['id'] as String, payload: payload)],
        nextCursor: id,
        hasMore: false,
      );
    }

    test('an incoming row with a newer updated_at overwrites the local one', () async {
      final local = await seedLocalCategory();
      final incoming = local.toJson()
        ..['name'] = 'Renamed Remotely'
        ..['updatedAt'] = '2999-01-01T00:00:00.000000Z'
        ..['localRev'] = 999
        ..['createdByDeviceId'] = 'other-device';

      var pullCalls = 0;
      final service = buildService(MockClient((request) async {
        if (request.url.queryParameters['action'] == 'pull_changes') {
          pullCalls++;
          final result = pullCalls == 1
              ? onePage(incoming)
              : const PullResult(changes: [], nextCursor: 0, hasMore: false);
          return http.Response(
            jsonEncode({
              'success': true,
              'changes': result.changes
                  .map((c) => {'id': c.id, 'table_name': c.tableName, 'row_id': c.rowId, 'payload': c.payload})
                  .toList(),
              'next_cursor': result.nextCursor,
              'has_more': result.hasMore,
            }),
            200,
          );
        }
        throw StateError('unexpected request: ${request.url}');
      }));

      await service.pullRemoteChanges(configured.baseUrl, configured.apiKey);

      final after = await (db.select(db.categories)..where((t) => t.id.equals(local.id))).getSingle();
      expect(after.name, 'Renamed Remotely');
    });

    test('an incoming row with an older updated_at is ignored', () async {
      final local = await seedLocalCategory();
      final incoming = local.toJson()
        ..['name'] = 'Should Not Apply'
        ..['updatedAt'] = '2000-01-01T00:00:00.000000Z'
        ..['createdByDeviceId'] = 'other-device';

      final service = buildService(MockClient((request) async {
        if (request.url.queryParameters['action'] == 'pull_changes') {
          return http.Response(
            jsonEncode({
              'success': true,
              'changes': [
                {'id': 1, 'table_name': 'categories', 'row_id': incoming['id'], 'payload': incoming},
              ],
              'next_cursor': 1,
              'has_more': false,
            }),
            200,
          );
        }
        throw StateError('unexpected request: ${request.url}');
      }));

      await service.pullRemoteChanges(configured.baseUrl, configured.apiKey);

      final after = await (db.select(db.categories)..where((t) => t.id.equals(local.id))).getSingle();
      expect(after.name, 'Original');
    });

    test('an exact updated_at tie is broken deterministically by device_id', () async {
      final local = await seedLocalCategory();
      // Local row's own createdByDeviceId is whatever this test db's
      // seeded device is - pick an incoming id guaranteed to sort after
      // it lexicographically ('zzz...' beats any UUID).
      final incoming = local.toJson()
        ..['name'] = 'Tie Winner'
        ..['createdByDeviceId'] = 'zzzzzzzz-tie-break-wins';
      // updatedAt left exactly as the local row's own value - a genuine tie.

      final service = buildService(MockClient((request) async {
        if (request.url.queryParameters['action'] == 'pull_changes') {
          return http.Response(
            jsonEncode({
              'success': true,
              'changes': [
                {'id': 1, 'table_name': 'categories', 'row_id': incoming['id'], 'payload': incoming},
              ],
              'next_cursor': 1,
              'has_more': false,
            }),
            200,
          );
        }
        throw StateError('unexpected request: ${request.url}');
      }));

      await service.pullRemoteChanges(configured.baseUrl, configured.apiKey);

      final after = await (db.select(db.categories)..where((t) => t.id.equals(local.id))).getSingle();
      expect(after.name, 'Tie Winner', reason: 'the lexicographically-greater device_id must win an exact tie');
    });
  });

  group('pullRemoteChanges - append-only tables', () {
    test('an incoming stock_movements row for an id that already exists locally is ignored, not overwritten', () async {
      // stock_movements has no update path anywhere (StockMovementsDao
      // exposes insert() only) - insert-or-ignore only. Uses
      // stock_movements rather than sale_items for this test purely
      // because it needs a shallower FK chain to set up (a product, not
      // a product AND a user-owned sale) - the behavior under test
      // (second insert with the same id never changes the first) is
      // identical for both append-only tables.
      final categoryRepository =
          CategoryRepositoryImpl(db, db.categoriesDao, syncMeta, const SystemClock(), UuidIdGenerator());
      final categoryId = UuidIdGenerator().newId();
      await categoryRepository.create(Category(id: categoryId, name: 'General', status: 'active'));
      final deviceId = await syncMeta.deviceId();
      final now = DateTime.now().toUtc().toIso8601String();

      const productId = 'fixed-product-id-2';
      await db.into(db.products).insert(ProductsCompanion.insert(
            id: productId,
            sku: 'SKU-2',
            name: 'Widget',
            categoryId: categoryId,
            retailPriceCents: 1000,
            wholesalePriceCents: 800,
            costPriceCents: 500,
            createdAt: now,
            updatedAt: now,
            localRev: await syncMeta.nextLocalRev(),
            createdByDeviceId: deviceId,
          ));

      const rowId = 'fixed-movement-id';
      await db.into(db.stockMovements).insert(StockMovementsCompanion.insert(
            id: rowId,
            productId: productId,
            movementType: 'purchase',
            quantity: 5,
            createdAt: now,
            updatedAt: now,
            localRev: await syncMeta.nextLocalRev(),
            createdByDeviceId: deviceId,
          ));

      final incoming =
          (await (db.select(db.stockMovements)..where((t) => t.id.equals(rowId))).getSingle()).toJson()
            ..['quantity'] = 999;

      final service = buildService(MockClient((request) async {
        if (request.url.queryParameters['action'] == 'pull_changes') {
          return http.Response(
            jsonEncode({
              'success': true,
              'changes': [
                {'id': 1, 'table_name': 'stock_movements', 'row_id': rowId, 'payload': incoming},
              ],
              'next_cursor': 1,
              'has_more': false,
            }),
            200,
          );
        }
        throw StateError('unexpected request: ${request.url}');
      }));

      await service.pullRemoteChanges(configured.baseUrl, configured.apiKey);

      final after = await (db.select(db.stockMovements)..where((t) => t.id.equals(rowId))).getSingle();
      expect(after.quantity, 5);
    });
  });

  group('pullRemoteChanges - stock_qty recompute', () {
    test('recomputes stock_qty as the sum of all local stock_movements after applying a pulled movement', () async {
      final categoryRepository =
          CategoryRepositoryImpl(db, db.categoriesDao, syncMeta, const SystemClock(), UuidIdGenerator());
      final categoryId = UuidIdGenerator().newId();
      await categoryRepository.create(Category(id: categoryId, name: 'General', status: 'active'));
      final deviceId = await syncMeta.deviceId();
      final now = DateTime.now().toUtc().toIso8601String();

      const productId = 'fixed-product-id';
      await db.into(db.products).insert(ProductsCompanion.insert(
            id: productId,
            sku: 'SKU-1',
            name: 'Widget',
            categoryId: categoryId,
            retailPriceCents: 1000,
            wholesalePriceCents: 800,
            costPriceCents: 500,
            stockQty: const Value(7),
            createdAt: now,
            updatedAt: now,
            localRev: await syncMeta.nextLocalRev(),
            createdByDeviceId: deviceId,
          ));
      // A pre-existing local movement, not itself part of this pull -
      // the recompute must still account for it.
      await db.into(db.stockMovements).insert(StockMovementsCompanion.insert(
            id: 'existing-movement',
            productId: productId,
            movementType: 'purchase',
            quantity: 7,
            createdAt: now,
            updatedAt: now,
            localRev: await syncMeta.nextLocalRev(),
            createdByDeviceId: deviceId,
          ));

      final incomingMovement = {
        'id': 'pulled-movement',
        'createdAt': now,
        'updatedAt': now,
        'deletedAt': null,
        'localRev': 500,
        'createdByDeviceId': 'other-device',
        'syncState': 'local_only',
        'productId': productId,
        'userId': null,
        'movementType': 'sale',
        'quantity': -3,
        'note': null,
      };

      final service = buildService(MockClient((request) async {
        if (request.url.queryParameters['action'] == 'pull_changes') {
          return http.Response(
            jsonEncode({
              'success': true,
              'changes': [
                {'id': 1, 'table_name': 'stock_movements', 'row_id': 'pulled-movement', 'payload': incomingMovement},
              ],
              'next_cursor': 1,
              'has_more': false,
            }),
            200,
          );
        }
        throw StateError('unexpected request: ${request.url}');
      }));

      await service.pullRemoteChanges(configured.baseUrl, configured.apiKey);

      final product = await (db.select(db.products)..where((t) => t.id.equals(productId))).getSingle();
      expect(product.stockQty, 4, reason: '7 (existing) + (-3) (pulled) = 4, a full re-sum not an incremental delta');
      expect(product.localRev, lessThan(500), reason: 'the stock_qty recompute must never bump the product\'s own local_rev');
    });
  });
}
