import '../entities/product.dart';

abstract class ProductRepository {
  Future<List<Product>> getAll();

  Future<Product?> findById(String id);

  Future<Product?> findBySku(String sku);

  Future<Product?> findByNameAndCategory(String name, String categoryId);

  /// Inserts a new product row with stock_qty always 0, regardless of
  /// what [product].stockQty holds - the only way stock_qty ever
  /// becomes nonzero is through StockService.applyMovement(), even for
  /// a brand new product's initial quantity. See product_table.dart.
  Future<String> create(Product product);

  /// Updates every field except stockQty, which this method never
  /// touches - editing a product's name/price/etc. must never
  /// side-effect its stock count.
  Future<void> update(Product product);

  /// Soft-delete only (sets deletedAt) - this table uses SyncedColumns,
  /// which never exposes a hard delete (see synced_columns.dart's doc
  /// comment). Safe regardless of the product's sale/stock-movement
  /// history: sale_items snapshots its own itemName/prices at sale time
  /// and stock_movements is its own permanent audit log, so neither
  /// depends on the product row still appearing in normal queries -
  /// only on the row still existing, which a soft delete never changes.
  /// Returns false if no matching, not-already-deleted row was found.
  Future<bool> delete(String id);
}
