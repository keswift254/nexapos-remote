import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'database_encryption.dart';

import 'tables/roles_table.dart';
import 'tables/users_table.dart';
import 'tables/categories_table.dart';
import 'tables/products_table.dart';
import 'tables/sales_table.dart';
import 'tables/sale_items_table.dart';
import 'tables/expenses_table.dart';
import 'tables/stock_movements_table.dart';
import 'tables/payment_records_table.dart';
import 'tables/business_settings_table.dart';
import 'tables/device_meta_table.dart';
import 'daos/users_dao.dart';
import 'daos/categories_dao.dart';
import 'daos/products_dao.dart';
import 'daos/stock_movements_dao.dart';
import 'daos/sales_dao.dart';
import 'daos/sale_items_dao.dart';
import 'daos/payment_records_dao.dart';
import 'daos/business_settings_dao.dart';
import 'daos/reports_dao.dart';
import 'daos/expenses_dao.dart';
import 'sync_metadata.dart';

part 'database.g.dart';

/// Tables that use [SyncedColumns] (i.e. everything except [DeviceMeta]).
/// Used to generate the updatedAt backstop triggers below - this list
/// must be kept in sync with the `tables:` list on [AppDatabase] minus
/// DeviceMeta.
const _syncedTableNames = [
  'roles',
  'users',
  'categories',
  'products',
  'sales',
  'sale_items',
  'expenses',
  'stock_movements',
  'payment_records',
  'business_settings',
];

