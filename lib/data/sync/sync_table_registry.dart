import 'package:drift/drift.dart';
import '../local/database.dart';

/// One entry per table in the sync engine's generic push/pull loop -
/// deliberately NOT per-table mapping logic (Drift's own generated
/// toJson()/fromJson()/toCompanion() already does that, confirmed
/// present for every synced table's row class), just the small amount
/// of per-table glue Dart's type system can't unify away: which
/// concrete Drift table/row/companion this is, whether it's append-only
/// (no update path exists at all, so applying an incoming row is just
/// insert-or-ignore, no last-write-wins compare needed), and - for
/// products only - which columns must never be overwritten by a pull.
class SyncTableAdapter {
  final String tableName;
  final bool isAppendOnly;

  /// Rows this device authored (createdByDeviceId = this device) with
  /// local_rev > sinceRev, as plain JSON maps ready to push.
  final Future<List<Map<String, dynamic>>> Function(AppDatabase db, String deviceId, int sinceRev) pendingRowsJson;

  /// LWW tables only: the local row's (updatedAt, createdByDeviceId) for
  /// the given id, or null if no local copy exists yet. Used by
  /// SyncService to decide whether an incoming change should win before
  /// ever calling [applyPayload].
  final Future<({String updatedAt, String deviceId})?> Function(AppDatabase db, String id)? findLocalMeta;

  /// Writes an incoming payload as the new local truth for its row -
  /// insert if missing, overwrite if present. For products, silently
  /// leaves stockQty/imagePath untouched via Value.absent() (Drift skips
  /// absent fields on update, and uses the column's own default -
  /// 0 for stockQty, null for imagePath - on insert), never the
  /// incoming value.
  final Future<void> Function(AppDatabase db, Map<String, dynamic> payload) applyPayload;

  const SyncTableAdapter({
    required this.tableName,
    required this.isAppendOnly,
    required this.pendingRowsJson,
    this.findLocalMeta,
    required this.applyPayload,
  });
}

Future<List<Map<String, dynamic>>> _pending<Row>(
  Selectable<Row> query,
  Map<String, dynamic> Function(Row) toJson,
) async {
  final rows = await query.get();
  return rows.map(toJson).toList();
}

