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
  test('changes received over the LAN wake up everything watching the database (dashboard, lists)', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final sourceDb = AppDatabase(NativeDatabase.memory());
    final receiverDb = AppDatabase(NativeDatabase.memory());
    addTearDown(sourceDb.close);
    addTearDown(receiverDb.close);
    final sourceMeta = SyncMetadataService(sourceDb);
    final receiverMeta = SyncMetadataService(receiverDb);
    await CategoryRepositoryImpl(sourceDb, sourceDb.categoriesDao, sourceMeta, const SystemClock(), UuidIdGenerator())
        .create(const Category(id: 'lan-cat', name: 'Made on the other till', status: 'active'));
    SyncService build(AppDatabase db, SyncMetadataService meta) =>
        SyncService(db, meta, PlatformSyncGateway(MockClient((_) async => throw StateError('offline'))), _Credentials());
    final source = build(sourceDb, sourceMeta);
    final receiver = build(receiverDb, receiverMeta);

    final changes = (await source.exportLanChanges(await receiver.lanRevisionCursors()))
        .where((c) => c.rowId == 'lan-cat')
        .toList();
    expect(changes, hasLength(1));

    // What the dashboard's change ticker listens to.
    final seen = <Set<TableUpdate>>[];
    final subscription = receiverDb.tableUpdates().listen(seen.add);
    addTearDown(subscription.cancel);
    await Future<void>.delayed(Duration.zero);

    await receiver.applyLanChanges(changes);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final tables = seen.expand((s) => s).map((u) => u.table).toSet();
    expect(tables, contains('categories'), reason: 'a change applied from another device must announce itself');
  });
}
