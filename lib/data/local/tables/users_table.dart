import 'package:drift/drift.dart';
import 'synced_columns.dart';
import 'roles_table.dart';

/// Status values: 'active', 'disabled' (mirrors PHP's users.status enum).
///
/// Deliberately no default admin is seeded here, unlike PHP's install SQL
/// which ships a known admin@pos.local/admin123 row. Shipping a known
/// credential in a distributable APK is a materially different risk than
/// in a LAN-only XAMPP install someone else provisions - first launch
/// with zero local users forces a setup wizard to create the real admin.
class Users extends Table with SyncedColumns {
  TextColumn get roleId => text().references(Roles, #id)();
  TextColumn get name => text()();
  TextColumn get username => text()();
  TextColumn get email => text().nullable()();
  TextColumn get passwordHash => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
}
