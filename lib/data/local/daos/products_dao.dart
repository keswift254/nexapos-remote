import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/products_table.dart';

part 'products_dao.g.dart';

@DriftAccessor(tables: [Products])
class ProductsDao extends DatabaseAccessor<AppDatabase> with _$ProductsDaoMixin {
  ProductsDao(super.db);

  Future<List<Product>> getAll() {
    return (select(products)..where((p) => p.deletedAt.isNull())).get();
  }

  Future<Product?> findById(String id) {
    return (select(products)..where((p) => p.id.equals(id) & p.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<Product?> findBySku(String sku) {
    return (select(products)..where((p) => p.sku.equals(sku) & p.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Case-insensitive match on name+category, used by the xlsx importer
  /// to decide create-vs-merge exactly like PHP's InventoryExcelService.
  Future<Product?> findByNameAndCategory(String name, String categoryId) {
    return (select(products)
          ..where((p) =>
              p.name.lower().equals(name.toLowerCase()) &
              p.categoryId.equals(categoryId) &
              p.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<void> insertProduct(ProductsCompanion companion) {
    return into(products).insert(companion);
  }

  Future<void> updateProduct(String id, ProductsCompanion companion) {
    return (update(products)..where((p) => p.id.equals(id))).write(companion);
  }

  Future<int> softDelete(String id, String deletedAt, int localRev) {
    return (update(products)..where((p) => p.id.equals(id) & p.deletedAt.isNull())).write(
      ProductsCompanion(
        deletedAt: Value(deletedAt),
        updatedAt: Value(deletedAt),
        localRev: Value(localRev),
      ),
    );
  }

  /// The ONLY place stock_qty is ever written - see StockService, which
  /// calls this and inserts the paired stock_movements row in the same
  /// transaction. Uses the same check-and-guard shape as PHP's
  /// `UPDATE products SET stock_qty = stock_qty - ? WHERE stock_qty >= ?`:
  /// returns the number of rows affected (0 means the guard rejected it).
  Future<int> applyStockDelta(String id, int delta, String updatedAt) async {
    final query = customUpdate(
      'UPDATE products SET stock_qty = stock_qty + ?1, updated_at = ?2 '
      'WHERE id = ?3 AND stock_qty + ?1 >= 0',
      variables: [
        Variable.withInt(delta),
        Variable.withString(updatedAt),
        Variable.withString(id),
      ],
      updates: {products},
    );
    return query;
  }
}
