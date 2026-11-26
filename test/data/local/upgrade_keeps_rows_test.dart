import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/domain/entities/expense.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

import '../../support/fake_shop_cloud.dart';
import '../../support/shop_harness.dart' show HarnessClock;
import '../../support/sync_device.dart';

/// An app update must never change a shop's records: not what they say, not when they were changed, not their change
/// number or device. A device's changes are matched against the copies the shop server already holds and that other
/// devices hold, so an update that rewrote rows (a backfill, a cleanup, a trigger firing during an upgrade) would make
/// every device that installs it disagree with the server - the "already recorded with different content" that once
/// stopped a shop PC's uploads for 27 days. A new upgrade step that touches existing rows fails here.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const syncedTables = [
    'roles',
    'users',
    'categories',
    'products',
    'sales',
    'sale_items',
    'expenses',
    'stock_movements',
    'payment_records',
    'business_settings',
  ];

  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nexapos_upgrade_rows');
    file = File('${dir.path}${Platform.pathSeparator}shop.db');
    final clock = HarnessClock(DateTime.now().toUtc().subtract(const Duration(days: 30)));
    final device = await SyncDevice.create('PC', FakeShopCloud(), clock, open: () => NativeDatabase(file));
    await device.openShop();
    final drinks = await device.addCategory('Drinks');
    final soda = await device.addProduct('Soda', drinks, 6000, 40);
    await device.addProduct('Juice', drinks, 9000, 12);
    clock.value = clock.value.add(const Duration(days: 1));
    await device.sell(soda, 2);
    await device.setPrice(soda, 6500);
    await device.expenses.create(Expense(
      id: '',
      expenseDate: clock.value,
      title: 'Transport',
      amount: const Money(30000),
      createdAt: clock.value,
    ));
    await device.db.close();
  });
  tearDown(() => dir.delete(recursive: true));

  Map<String, List<Map<String, Object?>>> read() {
    final db = raw.sqlite3.open(file.path);
    try {
      return {
        for (final table in syncedTables)
          table: [for (final row in db.select('SELECT * FROM "$table" ORDER BY id')) {...row}],
        'device_meta': [for (final row in db.select('SELECT next_local_rev, device_id FROM device_meta')) {...row}],
      };
    } finally {
      db.close();
    }
  }

  Future<void> open() async {
    final db = await SyncDevice.create('PC', FakeShopCloud(), HarnessClock(DateTime.now().toUtc()),
        open: () => NativeDatabase(file));
    await db.db.customSelect('SELECT 1').get();
    await db.db.close();
  }

  test('every upgrade step, from the first database version on, leaves every record exactly as it was', () async {
    final before = read();
    expect(before['sales'], hasLength(1));
    expect(before['products'], hasLength(2));

    // As a database last opened by the very first version: every upgrade step runs on the next open.
    final db = raw.sqlite3.open(file.path);
    db.execute('PRAGMA user_version = 1');
    db.close();
    await open();

    final after = read();
    for (final table in before.keys) {
      expect(after[table], before[table], reason: 'the update changed $table');
    }
  });

  test('opening the app again (a restart, an update of the same version) leaves every record as it was', () async {
    final before = read();
    await open();
    await open();
    expect(read(), before);
  });
}
