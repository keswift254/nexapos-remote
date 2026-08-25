import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/repositories/sale_item_repository.dart';
import '../local/database.dart' hide SaleItem;
import '../local/database.dart' as drift_db show SaleItem;
import '../local/daos/sale_items_dao.dart';
import '../local/sync_metadata.dart';

part 'sale_item_repository_impl.g.dart';

@Riverpod(keepAlive: true)
SaleItemRepository saleItemRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return SaleItemRepositoryImpl(
    db,
    db.saleItemsDao,
    ref.watch(syncMetadataProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
  );
}

class SaleItemRepositoryImpl implements SaleItemRepository {
  final AppDatabase _db;
  final SaleItemsDao _dao;
  final SyncMetadataService _syncMeta;
  final Clock _clock;
  final IdGenerator _idGenerator;

  SaleItemRepositoryImpl(this._db, this._dao, this._syncMeta, this._clock, this._idGenerator);

  SaleItem _toEntity(drift_db.SaleItem row) => SaleItem(
        id: row.id,
        saleId: row.saleId,
        productId: row.productId,
        itemName: row.itemName,
        quantity: row.quantity,
        unitPrice: Money(row.unitPriceCents),
        costPrice: Money(row.costPriceCents),
        lineTotal: Money(row.lineTotalCents),
      );

  @override
  Future<List<SaleItem>> forSale(String saleId) async {
    final rows = await _dao.forSale(saleId);
    return rows.map(_toEntity).toList();
  }

  @override
  Future<void> createMany(List<SaleItem> items) async {
    if (items.isEmpty) return;
    await _db.transaction(() async {
      final now = _clock.now().toIso8601String();
      final deviceId = await _syncMeta.deviceId();
      final companions = <SaleItemsCompanion>[];
      for (final item in items) {
        final rev = await _syncMeta.nextLocalRev();
        companions.add(SaleItemsCompanion.insert(
          id: item.id.isEmpty ? _idGenerator.newId() : item.id,
          saleId: item.saleId,
          productId: Value(item.productId),
          itemName: item.itemName,
          quantity: item.quantity,
          unitPriceCents: item.unitPrice.cents,
          costPriceCents: item.costPrice.cents,
          lineTotalCents: item.lineTotal.cents,
          createdAt: now,
          updatedAt: now,
          localRev: rev,
          createdByDeviceId: deviceId,
        ));
      }
      await _dao.insertMany(companions);
    });
  }
}
