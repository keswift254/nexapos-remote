import 'package:drift/drift.dart';

/// Shared columns for every table that participates in Phase 2 sync.
///
/// [id] is a client-generated UUID (not autoincrement) so two phones can
/// never collide when creating rows offline. [updatedAt] is stamped on
/// every UPDATE with no exceptions (enforced at the repository layer, and
/// backstopped by a trigger - see database.dart). [deletedAt] is a
/// soft-delete tombstone: no DAO in this app exposes a hard delete for a
/// table using this mixin. [localRev] is a monotonic per-device counter
/// (see DeviceMeta.nextLocalRev) used as the Phase 2 sync cursor instead
/// of wall-clock time, which is immune to phone clock drift.
/// [createdByDeviceId] is attribution only, never part of identity.
/// [syncState] is inert in Phase 1; it exists now so Phase 2 doesn't need
/// a schema migration to add it.
mixin SyncedColumns on Table {
  TextColumn get id => text()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get deletedAt => text().nullable()();
  IntColumn get localRev => integer()();
  TextColumn get createdByDeviceId => text()();
  TextColumn get syncState => text().withDefault(const Constant('local_only'))();

  @override
  Set<Column> get primaryKey => {id};
}
