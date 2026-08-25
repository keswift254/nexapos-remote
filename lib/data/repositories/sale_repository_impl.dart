import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/sale_repository.dart';
import '../local/database.dart' hide Sale;
import '../local/database.dart' as drift_db show Sale;
import '../local/daos/sales_dao.dart';
import '../local/sync_metadata.dart';

part 'sale_repository_impl.g.dart';

@Riverpod(keepAlive: true)
SaleRepository saleRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return SaleRepositoryImpl(
    db,
    db.salesDao,
    ref.watch(syncMetadataProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
  );
}

class SaleRepositoryImpl implements SaleRepository {
  final AppDatabase _db;
  final SalesDao _dao;
  final SyncMetadataService _syncMeta;
  final Clock _clock;
  final IdGenerator _idGenerator;

  SaleRepositoryImpl(this._db, this._dao, this._syncMeta, this._clock, this._idGenerator);

  Sale _toEntity(drift_db.Sale row) => Sale(
        id: row.id,
        saleNumber: row.saleNumber,
        userId: row.userId,
        customerName: row.customerName ?? 'Walk-in customer',
        customerPhone: row.customerPhone,
        saleType: row.saleType,
        paymentMethod: row.paymentMethod,
        subtotal: Money(row.subtotalCents),
        discount: Money(row.discountCents),
        total: Money(row.totalCents),
        status: row.status,
        createdAt: DateTime.parse(row.createdAt),
      );

  @override
  Future<Sale?> findById(String id) async {
    final row = await _dao.findById(id);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<String> create(Sale sale) async {
    final id = sale.id.isEmpty ? _idGenerator.newId() : sale.id;
    await _db.transaction(() async {
      final now = _clock.now().toIso8601String();
      final rev = await _syncMeta.nextLocalRev();
      final deviceId = await _syncMeta.deviceId();
      await _dao.insertSale(SalesCompanion.insert(
        id: id,
        saleNumber: sale.saleNumber,
        userId: sale.userId,
        customerName: Value(sale.customerName),
        customerPhone: Value(sale.customerPhone),
        saleType: sale.saleType,
        paymentMethod: sale.paymentMethod,
        subtotalCents: sale.subtotal.cents,
        discountCents: Value(sale.discount.cents),
        totalCents: sale.total.cents,
        status: sale.status,
        createdAt: now,
        updatedAt: now,
        localRev: rev,
        createdByDeviceId: deviceId,
      ));
    });
    return id;
  }

  @override
  Future<void> updateStatus(String id, String status) async {
    await _db.transaction(() async {
      final now = _clock.now().toIso8601String();
      final rev = await _syncMeta.nextLocalRev();
      await _dao.updateStatus(id, status, now, rev);
    });
  }

  @override
  Future<List<Sale>> findPendingPaystack() async {
    final rows = await _dao.findPendingPaystack();
    return rows.map(_toEntity).toList();
  }
}
