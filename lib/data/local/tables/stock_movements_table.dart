import 'package:drift/drift.dart';
import 'synced_columns.dart';
import 'products_table.dart';
import 'users_table.dart';

/// movement_type: 'purchase', 'sale', 'adjustment', 'return' (same 4
/// values as PHP). [quantity] is signed - positive for stock coming in,
/// negative for stock going out.
///
/// Append-only by construction: StockDao exposes insert() only, no
/// update() or delete(), so this table is genuinely complete and
/// authoritative on-device, closing the gap found in PHP where some
/// product-creation paths silently skip logging an initial movement.
/// products.stock_qty is provably always "replay these rows and sum" -
/// see StockService.applyMovement, the single writer for both this
/// table and products.stock_qty together in one transaction.
class StockMovements extends Table with SyncedColumns {
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get userId => text().nullable().references(Users, #id)();
  TextColumn get movementType => text()();
  IntColumn get quantity => integer()();
  TextColumn get note => text().nullable()();
}