final Map<String, SyncTableAdapter> syncTableAdapters = {
  'roles': SyncTableAdapter(
    tableName: 'roles',
    isAppendOnly: false,
    pendingRowsJson: (db, deviceId, sinceRev) => _pending(
      db.select(db.roles)..where((t) => t.createdByDeviceId.equals(deviceId) & t.localRev.isBiggerThanValue(sinceRev)),
      (row) => row.toJson(),
    ),
    findLocalMeta: (db, id) async {
      final row = await (db.select(db.roles)..where((t) => t.id.equals(id))).getSingleOrNull();
      return row == null ? null : (updatedAt: row.updatedAt, deviceId: row.createdByDeviceId);
    },
    applyPayload: (db, json) => db.into(db.roles).insertOnConflictUpdate(Role.fromJson(json).toCompanion(false)),
  ),
  'users': SyncTableAdapter(
    tableName: 'users',
    isAppendOnly: false,
    pendingRowsJson: (db, deviceId, sinceRev) => _pending(
      db.select(db.users)..where((t) => t.createdByDeviceId.equals(deviceId) & t.localRev.isBiggerThanValue(sinceRev)),
      (row) => row.toJson(),
    ),
    findLocalMeta: (db, id) async {
      final row = await (db.select(db.users)..where((t) => t.id.equals(id))).getSingleOrNull();
      return row == null ? null : (updatedAt: row.updatedAt, deviceId: row.createdByDeviceId);
    },
    applyPayload: (db, json) => db.into(db.users).insertOnConflictUpdate(User.fromJson(json).toCompanion(false)),
  ),
  'categories': SyncTableAdapter(
    tableName: 'categories',
    isAppendOnly: false,
    pendingRowsJson: (db, deviceId, sinceRev) => _pending(
      db.select(db.categories)..where((t) => t.createdByDeviceId.equals(deviceId) & t.localRev.isBiggerThanValue(sinceRev)),
      (row) => row.toJson(),
    ),
    findLocalMeta: (db, id) async {
      final row = await (db.select(db.categories)..where((t) => t.id.equals(id))).getSingleOrNull();
      return row == null ? null : (updatedAt: row.updatedAt, deviceId: row.createdByDeviceId);
    },
    applyPayload: (db, json) => db.into(db.categories).insertOnConflictUpdate(Category.fromJson(json).toCompanion(false)),
  ),
  'products': SyncTableAdapter(
    tableName: 'products',
    isAppendOnly: false,
    pendingRowsJson: (db, deviceId, sinceRev) => _pending(
      db.select(db.products)..where((t) => t.createdByDeviceId.equals(deviceId) & t.localRev.isBiggerThanValue(sinceRev)),
      (row) => row.toJson(),
    ),
    findLocalMeta: (db, id) async {
      final row = await (db.select(db.products)..where((t) => t.id.equals(id))).getSingleOrNull();
      return row == null ? null : (updatedAt: row.updatedAt, deviceId: row.createdByDeviceId);
    },
    applyPayload: (db, json) => db.into(db.products).insertOnConflictUpdate(
          Product.fromJson(json).toCompanion(false).copyWith(
                stockQty: const Value.absent(),
                imagePath: const Value.absent(),
              ),
        ),
  ),
  'sales': SyncTableAdapter(
    tableName: 'sales',
    isAppendOnly: false,
    pendingRowsJson: (db, deviceId, sinceRev) => _pending(
      db.select(db.sales)..where((t) => t.createdByDeviceId.equals(deviceId) & t.localRev.isBiggerThanValue(sinceRev)),
      (row) => row.toJson(),
    ),
    findLocalMeta: (db, id) async {
      final row = await (db.select(db.sales)..where((t) => t.id.equals(id))).getSingleOrNull();
      return row == null ? null : (updatedAt: row.updatedAt, deviceId: row.createdByDeviceId);
    },
    applyPayload: (db, json) => db.into(db.sales).insertOnConflictUpdate(Sale.fromJson(json).toCompanion(false)),
  ),
  // sale_items: no update path exists anywhere (immutable by design,
  // per sale_item_repository.dart) - applying an incoming row is purely
  // insert-or-ignore, never a LWW compare.
  'sale_items': SyncTableAdapter(
    tableName: 'sale_items',
    isAppendOnly: true,
    pendingRowsJson: (db, deviceId, sinceRev) => _pending(
      db.select(db.saleItems)..where((t) => t.createdByDeviceId.equals(deviceId) & t.localRev.isBiggerThanValue(sinceRev)),
      (row) => row.toJson(),
    ),
    applyPayload: (db, json) => db.into(db.saleItems).insert(
          SaleItem.fromJson(json).toCompanion(false),
          mode: InsertMode.insertOrIgnore,
        ),
  ),
  'expenses': SyncTableAdapter(
    tableName: 'expenses',
    isAppendOnly: false,
    pendingRowsJson: (db, deviceId, sinceRev) => _pending(
      db.select(db.expenses)..where((t) => t.createdByDeviceId.equals(deviceId) & t.localRev.isBiggerThanValue(sinceRev)),
      (row) => row.toJson(),
    ),
    findLocalMeta: (db, id) async {
      final row = await (db.select(db.expenses)..where((t) => t.id.equals(id))).getSingleOrNull();
      return row == null ? null : (updatedAt: row.updatedAt, deviceId: row.createdByDeviceId);
    },
    applyPayload: (db, json) => db.into(db.expenses).insertOnConflictUpdate(Expense.fromJson(json).toCompanion(false)),
  ),
  // stock_movements: append-only by construction (StockMovementsDao
  // exposes insert only) - see stock_movements_table.dart. products
  // stock_qty is deliberately recomputed from this table after a pull,
  // never synced as a plain field - see SyncService.
  'stock_movements': SyncTableAdapter(
    tableName: 'stock_movements',
    isAppendOnly: true,
    pendingRowsJson: (db, deviceId, sinceRev) => _pending(
      db.select(db.stockMovements)..where((t) => t.createdByDeviceId.equals(deviceId) & t.localRev.isBiggerThanValue(sinceRev)),
      (row) => row.toJson(),
    ),
    applyPayload: (db, json) => db.into(db.stockMovements).insert(
          StockMovement.fromJson(json).toCompanion(false),
          mode: InsertMode.insertOrIgnore,
        ),
  ),
  'payment_records': SyncTableAdapter(
    tableName: 'payment_records',
    isAppendOnly: false,
    pendingRowsJson: (db, deviceId, sinceRev) => _pending(
      db.select(db.paymentRecords)..where((t) => t.createdByDeviceId.equals(deviceId) & t.localRev.isBiggerThanValue(sinceRev)),
      (row) => row.toJson(),
    ),
    findLocalMeta: (db, id) async {
      final row = await (db.select(db.paymentRecords)..where((t) => t.id.equals(id))).getSingleOrNull();
      return row == null ? null : (updatedAt: row.updatedAt, deviceId: row.createdByDeviceId);
    },
    applyPayload: (db, json) =>
        db.into(db.paymentRecords).insertOnConflictUpdate(PaymentRecord.fromJson(json).toCompanion(false)),
  ),
  'business_settings': SyncTableAdapter(
    tableName: 'business_settings',
    isAppendOnly: false,
    pendingRowsJson: (db, deviceId, sinceRev) => _pending(
      db.select(db.businessSettings)..where((t) => t.createdByDeviceId.equals(deviceId) & t.localRev.isBiggerThanValue(sinceRev)),
      (row) => row.toJson(),
    ),
    findLocalMeta: (db, id) async {
      final row = await (db.select(db.businessSettings)..where((t) => t.id.equals(id))).getSingleOrNull();
      return row == null ? null : (updatedAt: row.updatedAt, deviceId: row.createdByDeviceId);
    },
    applyPayload: (db, json) =>
        db.into(db.businessSettings).insertOnConflictUpdate(BusinessSetting.fromJson(json).toCompanion(false)),
  ),
};
