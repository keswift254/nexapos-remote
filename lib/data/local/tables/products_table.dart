import 'package:drift/drift.dart';
import 'synced_columns.dart';
import 'categories_table.dart';

/// Status values: 'active', 'disabled' (mirrors PHP's products.status).
///
/// Deliberate deviation from PHP: [categoryId] is a real FK here, not the
/// free-text `products.category` VARCHAR the PHP schema uses (PHP
/// compensates with a manual rename-cascade in its update_category
/// route). A free-text category is exactly the kind of thing that
/// becomes a sync nightmare later - fixing it now, before multi-device
/// data exists, costs nothing.
///
/// [stockQty] is a cached/materialized column - cart and product-list
/// screens need instant reads, not a SUM() over stock_movements on every
/// render. It is only ever written by StockService.applyMovement(), the
/// single write path described in stock_movements_table.dart.
class Products extends Table with SyncedColumns {
  TextColumn get sku => text()();
  TextColumn get name => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get imagePath => text().nullable()();
  IntColumn get retailPriceCents => integer()();
  IntColumn get wholesalePriceCents => integer()();
  IntColumn get costPriceCents => integer()();
  IntColumn get stockQty => integer().withDefault(const Constant(0))();
  IntColumn get reorderLevel => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('active'))();
}
