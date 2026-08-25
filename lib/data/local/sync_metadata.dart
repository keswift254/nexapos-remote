import 'package:drift/drift.dart';
import 'database.dart';

/// Shared helper for the sync bookkeeping every [SyncedColumns] table
/// needs on insert/update: the device's own id (attribution) and a
/// freshly incremented local_rev (the Phase 2 sync cursor). Kept in one
/// place so every repository stamps rows identically instead of each
/// reimplementing the device_meta counter dance.
class SyncMetadataService {
  final AppDatabase _db;

  SyncMetadataService(this._db);

  Future<String> deviceId() async {
    final row = await (_db.select(_db.deviceMeta)..limit(1)).getSingle();
    return row.deviceId;
  }

  /// See device_meta_table.dart's doc comment on this column - sent
  /// alongside deviceId on every registerDevice() call.
  Future<String> registrationSecret() async {
    final row = await (_db.select(_db.deviceMeta)..limit(1)).getSingle();
    return row.registrationSecret;
  }

  /// Atomically reads-increments-returns device_meta.next_local_rev.
  /// Callers must run this inside the same transaction as the row
  /// write it stamps, so two writes on this device can never collide
  /// on the same rev.
  Future<int> nextLocalRev() async {
    final row = await (_db.select(_db.deviceMeta)..limit(1)).getSingle();
    final rev = row.nextLocalRev;
    await (_db.update(_db.deviceMeta)..where((t) => t.id.equals(row.id)))
        .write(DeviceMetaCompanion(nextLocalRev: Value(rev + 1)));
    return rev;
  }

  Future<int> lastPushedLocalRev() async {
    final row = await (_db.select(_db.deviceMeta)..limit(1)).getSingle();
    return row.lastPushedLocalRev;
  }

  Future<void> setLastPushedLocalRev(int rev) async {
    final row = await (_db.select(_db.deviceMeta)..limit(1)).getSingle();
    await (_db.update(_db.deviceMeta)..where((t) => t.id.equals(row.id)))
        .write(DeviceMetaCompanion(lastPushedLocalRev: Value(rev)));
  }

  Future<int> lastPulledChangeId() async {
    final row = await (_db.select(_db.deviceMeta)..limit(1)).getSingle();
    return row.lastPulledChangeId;
  }

  Future<void> setLastPulledChangeId(int id) async {
    final row = await (_db.select(_db.deviceMeta)..limit(1)).getSingle();
    await (_db.update(_db.deviceMeta)..where((t) => t.id.equals(row.id)))
        .write(DeviceMetaCompanion(lastPulledChangeId: Value(id)));
  }

  /// A cursor is only meaningful against the shop it accumulated
  /// against - called after a successful joinShop, since this device's
  /// prior push/pull history (if any, as a lone shop founder) belongs
  /// to a shop it's no longer part of.
  Future<void> resetCursors() async {
    final row = await (_db.select(_db.deviceMeta)..limit(1)).getSingle();
    await (_db.update(_db.deviceMeta)..where((t) => t.id.equals(row.id))).write(
      const DeviceMetaCompanion(lastPushedLocalRev: Value(0), lastPulledChangeId: Value(0)),
    );
  }
}
