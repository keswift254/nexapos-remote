import 'package:drift/drift.dart';
import 'synced_columns.dart';

/// Single-row table. PHP's equivalent (config/config.php's 'receipt'
/// section: business_name, address, phone, footer, paper_width_mm,
/// currency) is file-based - a phone has no config file to hand-edit, so
/// this must be DB-backed and editable from a Settings screen from day
/// one. Uses the full sync mixin (unlike DeviceMeta) because business
/// settings are genuinely synchronizable data: if the PHP side ever
/// moves its own config into a DB table (a noted Phase 2 possibility),
/// this becomes its natural sync counterpart.
class BusinessSettings extends Table with SyncedColumns {
  TextColumn get businessName => text()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get receiptFooter => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('KES'))();
  IntColumn get paperWidthMm => integer().withDefault(const Constant(58))();
}
