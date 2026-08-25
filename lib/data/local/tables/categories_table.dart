import 'package:drift/drift.dart';
import 'synced_columns.dart';

/// Status values: 'active', 'disabled' (mirrors PHP's categories.status).
class Categories extends Table with SyncedColumns {
  TextColumn get name => text()();
  TextColumn get status => text().withDefault(const Constant('active'))();
}
