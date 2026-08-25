import 'package:drift/drift.dart';
import 'synced_columns.dart';

/// Seeded once with fixed, hardcoded UUID constants (see [RoleIds]) so
/// role rows line up by id across every phone and the PC once Phase 2
/// sync exists - name-matching strings across devices would be exactly
/// the kind of fragile reconciliation this schema is trying to avoid.
class Roles extends Table with SyncedColumns {
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
}

abstract final class RoleIds {
  static const admin = '00000000-0000-4000-8000-000000000001';
  static const manager = '00000000-0000-4000-8000-000000000002';
  static const cashier = '00000000-0000-4000-8000-000000000003';
}
