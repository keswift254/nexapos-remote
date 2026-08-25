import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../core/result.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/id_generator.dart';
import '../../data/local/database.dart';
import '../../data/local/daos/products_dao.dart';
import '../../data/local/daos/stock_movements_dao.dart';
import '../../data/local/sync_metadata.dart';
import 'package:drift/drift.dart' show Value;

part 'stock_service.g.dart';

@Riverpod(keepAlive: true)
StockService stockService(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return StockService(
    db,
    db.productsDao,
    db.stockMovementsDao,
    ref.watch(syncMetadataProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
  );
}

/// The single write path for products.stock_qty, for every caller:
/// checkout, manual stock adjustment, and product creation with an
/// initial quantity alike. No other code in this app is allowed to
/// touch stock_qty directly - see products_table.dart and
/// stock_movements_table.dart for why that invariant is what makes
/// stock_qty provably "replay stock_movements and sum".
class StockService {
  final AppDatabase _db;
  final ProductsDao _productsDao;
  final StockMovementsDao _stockMovementsDao;
  final SyncMetadataService _syncMeta;
  final Clock _clock;
  final IdGenerator _idGenerator;

  StockService(
    this._db,
    this._productsDao,
    this._stockMovementsDao,
    this._syncMeta,
    this._clock,
    this._idGenerator,
  );

  /// [delta] is signed: positive for stock coming in (purchase, return,
  /// initial quantity), negative for stock going out (sale, shrinkage
  /// adjustment). Same check-and-guard shape as PHP's checkout route:
  /// atomically verifies stock_qty + delta >= 0 before committing.
  Future<Result<void>> applyMovement({
    required String productId,
    required String movementType,
    required int delta,
    String? note,
    String? userId,
  }) async {
    final product = await _productsDao.findById(productId);
    if (product == null) {
      return const Result.failure('Product not found.');
    }

    return _db.transaction(() async {
      final now = _clock.now().toIso8601String();
      final rowsAffected = await _productsDao.applyStockDelta(productId, delta, now);
      if (rowsAffected == 0) {
        return Result.failure('Only ${product.stockQty} ${product.name} in stock.');
      }

      final rev = await _syncMeta.nextLocalRev();
      final deviceId = await _syncMeta.deviceId();
      await _stockMovementsDao.insertMovement(StockMovementsCompanion.insert(
        id: _idGenerator.newId(),
        productId: productId,
        userId: Value(userId),
        movementType: movementType,
        quantity: delta,
        note: Value(note),
        createdAt: now,
        updatedAt: now,
        localRev: rev,
        createdByDeviceId: deviceId,
      ));
      return const Result.ok(null);
    });
  }
}
