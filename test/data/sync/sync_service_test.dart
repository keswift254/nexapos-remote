import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/core/utils/id_generator.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Category;
import 'package:nexapos_mobile/data/local/database.dart'
    as drift_db
    show Category;
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
  Future<void> clearRegistration() async =>
      credentials = credentials.copyWith(baseUrl: '', apiKey: '');
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
    return SyncService(
      db,
      syncMeta,
      PlatformSyncGateway(client),
      _FakeCredentialsService(configured),
    );
  }

  group('initial snapshot', () {
    Future<List<Map<String, dynamic>>> records() async {
      final role = (await db.select(db.roles).get()).first;
      final settings = (await db.select(db.businessSettings).get()).first
          .toJson();
      const stamp = '2099-09-15T10:00:00.000000Z';
      Map<String, dynamic> common(String id) => {
        'id': id,
        'createdAt': stamp,
        'updatedAt': stamp,
        'deletedAt': null,
        'createdByDeviceId': 'owner-device',
        'localRev': 100,
        'syncState': 'local_only',
      };
      Map<String, dynamic> row(
        int id,
        String table,
        Map<String, dynamic> payload,
      ) => {
        'id': id,
        'table_name': table,
        'row_id': payload['id'],
        'payload': payload,
      };
      return [
        row(1, 'products', {
          ...common('remote-product'),
          'sku': 'SNAP',
          'name': 'Snapshot product',
          'categoryId': 'remote-category',
          'imagePath': null,
          'retailPriceCents': 100,
          'wholesalePriceCents': 90,
          'costPriceCents': 50,
          'stockQty': 999,
          'reorderLevel': 0,
          'status': 'active',
        }),
        row(2, 'stock_movements', {
          ...common('remote-movement'),
          'productId': 'remote-product',
          'userId': null,
          'movementType': 'purchase',
          'quantity': 7,
          'note': null,
        }),
        row(3, 'categories', {
          ...common('remote-category'),
          'name': 'Parent arrives later',
          'status': 'active',
        }),
        row(4, 'users', {
          ...common('remote-user'),
          'roleId': role.id,
          'name': 'Snapshot User',
          'username': 'snapshot-user',
          'email': null,
          'phone': null,
          'passwordHash': 'test-hash',
          'status': 'active',
        }),
        row(5, 'business_settings', {
          ...settings,
          'updatedAt': stamp,
          'createdByDeviceId': 'owner-device',
        }),
      ];
    }

    test('resumes staged pages and atomically applies out-of-order parents and stock', () async {
      final data = await records();
      await buildService(MockClient((_) async => throw StateError('unused')))
          .prepareJoinedShop();
      var failSecond = true;
      var starts = 0;
      final cursors = <String>[];
      final service = buildService(
        MockClient((request) async {
          final action = request.url.queryParameters['action'];
          const meta = {
            'success': true,
            'snapshot_id': 'snapshot-test',
            'high_water': 1000,
            'total': 5,
          };
          if (action == 'start_sync_snapshot') {
            starts++;
            return http.Response(jsonEncode(meta), 200);
          }
          if (action == 'discard_sync_snapshot')
            return http.Response('{"success":true}', 200);
          final after = request.url.queryParameters['after']!;
          cursors.add(after);
          if (after == '2' && failSecond) throw http.ClientException('offline');
          return http.Response(
            jsonEncode({
              ...meta,
              'changes': after == '0'
                  ? data.take(2).toList()
                  : data.skip(2).toList(),
              'next_cursor': after == '0' ? 2 : 5,
              'has_more': after == '0',
            }),
            200,
          );
        }),
      );
      await expectLater(
        service.pullInitialSnapshot(configured.baseUrl, configured.apiKey),
        throwsA(isA<PaystackOfflineException>()),
      );
      expect(await db.select(db.products).get(), isEmpty);
      expect(await syncMeta.lastPulledChangeId(), 0);
      expect(await service.needsInitialPull, isTrue);
      failSecond = false;
      final seenWhileApplying = <int>[];
      service.progress.addListener(() {
        if (service.progress.value.message == 'Applying shop records') {
          seenWhileApplying.add(service.progress.value.completed);
        }
      });
      await service.pullInitialSnapshot(configured.baseUrl, configured.apiKey);
      expect(starts, 1);
      expect(cursors, ['0', '2', '2']);
      expect((await db.select(db.products).getSingle()).stockQty, 7);
      expect((await db.select(db.users).getSingle()).username, 'snapshot-user');
      expect(await syncMeta.lastPulledChangeId(), 1000);
      expect(await service.needsInitialPull, isFalse);
      // The switch from "downloading" to "applying" must read as a
      // continuation, not as having lost the download that just finished -
      // every notification from here has to already show all 5 records,
      // never a bare 0 for a shop it already knows the full size of.
      expect(seenWhileApplying, isNotEmpty);
      expect(seenWhileApplying, everyElement(5));
    });

    test('stuck retrying a stalled join (many retries, still fails): the download screen never flashes back to zero', () async {
      // This is what device_sync_screen.dart's join-progress view actually
      // watches (service.progress), driven through the SAME retry loop
      // app.dart's _scheduleNextSync uses every hydratingSyncRetryInterval
      // (runSyncCycle, not pullInitialSnapshot directly) - matches a real
      // report of a join stuck retrying for a long time on a bad
      // connection. A bug here previously reset the screen to "Checking
      // shop membership" / 0 records for a moment at the START of every
      // one of those retries, even mid-download, before jumping back up to
      // the real, already-persisted count a beat later - every retry, not
      // just once.
      final data = await records();
      await buildService(MockClient((_) async => throw StateError('unused')))
          .prepareJoinedShop();
      var alwaysFailAfterFirstPage = true;
      final service = buildService(
        MockClient((request) async {
          final action = request.url.queryParameters['action'];
          const meta = {
            'success': true,
            'snapshot_id': 'snapshot-test',
            'high_water': 1000,
            'total': 5,
          };
          if (action == 'start_sync_snapshot')
            return http.Response(jsonEncode(meta), 200);
          final after = request.url.queryParameters['after']!;
          if (after == '2' && alwaysFailAfterFirstPage)
            throw http.ClientException('offline');
          return http.Response(
            jsonEncode({
              ...meta,
              'changes': after == '0'
                  ? data.take(2).toList()
                  : data.skip(2).toList(),
              'next_cursor': after == '0' ? 2 : 5,
              'has_more': after == '0',
            }),
            200,
          );
        }),
      );
      final seen = <int>[];
      service.progress.addListener(
        () => seen.add(service.progress.value.completed),
      );

      // The first cycle has nothing persisted yet to preserve, so it alone
      // legitimately starts at 0 - only what happens from the SECOND retry
      // onward (resuming an already-partial download) is under test here.
      await service.runSyncCycle();
      expect(
        service.progress.value.completed,
        2,
        reason: 'the first 2 records made it in before the stall',
      );
      seen.clear();

      for (var retry = 0; retry < 4; retry++) {
        await service.runSyncCycle();
      }

      expect(seen, isNotEmpty);
      expect(
        seen.every((completed) => completed >= 2),
        isTrue,
        reason:
            'must never dip back below the 2 records this device already has, across 4 retries - saw $seen',
      );
      expect(
        await service.needsInitialPull,
        isTrue,
        reason: 'the join is still genuinely stuck in this test',
      );

      alwaysFailAfterFirstPage = false;
      await service.runSyncCycle();
      expect(service.progress.value.completed, 5);
      expect(await service.needsInitialPull, isFalse);
    });

    test(
      'a missing parent rolls back every applied record and the cursor',
      () async {
        final data = await records();
        data.removeAt(2);
        final service = buildService(
          MockClient((request) async {
            const meta = {
              'success': true,
              'snapshot_id': 'bad-fk',
              'high_water': 100,
              'total': 4,
            };
            return http.Response(
              jsonEncode({
                ...meta,
                if (request.url.queryParameters['action'] ==
                    'pull_sync_snapshot') ...{
                  'changes': data,
                  'next_cursor': 5,
                  'has_more': false,
                },
              }),
              200,
            );
          }),
        );
        await service.prepareJoinedShop();
        await expectLater(
          service.pullInitialSnapshot(configured.baseUrl, configured.apiKey),
          throwsA(anything),
        );
        expect(await db.select(db.products).get(), isEmpty);
        expect(await db.select(db.users).get(), isEmpty);
        expect(await syncMeta.lastPulledChangeId(), 0);
        expect(await service.needsInitialPull, isTrue);
      },
    );

    test('cannot snapshot an already-operating device', () async {
      var requested = false;
      final service = buildService(
        MockClient((_) async {
          requested = true;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        service.pullInitialSnapshot(configured.baseUrl, configured.apiKey),
        throwsStateError,
      );
      expect(requested, isFalse);
    });
  });

  group('pushLocalChanges', () {
    test(
      'does nothing when not configured, without touching the network',
      () async {
        var called = false;
        final service = SyncService(
          db,
          syncMeta,
          PlatformSyncGateway(
            MockClient((request) async {
              called = true;
              throw StateError('should never be called');
            }),
          ),
          _FakeCredentialsService(
            const PaystackCredentials(
              baseUrl: '',
              apiKey: '',
              currency: 'KES',
              defaultEmail: 'x@y.com',
            ),
          ),
        );

        await service.runSyncCycle();

        expect(called, isFalse);
      },
    );

    test('sends pending rows across tables in ascending local_rev order, not table-iteration order', () async {
      final categoryRepository = CategoryRepositoryImpl(
        db,
        db.categoriesDao,
        syncMeta,
        const SystemClock(),
        UuidIdGenerator(),
      );
      final settingsRepository = BusinessSettingsRepositoryImpl(
        db,
        db.businessSettingsDao,
        syncMeta,
        const SystemClock(),
      );

      // business_settings is seeded once at onCreate (an earlier rev
      // than anything created here) - update it again so it gets a
      // fresh, later rev than the category about to be created next.
      final settings = await settingsRepository.get();
      await settingsRepository.update(
        settings.copyWith(businessName: 'Updated Name'),
      );
      await categoryRepository.create(
        const Category(id: '', name: 'Drinks', status: 'active'),
      );

      // 'categories' iterates before 'business_settings' in
      // syncTableAdapters (insertion order), but business_settings was
      // updated FIRST here, so it has the lower local_rev - a naive
      // per-table loop would emit categories first regardless, which is
      // exactly the bug this test guards against.
      List<Map<String, dynamic>>? pushedBatch;
      final service = buildService(
        MockClient((request) async {
          if (request.url.queryParameters['action'] == 'push_changes') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            pushedBatch = (body['changes'] as List)
                .cast<Map<String, dynamic>>();
            return http.Response(
              jsonEncode({'success': true, 'count': pushedBatch!.length}),
              200,
            );
          }
          throw StateError('unexpected request: ${request.url}');
        }),
      );

      await service.pushLocalChanges(configured.baseUrl, configured.apiKey);

      expect(pushedBatch, isNotNull);
      final revs = pushedBatch!.map((c) => c['local_rev'] as int).toList();
      expect(
        revs,
        equals([...revs]..sort()),
        reason: 'push batch must be in ascending local_rev order',
      );
      final tableOrder = pushedBatch!.map((c) => c['table_name']).toList();
      expect(
        tableOrder.indexOf('business_settings'),
        lessThan(tableOrder.indexOf('categories')),
        reason: 'business_settings has the lower local_rev here and must be sent first despite iterating later',
      );
    });

    test('advances the push cursor to the highest rev actually sent', () async {
      final categoryRepository = CategoryRepositoryImpl(
        db,
        db.categoriesDao,
        syncMeta,
        const SystemClock(),
        UuidIdGenerator(),
      );
      await categoryRepository.create(
        const Category(id: '', name: 'Drinks', status: 'active'),
      );
      final expectedRev = await syncMeta.nextLocalRev() - 1;

      final service = buildService(
        MockClient((request) async {
          return http.Response(jsonEncode({'success': true, 'count': 1}), 200);
        }),
      );
      await service.pushLocalChanges(configured.baseUrl, configured.apiKey);

      expect(await syncMeta.lastPushedLocalRev(), expectedRev);
    });

    test('splits large pushes into bounded batches and advances after each acknowledgement', () async {
      final categoryRepository = CategoryRepositoryImpl(
        db,
        db.categoriesDao,
        syncMeta,
        const SystemClock(),
        UuidIdGenerator(),
      );
      for (var i = 0; i < 205; i++) {
        await categoryRepository.create(
          Category(id: '', name: 'Category $i', status: 'active'),
        );
      }
      final expectedRev = await syncMeta.nextLocalRev() - 1;
      final batchSizes = <int>[];

      final service = buildService(
        MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final changes = body['changes'] as List;
          batchSizes.add(changes.length);
          return http.Response(
            jsonEncode({'success': true, 'count': changes.length}),
            200,
          );
        }),
      );

      await service.pushLocalChanges(configured.baseUrl, configured.apiKey);

      expect(batchSizes.length, greaterThan(1));
      expect(batchSizes.every((size) => size <= 200), isTrue);
      expect(batchSizes.reduce((a, b) => a + b), greaterThanOrEqualTo(205));
      expect(await syncMeta.lastPushedLocalRev(), expectedRev);
    });
  });

  group('pullRemoteChanges - last-write-wins', () {
    Future<drift_db.Category> seedLocalCategory() async {
      final repo = CategoryRepositoryImpl(
        db,
        db.categoriesDao,
        syncMeta,
        const SystemClock(),
        UuidIdGenerator(),
      );
      final id = UuidIdGenerator().newId();
      await repo.create(Category(id: id, name: 'Original', status: 'active'));
      final query = db.select(db.categories)..where((t) => t.id.equals(id));
      return query.getSingle();
    }

    PullResult onePage(Map<String, dynamic> payload, {int id = 1}) {
      return PullResult(
        changes: [
          PulledChange(
            id: id,
            tableName: 'categories',
            rowId: payload['id'] as String,
            payload: payload,
          ),
        ],
        nextCursor: id,
        hasMore: false,
      );
    }

    test(
      'an incoming row with a newer updated_at overwrites the local one',
      () async {
        final local = await seedLocalCategory();
        final incoming = local.toJson()
          ..['name'] = 'Renamed Remotely'
          ..['updatedAt'] = '2999-01-01T00:00:00.000000Z'
          ..['localRev'] = 999
          ..['createdByDeviceId'] = 'other-device';

        var pullCalls = 0;
        final service = buildService(
          MockClient((request) async {
            if (request.url.queryParameters['action'] == 'pull_changes') {
              pullCalls++;
              final result = pullCalls == 1
                  ? onePage(incoming)
                  : const PullResult(
                      changes: [],
                      nextCursor: 0,
                      hasMore: false,
                    );
              return http.Response(
                jsonEncode({
                  'success': true,
                  'changes': result.changes
                      .map(
                        (c) => {
                          'id': c.id,
                          'table_name': c.tableName,
                          'row_id': c.rowId,
                          'payload': c.payload,
                        },
                      )
                      .toList(),
                  'next_cursor': result.nextCursor,
                  'has_more': result.hasMore,
                }),
                200,
              );
            }
            throw StateError('unexpected request: ${request.url}');
          }),
        );

        await service.pullRemoteChanges(configured.baseUrl, configured.apiKey);

        final after = await (db.select(
          db.categories,
        )..where((t) => t.id.equals(local.id))).getSingle();
        expect(after.name, 'Renamed Remotely');
      },
    );

    test('an incoming row with an older updated_at is ignored', () async {
      final local = await seedLocalCategory();
      final incoming = local.toJson()
        ..['name'] = 'Should Not Apply'
        ..['updatedAt'] = '2000-01-01T00:00:00.000000Z'
        ..['createdByDeviceId'] = 'other-device';

      final service = buildService(
        MockClient((request) async {
          if (request.url.queryParameters['action'] == 'pull_changes') {
            return http.Response(
              jsonEncode({
                'success': true,
                'changes': [
                  {
                    'id': 1,
                    'table_name': 'categories',
                    'row_id': incoming['id'],
                    'payload': incoming,
                  },
                ],
                'next_cursor': 1,
                'has_more': false,
              }),
              200,
            );
          }
          throw StateError('unexpected request: ${request.url}');
        }),
      );

      await service.pullRemoteChanges(configured.baseUrl, configured.apiKey);

      final after = await (db.select(
        db.categories,
      )..where((t) => t.id.equals(local.id))).getSingle();
      expect(after.name, 'Original');
    });

    test(
      'an exact updated_at tie is broken deterministically by device_id',
      () async {
        final local = await seedLocalCategory();
        // Local row's own createdByDeviceId is whatever this test db's
        // seeded device is - pick an incoming id guaranteed to sort after
        // it lexicographically ('zzz...' beats any UUID).
        final incoming = local.toJson()
          ..['name'] = 'Tie Winner'
          ..['createdByDeviceId'] = 'zzzzzzzz-tie-break-wins';
        // updatedAt left exactly as the local row's own value - a genuine tie.

        final service = buildService(
          MockClient((request) async {
            if (request.url.queryParameters['action'] == 'pull_changes') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'changes': [
                    {
                      'id': 1,
                      'table_name': 'categories',
                      'row_id': incoming['id'],
                      'payload': incoming,
                    },
                  ],
                  'next_cursor': 1,
                  'has_more': false,
                }),
                200,
              );
            }
            throw StateError('unexpected request: ${request.url}');
          }),
        );

        await service.pullRemoteChanges(configured.baseUrl, configured.apiKey);

        final after = await (db.select(
          db.categories,
        )..where((t) => t.id.equals(local.id))).getSingle();
        expect(
          after.name,
          'Tie Winner',
          reason:
              'the lexicographically-greater device_id must win an exact tie',
        );
      },
    );
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
      final categoryRepository = CategoryRepositoryImpl(
        db,
        db.categoriesDao,
        syncMeta,
        const SystemClock(),
        UuidIdGenerator(),
      );
      final categoryId = UuidIdGenerator().newId();
      await categoryRepository.create(
        Category(id: categoryId, name: 'General', status: 'active'),
      );
      final deviceId = await syncMeta.deviceId();
      final now = DateTime.now().toUtc().toIso8601String();

      const productId = 'fixed-product-id-2';
      await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
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
            ),
          );

      const rowId = 'fixed-movement-id';
      await db
          .into(db.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              id: rowId,
              productId: productId,
              movementType: 'purchase',
              quantity: 5,
              createdAt: now,
              updatedAt: now,
              localRev: await syncMeta.nextLocalRev(),
              createdByDeviceId: deviceId,
            ),
          );

      final incoming =
          (await (db.select(
              db.stockMovements,
            )..where((t) => t.id.equals(rowId))).getSingle()).toJson()
            ..['quantity'] = 999;

      final service = buildService(
        MockClient((request) async {
          if (request.url.queryParameters['action'] == 'pull_changes') {
            return http.Response(
              jsonEncode({
                'success': true,
                'changes': [
                  {
                    'id': 1,
                    'table_name': 'stock_movements',
                    'row_id': rowId,
                    'payload': incoming,
                  },
                ],
                'next_cursor': 1,
                'has_more': false,
              }),
              200,
            );
          }
          throw StateError('unexpected request: ${request.url}');
        }),
      );

      await service.pullRemoteChanges(configured.baseUrl, configured.apiKey);

      final after = await (db.select(
        db.stockMovements,
      )..where((t) => t.id.equals(rowId))).getSingle();
      expect(after.quantity, 5);
    });
  });

  group('pullRemoteChanges - stock_qty recompute', () {
    test('recomputes stock_qty as the sum of all local stock_movements after applying a pulled movement', () async {
      final categoryRepository = CategoryRepositoryImpl(
        db,
        db.categoriesDao,
        syncMeta,
        const SystemClock(),
        UuidIdGenerator(),
      );
      final categoryId = UuidIdGenerator().newId();
      await categoryRepository.create(
        Category(id: categoryId, name: 'General', status: 'active'),
      );
      final deviceId = await syncMeta.deviceId();
      final now = DateTime.now().toUtc().toIso8601String();

      const productId = 'fixed-product-id';
      await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
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
            ),
          );
      // A pre-existing local movement, not itself part of this pull -
      // the recompute must still account for it.
      await db
          .into(db.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              id: 'existing-movement',
              productId: productId,
              movementType: 'purchase',
              quantity: 7,
              createdAt: now,
              updatedAt: now,
              localRev: await syncMeta.nextLocalRev(),
              createdByDeviceId: deviceId,
            ),
          );

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

      final service = buildService(
        MockClient((request) async {
          if (request.url.queryParameters['action'] == 'pull_changes') {
            return http.Response(
              jsonEncode({
                'success': true,
                'changes': [
                  {
                    'id': 1,
                    'table_name': 'stock_movements',
                    'row_id': 'pulled-movement',
                    'payload': incomingMovement,
                  },
                ],
                'next_cursor': 1,
                'has_more': false,
              }),
              200,
            );
          }
          throw StateError('unexpected request: ${request.url}');
        }),
      );

      await service.pullRemoteChanges(configured.baseUrl, configured.apiKey);

      final product = await (db.select(
        db.products,
      )..where((t) => t.id.equals(productId))).getSingle();
      expect(
        product.stockQty,
        4,
        reason: '7 (existing) + (-3) (pulled) = 4, a full re-sum not an incremental delta',
      );
      expect(
        product.localRev,
        lessThan(500),
        reason: 'the stock_qty recompute must never bump the product\'s own local_rev',
      );
    });
  });

  group('native LAN change exchange', () {
    test(
      'applies once and queues the original source revision for cloud relay',
      () async {
        final sourceRepo = CategoryRepositoryImpl(
          db,
          db.categoriesDao,
          syncMeta,
          const SystemClock(),
          UuidIdGenerator(),
        );
        await sourceRepo.create(
          const Category(
            id: 'lan-category',
            name: 'LAN category',
            status: 'active',
          ),
        );
        final sourceDeviceId = await syncMeta.deviceId();
        final sourceService = buildService(
          MockClient((_) async => throw StateError('unused')),
        );

        final receiverDb = AppDatabase(NativeDatabase.memory());
        addTearDown(receiverDb.close);
        final receiverMeta = SyncMetadataService(receiverDb);
        final pushedBodies = <Map<String, dynamic>>[];
        final receiverService = SyncService(
          receiverDb,
          receiverMeta,
          PlatformSyncGateway(
            MockClient((request) async {
              pushedBodies.add(
                (jsonDecode(request.body) as Map).cast<String, dynamic>(),
              );
              return http.Response('{"success":true}', 200);
            }),
          ),
          _FakeCredentialsService(configured),
        );

        final changes = await sourceService.exportLanChanges(
          await receiverService.lanRevisionCursors(),
        );
        final categoryChanges = changes
            .where((change) => change.rowId == 'lan-category')
            .toList();
        expect(categoryChanges, hasLength(1));

        await receiverService.applyLanChanges(categoryChanges);
        await receiverService.applyLanChanges(categoryChanges);
        expect(
          (await receiverDb.select(receiverDb.categories).get()).where(
            (row) => row.id == 'lan-category',
          ),
          hasLength(1),
        );

        await receiverService.pushLocalChanges(
          configured.baseUrl,
          configured.apiKey,
        );
        final relayed = pushedBodies
            .expand((body) => (body['changes'] as List).whereType<Map>())
            .where((change) => change['source_device_id'] == sourceDeviceId)
            .toList();
        expect(relayed, hasLength(1));
        expect(relayed.single['local_rev'], categoryChanges.single.localRev);

        pushedBodies.clear();
        await receiverService.pushLocalChanges(
          configured.baseUrl,
          configured.apiKey,
        );
        expect(
          pushedBodies
              .expand((body) => body['changes'] as List)
              .where(
                (change) =>
                    (change as Map)['source_device_id'] == sourceDeviceId,
              ),
          isEmpty,
          reason: 'an acknowledged relay must leave the durable outbox',
        );
      },
    );

    test(
      'a relayed change the server permanently refuses does not block pushLocalChanges, and is not retried forever',
      () async {
        // Reproduces a real report: leaving a shop calls pushLocalChanges,
        // which also drains this device's LAN relay outbox - a source
        // device that relayed a change here and has SINCE left the shop or
        // been disabled makes the server refuse that one relay (422), and
        // that used to make pushLocalChanges itself look like it failed,
        // blocking leaving the shop over data that was never this device's
        // own.
        final sourceRepo = CategoryRepositoryImpl(
          db,
          db.categoriesDao,
          syncMeta,
          const SystemClock(),
          UuidIdGenerator(),
        );
        await sourceRepo.create(
          const Category(
            id: 'stale-relay-category',
            name: 'Stale relay',
            status: 'active',
          ),
        );
        final sourceDeviceId = await syncMeta.deviceId();
        final sourceService = buildService(
          MockClient((_) async => throw StateError('unused')),
        );

        final receiverDb = AppDatabase(NativeDatabase.memory());
        addTearDown(receiverDb.close);
        final receiverMeta = SyncMetadataService(receiverDb);
        final pushedBodies = <Map<String, dynamic>>[];
        final receiverService = SyncService(
          receiverDb,
          receiverMeta,
          PlatformSyncGateway(
            MockClient((request) async {
              final body = (jsonDecode(request.body) as Map)
                  .cast<String, dynamic>();
              pushedBodies.add(body);
              final touchesStaleSource = (body['changes'] as List)
                  .cast<Map>()
                  .any((c) => c['source_device_id'] == sourceDeviceId);
              if (touchesStaleSource) {
                return http.Response(
                  jsonEncode({
                    'success': false,
                    'message':
                        'Could not record changes: Relayed source device is not active in this shop.',
                  }),
                  422,
                );
              }
              return http.Response('{"success":true}', 200);
            }),
          ),
          _FakeCredentialsService(configured),
        );

        final changes = await sourceService.exportLanChanges(
          await receiverService.lanRevisionCursors(),
        );
        final staleChange = changes
            .where((c) => c.rowId == 'stale-relay-category')
            .toList();
        expect(staleChange, hasLength(1));
        await receiverService.applyLanChanges(staleChange);

        // Must not throw - the receiver's own seeded data is real and must
        // still reach the server even though this stale relay never will.
        await receiverService.pushLocalChanges(
          configured.baseUrl,
          configured.apiKey,
        );
        expect(
          pushedBodies.any(
            (body) => (body['changes'] as List).cast<Map>().any(
              (c) => c['source_device_id'] == sourceDeviceId,
            ),
          ),
          isTrue,
          reason: 'the relay really was attempted, not silently skipped',
        );

        pushedBodies.clear();
        await receiverService.pushLocalChanges(
          configured.baseUrl,
          configured.apiKey,
        );
        expect(
          pushedBodies
              .expand((body) => body['changes'] as List)
              .where(
                (c) => (c as Map)['source_device_id'] == sourceDeviceId,
              ),
          isEmpty,
          reason:
              'a permanently-rejected relay must be dropped, not retried on every future cycle',
        );
      },
    );

    test(
      'a mixed relay batch drops only the entry the server rejects - the rest still reach the cloud',
      () async {
        final sourceRepo = CategoryRepositoryImpl(
          db,
          db.categoriesDao,
          syncMeta,
          const SystemClock(),
          UuidIdGenerator(),
        );
        await sourceRepo.create(
          const Category(id: 'good-relay', name: 'Good', status: 'active'),
        );
        await sourceRepo.create(
          const Category(id: 'bad-relay', name: 'Bad', status: 'active'),
        );
        final sourceDeviceId = await syncMeta.deviceId();
        final sourceService = buildService(
          MockClient((_) async => throw StateError('unused')),
        );

        final receiverDb = AppDatabase(NativeDatabase.memory());
        addTearDown(receiverDb.close);
        final receiverMeta = SyncMetadataService(receiverDb);
        final acceptedRowIds = <String>[];
        final receiverService = SyncService(
          receiverDb,
          receiverMeta,
          PlatformSyncGateway(
            MockClient((request) async {
              final body = (jsonDecode(request.body) as Map)
                  .cast<String, dynamic>();
              final relayed = (body['changes'] as List)
                  .cast<Map>()
                  .where((c) => c['source_device_id'] == sourceDeviceId)
                  .toList();
              // The server rejects the WHOLE request over one bad entry,
              // batched with good ones or not - exactly what forces the
              // one-at-a-time fallback under test here.
              if (relayed.any((c) => c['row_id'] == 'bad-relay')) {
                return http.Response(
                  jsonEncode({
                    'success': false,
                    'message':
                        'Could not record changes: Relayed source device is not active in this shop.',
                  }),
                  422,
                );
              }
              acceptedRowIds.addAll(
                relayed.map((c) => c['row_id'] as String),
              );
              return http.Response('{"success":true}', 200);
            }),
          ),
          _FakeCredentialsService(configured),
        );

        final changes = await sourceService.exportLanChanges(
          await receiverService.lanRevisionCursors(),
        );
        final relayChanges = changes
            .where((c) => c.rowId == 'good-relay' || c.rowId == 'bad-relay')
            .toList();
        expect(relayChanges, hasLength(2));
        await receiverService.applyLanChanges(relayChanges);

        await receiverService.pushLocalChanges(
          configured.baseUrl,
          configured.apiKey,
        );

        expect(
          acceptedRowIds,
          contains('good-relay'),
          reason:
              'a batch-mate of a bad relay must still get through via the one-at-a-time fallback',
        );
        expect(acceptedRowIds, isNot(contains('bad-relay')));
      },
    );
  });
}
