import 'package:drift/drift.dart';

/// Single-row table holding this device's own identity and sync
/// bookkeeping. Deliberately does NOT use [SyncedColumns] - it would be
/// circular for the table that produces [nextLocalRev] values to itself
/// carry a localRev column, and this is inherently local-only device
/// identity, never itself a row that gets synced to another device.
///
/// [deviceId] is generated once on first launch and persisted -
/// attribution metadata written into every other table's
/// createdByDeviceId column, never regenerated.
/// [nextLocalRev] is the monotonic counter every insert/update reads,
/// increments, and stamps onto its own row's localRev, in the same
/// transaction. This is what Phase 2's "give me everything since rev X"
/// sync cursor will use - immune to phone clock drift, unlike
/// updatedAt (which stays purely for human display and conflict-
/// resolution tie-breaks).
class DeviceMeta extends Table {
  TextColumn get id => text()();
  TextColumn get deviceId => text()();
  TextColumn get deviceLabel => text()();

  /// Generated once, alongside deviceId, and sent to nexapos_platform's
  /// register_device on every attempt (first and any retry) - proves
  /// this retry is genuinely the same caller as the original
  /// registration, since deviceId alone isn't secret (see
  /// nexapos_platform's clients.registration_secret_hash schema
  /// comment for the full story). Empty string, not null, for installs
  /// that predate this column - functionally equivalent, since any
  /// device that old is long past its 10-minute registration grace
  /// window anyway and will never need this again regardless.
  TextColumn get registrationSecret => text().withDefault(const Constant(''))();

  IntColumn get nextLocalRev => integer().withDefault(const Constant(1))();

  /// The highest local_rev this device has successfully pushed to
  /// nexapos_platform - a single value, not one per table, since
  /// [nextLocalRev] is already one counter shared across every table.
  IntColumn get lastPushedLocalRev => integer().withDefault(const Constant(0))();

  /// The highest sync_changes.id this device has successfully pulled
  /// and applied - a server-assigned cursor, unrelated to local_rev.
  IntColumn get lastPulledChangeId => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
