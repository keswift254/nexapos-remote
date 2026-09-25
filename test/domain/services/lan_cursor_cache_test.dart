import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/core/utils/id_generator.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Category;
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/data/repositories/category_repository_impl.dart';
import 'package:nexapos_mobile/data/sync/platform_sync_gateway.dart';
import 'package:nexapos_mobile/domain/entities/category.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/services/lan_cursor_cache.dart';
import 'package:nexapos_mobile/domain/services/paystack_credentials_service.dart';
import 'package:nexapos_mobile/domain/services/sync_service.dart';

class _Credentials implements PaystackCredentialsService {
  @override
  Future<PaystackCredentials> load() async => const PaystackCredentials(
    baseUrl: 'http://localhost/index.php', apiKey: 'k', currency: 'KES', defaultEmail: '',
  );
  @override
  Future<void> save(PaystackCredentials value) async {}
  @override
  Future<String> loadDeviceLabel() async => '';
  @override
  Future<void> saveDeviceLabel(String label) async {}
  @override
  Future<void> clearRegistration() async {}
}

void main() {
  group('LanCursorCache', () {
    test('works the answer out once and keeps it', () async {
      var computed = 0;
      final cache = LanCursorCache(() async {
        computed++;
        return {'a': computed};
      });

      expect(await cache.get(), {'a': 1});
      expect(await cache.get(), {'a': 1});
      expect(computed, 1);
    });

    test('works it out again after an invalidation', () async {
      var computed = 0;
      final cache = LanCursorCache(() async => {'a': ++computed});
      await cache.get();

      cache.invalidate();

      expect(await cache.get(), {'a': 2});
    });

    test('is invalidated by the database change stream it is attached to', () async {
      final updates = StreamController<Object?>.broadcast();
      addTearDown(updates.close);
      var computed = 0;
      final cache = LanCursorCache(() async => {'a': ++computed});
      cache.attach(updates.stream);
      addTearDown(cache.dispose);
      await cache.get();

      updates.add('a write happened');
      await Future<void>.delayed(Duration.zero);

      expect(await cache.get(), {'a': 2});
    });

    test('a write that lands while it is being worked out is not kept as if it were current', () async {
      final started = Completer<void>();
      final release = Completer<void>();
      var computed = 0;
      final cache = LanCursorCache(() async {
        final mine = ++computed;
        if (mine == 1) {
          started.complete();
          await release.future; // slow first computation
        }
        return {'a': mine};
      });

      final first = cache.get();
      await started.future;
      cache.invalidate(); // a write lands meanwhile
      release.complete();

      expect(await first, {'a': 1}, reason: 'the caller still gets an answer (at worst a moment behind)');
      expect(await cache.get(), {'a': 2}, reason: 'but the stale one was not kept');
    });

    test('a kept answer is not trusted forever: it is worked out again once it is old enough', () async {
      var now = Duration.zero;
      var computed = 0;
      final cache = LanCursorCache(
        () async => {'a': ++computed},
        maxAge: const Duration(seconds: 10),
        elapsed: () => now,
      );
      await cache.get();

      now = const Duration(seconds: 9);
      expect(await cache.get(), {'a': 1}, reason: 'still fresh enough');

      now = const Duration(seconds: 10);
      expect(await cache.get(), {'a': 2}, reason: 'old enough - the backstop for a write that missed the change stream');
      expect(await cache.get(), {'a': 2});
    });

    test('stops listening once disposed', () async {
      final updates = StreamController<Object?>.broadcast();
      addTearDown(updates.close);
      var computed = 0;
      final cache = LanCursorCache(() async => {'a': ++computed});
      cache.attach(updates.stream);
      await cache.get();
      await cache.dispose();

      updates.add('a write happened');
      await Future<void>.delayed(Duration.zero);

      expect(await cache.get(), {'a': 1}, reason: 'no longer invalidated');
    });
  });

  test('against a real database: the summary follows what is written, and is not recomputed when nothing changed', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final meta = SyncMetadataService(db);
    final service = SyncService(
      db, meta, PlatformSyncGateway(MockClient((_) async => throw StateError('offline'))), _Credentials(),
    );
    var computed = 0;
    final cache = LanCursorCache(() {
      computed++;
      return service.lanRevisionCursors();
    });
    cache.attach(db.tableUpdates());
    addTearDown(cache.dispose);
    final categories = CategoryRepositoryImpl(db, db.categoriesDao, meta, const SystemClock(), UuidIdGenerator());
    final deviceId = await meta.deviceId();

    final before = await cache.get();
    await cache.get();
    await cache.get();
    expect(computed, 1, reason: 'idle: read once, not every time');

    await categories.create(const Category(id: 'c1', name: 'One', status: 'active'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final after = await cache.get();

    expect(computed, 2);
    expect(after[deviceId] ?? 0, greaterThan(before[deviceId] ?? 0), reason: 'the new row moves this device\'s revision on');
  });
}
