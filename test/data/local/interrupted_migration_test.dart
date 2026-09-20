import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

/// Reproduces the real web failure: "duplicate column name: barcode" on
/// ALTER TABLE products ADD COLUMN barcode. An upgrade interrupted after
/// the column was added but before the schema version was recorded leaves
/// the column present while the stored version is still old, so every
/// later open re-ran the same ALTER and failed for good.
void main() {
  test('re-opening after an interrupted upgrade finishes it instead of failing', () async {
    final dir = await Directory.systemTemp.createTemp('nexapos_migration_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}app.db');

    // A fresh database is created at the current schema, so it already
    // has products.barcode.
    final first = AppDatabase(NativeDatabase(file));
    await first.customSelect('SELECT 1').get();
    await first.close();

    // Rewind only the recorded version - exactly the state an interrupted
    // upgrade leaves behind (column added, version never bumped).
    final handle = raw.sqlite3.open(file.path);
    handle.execute('PRAGMA user_version = 4');
    handle.close();

    final second = AppDatabase(NativeDatabase(file));
    addTearDown(second.close);
    // Opening runs onUpgrade(4 -> 5); it used to throw here.
    final columns = await second
        .customSelect('PRAGMA table_info("products")')
        .get();
    expect(columns.map((r) => r.read<String>('name')), contains('barcode'));

    final version = await second.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 5);
  });

  test('an old database that genuinely lacks the column still gets it added', () async {
    final dir = await Directory.systemTemp.createTemp('nexapos_migration_test2');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}app.db');

    final first = AppDatabase(NativeDatabase(file));
    await first.customSelect('SELECT 1').get();
    await first.close();

    // Simulate a real version-4 database: drop the column and rewind.
    final handle = raw.sqlite3.open(file.path);
    handle.execute('ALTER TABLE products DROP COLUMN barcode');
    handle.execute('PRAGMA user_version = 4');
    handle.close();

    final second = AppDatabase(NativeDatabase(file));
    addTearDown(second.close);
    final columns = await second
        .customSelect('PRAGMA table_info("products")')
        .get();
    expect(columns.map((r) => r.read<String>('name')), contains('barcode'));
  });
}
