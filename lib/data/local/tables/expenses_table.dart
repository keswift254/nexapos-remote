import 'package:drift/drift.dart';
import 'synced_columns.dart';
import 'users_table.dart';

/// Soft-delete replaces PHP's hard `DELETE FROM expenses`.
class Expenses extends Table with SyncedColumns {
  TextColumn get userId => text().nullable().references(Users, #id)();
  TextColumn get expenseDate => text()();
  TextColumn get title => text()();
  IntColumn get amountCents => integer()();
  TextColumn get note => text().nullable()();
}