@DriftDatabase(
  tables: [
    Roles,
    Users,
    Categories,
    Products,
    Sales,
    SaleItems,
    Expenses,
    StockMovements,
    PaymentRecords,
    BusinessSettings,
    DeviceMeta,
  ],
  daos: [
    UsersDao,
    CategoriesDao,
    ProductsDao,
    StockMovementsDao,
    SalesDao,
    SaleItemsDao,
    PaymentRecordsDao,
    BusinessSettingsDao,
    ReportsDao,
    ExpensesDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Same 'nexapos.sqlite' file/location driftDatabase() has always
  /// used (getApplicationDocumentsDirectory() + '$name.sqlite') - real
  /// devices already have a file there, so this can't switch to a
  /// different name/path without every existing install looking like
  /// it lost its data. Wrapped in the same DatabaseConnection.delayed
  /// pattern driftDatabase() itself uses internally, so resolving the
  /// encryption key and (if needed) migrating an existing plain file
  /// happen before the connection driftDatabase() hands back is ever
  /// touched - by the time any query runs, the file on disk and the
  /// PRAGMA key driftDatabase's own `native.setup` applies are already
  /// guaranteed to match.
  AppDatabase.defaults()
      : super(
          DatabaseConnection.delayed(
            Future(() async {
              const storage = FlutterSecureStorage();
              final key = await getOrCreateEncryptionKey(storage);
              final dir = await getApplicationDocumentsDirectory();
              final dbFile = File(p.join(dir.path, 'nexapos.sqlite'));
              await migrateToEncryptedIfNeeded(dbFile, key);

              return driftDatabase(
                name: 'nexapos',
                native: DriftNativeOptions(
                  setup: (db) => db.execute("PRAGMA key = '$key';"),
                ),
              );
            }),
          ),
        );

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createUpdatedAtTriggers();
          // Device id must exist before anything else, since roles and
          // business_settings stamp createdByDeviceId from it.
          await _seedDeviceMeta();
          await _seedRoles();
          await _seedDefaultBusinessSettings();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Sync cursors (Phase 2) - both default to 0, meaning "never
            // pushed/pulled anything yet", correct for an existing
            // installation that predates sync exactly as much as for a
            // brand-new one.
            await m.addColumn(deviceMeta, deviceMeta.lastPushedLocalRev);
            await m.addColumn(deviceMeta, deviceMeta.lastPulledChangeId);
          }
          if (from < 3) {
            // Left as the column default (empty string), not backfilled -
            // see registrationSecret's own doc comment for why that's
            // correct for an existing installation.
            await m.addColumn(deviceMeta, deviceMeta.registrationSecret);
          }
        },
        beforeOpen: (details) async {
          // WAL mode so report/list screens can keep reading while a
          // checkout transaction commits.
          await customStatement('PRAGMA journal_mode=WAL');
          await customStatement('PRAGMA foreign_keys=ON');
        },
      );

  /// Belt-and-suspenders backstop: every repository method that issues an
  /// UPDATE is required to pass updatedAt explicitly (the real
  /// enforcement point), but if one ever forgets, this trigger stamps it
  /// anyway rather than silently leaving a stale value.
  ///
  /// Padded to 6-digit (microsecond-shaped) fractional seconds, matching
  /// Dart's DateTime.toIso8601String() exactly - SQLite's strftime('%f')
  /// only ever gives 3 digits, and two differently-padded ISO8601
  /// strings can sort incorrectly against each other as plain text
  /// (".123Z" > ".123456Z" lexicographically, backwards from the actual
  /// time order). Dormant today since no call site relies on this
  /// trigger firing, but sync makes updated_at string comparison
  /// cross-device-correctness-load-bearing rather than just a display
  /// value, so it's worth being exactly right now.
  Future<void> _createUpdatedAtTriggers() async {
    for (final table in _syncedTableNames) {
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS trg_${table}_updated_at
        AFTER UPDATE ON $table
        WHEN NEW.updated_at = OLD.updated_at
        BEGIN
          UPDATE $table
          SET updated_at = strftime('%Y-%m-%dT%H:%M:%f', 'now') || '000Z'
          WHERE id = NEW.id;
        END;
      ''');
    }
  }

  /// Fixed, hardcoded UUID constants (see [RoleIds]) so role rows line
  /// up by id across every phone and the PC once Phase 2 sync exists.
  ///
  /// Each seed row consumes a real, distinct local_rev via
  /// SyncMetadataService rather than a hardcoded value - a rev shared
  /// across rows would let a later, genuinely different write land on
  /// the exact same rev as a seed row, and a rev-cursor sync can't tell
  /// those two writes apart once that happens.
  Future<void> _seedRoles() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final deviceId = await _currentDeviceId();
    final syncMeta = SyncMetadataService(this);
    final seedRoles = [
      (RoleIds.admin, 'admin', 'Full access'),
      (RoleIds.manager, 'manager', 'Inventory, reports, sales'),
      (RoleIds.cashier, 'cashier', 'Sales terminal only'),
    ];
    for (final (id, name, description) in seedRoles) {
      final rev = await syncMeta.nextLocalRev();
      await into(roles).insert(
        RolesCompanion.insert(
          id: id,
          name: name,
          description: Value(description),
          createdAt: now,
          updatedAt: now,
          localRev: rev,
          createdByDeviceId: deviceId,
        ),
      );
    }
  }

  /// Reads the device id written by [_seedDeviceMeta], which must run
  /// before this is called. Falls back to a throwaway id only as a
  /// defensive guard against call-order mistakes, not a real code path.
  Future<String> _currentDeviceId() async {
    const uuid = Uuid();
    final existing = await (select(deviceMeta)..limit(1)).getSingleOrNull();
    return existing?.deviceId ?? uuid.v4();
  }

  Future<void> _seedDeviceMeta() async {
    const uuid = Uuid();
    final existing = await (select(deviceMeta)..limit(1)).getSingleOrNull();
    if (existing != null) return;
    await into(deviceMeta).insert(
      DeviceMetaCompanion.insert(
        id: 'device',
        deviceId: uuid.v4(),
        deviceLabel: 'This device',
        // v4 again purely because it's already the UUID generator in
        // scope here, not because this needs to look like a device id -
        // any sufficiently random string would do, this just reuses
        // what's already imported. See registrationSecret's doc comment.
        registrationSecret: Value(uuid.v4()),
      ),
    );
  }

  Future<void> _seedDefaultBusinessSettings() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final deviceId = await _currentDeviceId();
    final existing = await (select(businessSettings)..limit(1)).getSingleOrNull();
    if (existing != null) return;
    final rev = await SyncMetadataService(this).nextLocalRev();
    await into(businessSettings).insert(
      BusinessSettingsCompanion.insert(
        id: 'settings',
        businessName: 'My Business',
        createdAt: now,
        updatedAt: now,
        localRev: rev,
        createdByDeviceId: deviceId,
      ),
    );
  }
}
