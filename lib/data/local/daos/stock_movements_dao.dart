import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/stock_movements_table.dart';

part 'stock_movements_dao.g.dart';

/// Append-only by construction: only insertMovement() is exposed, no
/// update()/delete() - see stock_movements_table.dart for why this
/// matters for the stock_qty reconciliation invariant.
@DriftAccessor(tables: [StockMovements])
class StockMovementsDao extends DatabaseAccessor<AppDatabase> with _$StockMovementsDaoMixin {
  StockMovementsDao(super.db);

  Future<void> insertMovement(StockMovementsCompanion companion) {
    return into(stockMovements).insert(companion);
  }

  Future<List<StockMovement>> forProduct(String productId) {
    return (select(stockMovements)
          ..where((m) => m.productId.equals(productId))
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .get();
  }
}
