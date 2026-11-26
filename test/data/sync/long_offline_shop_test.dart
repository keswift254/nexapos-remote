import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/domain/entities/expense.dart';

import '../../support/fake_shop_cloud.dart';
import '../../support/shop_harness.dart' show HarnessClock;
import '../../support/sync_device.dart';

/// A shop that is offline for a long time must sync completely, all at once, when it is back online - also after the
/// app was updated in between. This is the whole shop through the app's real sync, against a server that behaves like
/// the real one (test/support/fake_shop_cloud.dart):
///  - A, the shop PC: offline for two months, sells and changes prices; its app is updated half-way;
///  - B, a till that only ever reaches the shop over the LAN (no internet of its own): sells, changes a price of A's,
///    removes an expense of A's; for the last ten days even the LAN is down;
///  - C, the owner's phone, online all along, away from the shop: changes a price later than A did;
///  - the server's daily clean-up runs while they are away.
/// When A is online again, every change of A and B reaches the server once, and A, B and C end up with exactly the
/// same shop - the newest change of every item winning wherever it was made.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const syncedTables = [
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

  /// What every device must agree on (sync_state is each device's own bookkeeping).
  Future<Map<String, Object?>> shopOf(SyncDevice device) async => {
        for (final table in syncedTables)
          table: {
            for (final entry in (await device.rows(table)).entries)
              entry.key: {...entry.value}..remove('sync_state'),
          },
      };

  test('two months offline (one till only on the LAN, an app update, the server cleaned up) - then one sync, '
      'and every device holds the same shop', () async {
    final dir = await Directory.systemTemp.createTemp('nexapos_long_offline');
    addTearDown(() => dir.delete(recursive: true));
    final pcFile = File('${dir.path}${Platform.pathSeparator}pc.db');

    final start = DateTime.now().toUtc().subtract(const Duration(days: 70));
    final shopClock = HarnessClock(start);
    final phoneClock = HarnessClock(start);
    // The whole two months lie in the past, so the server's "more than a day in the future" check (on its real clock)
    // never comes into it: a database stamps its first rows with the real time, as any device does.
    final cloud = FakeShopCloud();

    var a = await SyncDevice.create('A', cloud, shopClock, open: () => NativeDatabase(pcFile));
    final b = await SyncDevice.create('B', cloud, shopClock);
    final c = await SyncDevice.create('C', cloud, phoneClock);
    addTearDown(() async {
      await a.db.close();
      await b.db.close();
      await c.db.close();
    });

    // Day 0, online: A opens the shop, B and C join.
    await a.openShop();
    final drinks = await a.addCategory('Drinks');
    final items = <String>[
      for (var i = 0; i < 5; i++) await a.addProduct('Item $i', drinks, 1000 * (i + 1), 500),
    ];
    final rent = await a.expenses.create(Expense(
      id: '',
      expenseDate: shopClock.value,
      title: 'Rent',
      amount: const Money(1500000),
      createdAt: shopClock.value,
    ));
    await a.syncWithCloud();
    await b.join();
    await c.join();

    // Day 1: the shop's internet goes. B never had any of its own.
    a.hasInternet = false;
    b.hasInternet = false;
    String? lateItem;
    for (var day = 1; day <= 60; day++) {
      shopClock.value = start.add(Duration(days: day, hours: 9));
      phoneClock.value = shopClock.value;
      for (var n = 0; n < 3; n++) {
        await a.sell(items[(day + n) % items.length], 1);
      }
      if (day <= 50) {
        for (var n = 0; n < 2; n++) {
          await b.sell(items[(day * 3 + n) % items.length], 2);
        }
      }
      if (day == 10) await b.setPrice(items[1], 2222); // B changes A's item
      if (day == 20) await a.setPrice(items[0], 1111);
      if (day == 25) {
        await c.setPrice(items[0], 1999); // later than A's change: C's must win everywhere
        await c.syncWithCloud();
      }
      if (day == 30) lateItem = await a.addProduct('Late item', drinks, 4200, 50);
      if (day == 33 && lateItem != null) {
        await b.takeOverLan(a);
        await b.sell(lateItem, 1);
      }
      if (day == 40) expect(await b.expenses.delete(rent), isTrue); // B removes A's expense
      if (day == 45) a = await a.restart(); // the PC's app is updated
      // The LAN works until day 50; the tills swap changes every few days.
      if (day <= 50 && day % 3 == 0) {
        await a.takeOverLan(b);
        await b.takeOverLan(a);
      }
      if (day % 7 == 0) cloud.compact(); // the server's daily clean-up, while they are away
    }
    expect(cloud.compact(), greaterThanOrEqualTo(0));

    // Day 61: A is online again. One routine sync.
    shopClock.value = start.add(const Duration(days: 61, hours: 9));
    phoneClock.value = shopClock.value;
    a.hasInternet = true;
    final waitingOnA = await a.waiting();
    expect(waitingOnA, greaterThan(500), reason: 'two months of the PC\'s sales were waiting');
    await a.syncWithCloud();

    expect(await a.waiting(), 0, reason: 'nothing of A left to upload after ONE sync');
    expect(await a.sync.quarantinedCount(), 0, reason: 'nothing set aside');
    final relayLeft = await a.db.customSelect('SELECT COUNT(*) AS n FROM local_lan_relay_outbox').getSingle();
    expect(relayLeft.read<int>('n'), 0, reason: 'everything of B that A held went up too');

    // The LAN is back: B's last ten days reach A, A passes them on; B gets the shop's newest.
    await a.takeOverLan(b);
    await a.syncWithCloud();
    await b.takeOverLan(a);
    await c.syncWithCloud();

    // Every change of B reached the server exactly once - B never had internet.
    for (final table in syncedTables) {
      final own = (await b.rows(table)).values.where((r) => r['created_by_device_id'] == b.id);
      for (final row in own) {
        expect(
          cloud.changes.where((ch) =>
              ch['device_id'] == b.id && ch['table_name'] == table && ch['row_id'] == row['id'] && ch['local_rev'] == row['local_rev']),
          hasLength(1),
          reason: 'B\'s $table ${row['id']} (revision ${row['local_rev']}) is on the server once',
        );
      }
    }

    // One shop on every device.
    final shopA = await shopOf(a);
    final shopB = await shopOf(b);
    final shopC = await shopOf(c);
    for (final table in syncedTables) {
      expect(jsonEncode(shopB[table]), jsonEncode(shopA[table]), reason: 'B and A agree on $table');
      expect(jsonEncode(shopC[table]), jsonEncode(shopA[table]), reason: 'C and A agree on $table');
    }

    // The newest change of every item won, wherever it was made.
    final products = shopA['products']! as Map<String, Object?>;
    int price(String id) => (products[id]! as Map)['retail_price_cents'] as int;
    expect(price(items[0]), 1999, reason: 'C changed it after A did');
    expect(price(items[1]), 2222, reason: 'B\'s change, made on a till without internet');
    expect(((shopA['expenses']! as Map)[rent]! as Map)['deleted_at'], isNotNull, reason: 'B removed it');

    // Stock adds up from every device's sales.
    for (final id in [...items, lateItem!]) {
      final movements = (shopA['stock_movements']! as Map).values.cast<Map>().where((m) => m['product_id'] == id);
      final sum = movements.fold<int>(0, (total, m) => total + (m['quantity'] as int));
      expect((products[id]! as Map)['stock_qty'], sum, reason: 'stock of $id is every movement added up');
    }
    final sales = (shopA['sales']! as Map).values.cast<Map>();
    expect(sales.where((s) => s['created_by_device_id'] == b.id), hasLength(100 + 1));
    expect(sales.where((s) => s['created_by_device_id'] == a.id), hasLength(180));
  });

  test('a page of changes with a row whose parent this device does not hold does not stop every later download',
      () async {
    final clock = HarnessClock(DateTime.now().toUtc().subtract(const Duration(days: 2)));
    final cloud = FakeShopCloud();
    final a = await SyncDevice.create('A', cloud, clock);
    final b = await SyncDevice.create('B', cloud, clock);
    addTearDown(() async {
      await a.db.close();
      await b.db.close();
    });
    await a.openShop();
    final item = await a.addProduct('Soda', await a.addCategory('Drinks'), 6000, 10);
    await a.syncWithCloud();
    await b.join();
    final sale = await a.sell(item, 1);
    await a.syncWithCloud();
    // The sale itself never reached the server (refused there), its lines did.
    cloud.changes.removeWhere((ch) => ch['table_name'] == 'sales' && ch['row_id'] == sale.id);
    clock.value = clock.value.add(const Duration(minutes: 5));
    await a.setPrice(item, 6500);
    await a.syncWithCloud();

    await b.syncWithCloud();
    await b.syncWithCloud();

    expect((await b.rows('products'))[item]!['retail_price_cents'], 6500, reason: 'later changes still arrive');
    expect((await b.rows('sale_items')).values.where((line) => line['sale_id'] == sale.id), hasLength(1),
        reason: 'the line is kept; it links up if its sale ever arrives');
  });

  test('a relayed change the server refuses costs only that change, not every change of its till', () async {
    final clock = HarnessClock(DateTime.now().toUtc().subtract(const Duration(hours: 1)));
    final cloud = FakeShopCloud();
    final a = await SyncDevice.create('A', cloud, clock);
    final b = await SyncDevice.create('B', cloud, clock);
    addTearDown(() async {
      await a.db.close();
      await b.db.close();
    });
    await a.openShop();
    final item = await a.addProduct('Soda', await a.addCategory('Drinks'), 6000, 100);
    await a.syncWithCloud();
    await b.join();
    b.hasInternet = false;
    final before = await b.sell(item, 1);
    // B's clock jumps three days ahead for one sale (a wrong date set by hand), then is put right.
    final rightTime = clock.value;
    clock.value = rightTime.add(const Duration(days: 3));
    final ahead = await b.sell(item, 1);
    clock.value = rightTime.add(const Duration(minutes: 1));
    final after = await b.sell(item, 1);

    await a.takeOverLan(b);
    await a.syncWithCloud();

    bool onServer(String saleId) => cloud.changes.any((ch) => ch['table_name'] == 'sales' && ch['row_id'] == saleId);
    expect(onServer(before.id), isTrue);
    expect(onServer(after.id), isTrue, reason: 'B\'s later sales still went up');
    expect(onServer(ahead.id), isFalse, reason: 'the server refuses a change dated days ahead');
    final relayLeft = await a.db.customSelect('SELECT COUNT(*) AS n FROM local_lan_relay_outbox').getSingle();
    expect(relayLeft.read<int>('n'), 0, reason: 'nothing stays queued to be refused again and again');
  });
}
