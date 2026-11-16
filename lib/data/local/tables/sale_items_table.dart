import 'package:drift/drift.dart';
import 'synced_columns.dart';
import 'sales_table.dart';
import 'products_table.dart';

/// [productId] is nullable with the same snapshot-on-delete intent as
/// PHP: a soft-deleted product still resolves, so unlike PHP this
/// column never actually needs to be nulled out - kept nullable anyway
/// for schema parity and to allow manual (non-catalog) sale items.
///
/// Audit columns added here for uniformity even though PHP's
/// sale_items table has none at all.
class SaleItems extends Table with SyncedColumns {
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get productId => text().nullable().references(Products, #id)();
  TextColumn get itemName => text()();
  IntColumn get quantity => integer()();
  IntColumn get unitPriceCents => integer()();
  IntColumn get costPriceCents => integer()();
  IntColumn get lineTotalCents => integer()();

  // Set on a line of a refund sale (negative quantity and line total): the line of
  // the ORIGINAL sale it gives back, so what is still refundable can be worked out
  // exactly (names and prices repeat, ids do not). Null on every ordinary sale line.
  TextColumn get refundOfItemId => text().nullable()();
}
