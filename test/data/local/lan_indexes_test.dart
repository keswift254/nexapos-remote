import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/data/sync/sync_table_registry.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<Set<String>> indexesOf(String table) async {
    final rows = await db.customSelect('PRAGMA index_list("$table")').get();
    return rows.map((r) => r.data['name'] as String).toSet();
  }

  test('every table the LAN sync reads has an index on (source device, revision)', () async {
    for (final table in syncTableAdapters.keys) {
      expect(await indexesOf(table), contains('idx_${table}_source_rev'), reason: table);
    }
  });

  test('the index covers exactly the two columns the LAN queries use, in that order', () async {
    final columns = await db.customSelect('PRAGMA index_info("idx_sales_source_rev")').get();
    expect(columns.map((c) => c.data['name']), ['created_by_device_id', 'local_rev']);
  });

  test('"newest revision per device" is answered from the index alone, not by reading the table', () async {
    final plan = await db
        .customSelect(
          'EXPLAIN QUERY PLAN SELECT created_by_device_id AS device_id, MAX(local_rev) AS revision '
          'FROM "sale_items" GROUP BY created_by_device_id',
        )
        .get();
    final text = plan.map((r) => r.data['detail']).join(' | ');
    expect(text, contains('COVERING INDEX'), reason: text);
    expect(text, contains('idx_sale_items_source_rev'), reason: text);
  });

  test('"what came after revision N from device X" uses the index too', () async {
    final plan = await db
        .customSelect(
          'EXPLAIN QUERY PLAN SELECT * FROM "stock_movements" WHERE created_by_device_id = ? AND local_rev > ?',
          variables: [Variable('dev-a'), Variable(10)],
        )
        .get();
    final text = plan.map((r) => r.data['detail']).join(' | ');
    expect(text, contains('idx_stock_movements_source_rev'), reason: text);
  });

  test('tables that are not synced get no such index', () async {
    expect(await indexesOf('device_meta'), isNot(contains('idx_device_meta_source_rev')));
  });

  test('opening the same database again is harmless (the statements are idempotent)', () async {
    // beforeOpen runs on every open; running its index step again must not fail.
    for (final table in syncTableAdapters.keys) {
      await db.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_${table}_source_rev ON "$table"(created_by_device_id, local_rev)',
      );
    }
    expect(await indexesOf('sales'), contains('idx_sales_source_rev'));
  });
}
