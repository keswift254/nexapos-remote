import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' show editsBeforeRevisionOwnersSentFlag;
import 'package:nexapos_mobile/domain/entities/expense.dart';

import '../../support/fake_shop_cloud.dart';
import '../../support/shop_harness.dart' show HarnessClock;
import '../../support/sync_device.dart';

/// A change one device makes to a row another device made - a price changed on the PC for an item added on a phone, a
/// password changed on a phone, an expense removed - must reach the shop like any other change. Until 1.0.96 the row
/// kept the other device's name with this device's change number: the upload (which sends this device's own revisions)
/// never sent it and the dashboard never counted it as waiting; over the LAN it travelled as the other device's revision
/// under a number that device may have used for something else.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late FakeShopCloud cloud;
  late HarnessClock clock;
  late SyncDevice a;
  late SyncDevice b;
  late String sodaId;

  setUp(() async {
    clock = HarnessClock(DateTime.now().toUtc().subtract(const Duration(days: 3)));
    cloud = FakeShopCloud();
    a = await SyncDevice.create('A', cloud, clock);
    b = await SyncDevice.create('B', cloud, clock);
    await a.openShop();
    sodaId = await a.addProduct('Soda', await a.addCategory('Drinks'), 6000, 10);
    await a.syncWithCloud();
    await b.join();
  });
  tearDown(() async {
    await a.db.close();
    await b.db.close();
  });

  Future<Map<String, Object?>> rowOf(SyncDevice device, String table, String id) async => (await device.rows(table))[id]!;

  test('a price changed on B for an item made on A counts as waiting on B, goes up, and reaches A', () async {
    clock.value = clock.value.add(const Duration(hours: 1));
    await b.setPrice(sodaId, 7000);

    final onB = await rowOf(b, 'products', sodaId);
    expect(onB['created_by_device_id'], b.id, reason: 'the change is B\'s revision: B numbered it');
    expect(await b.waiting(), 1, reason: 'the dashboard counts it as waiting to upload');

    await b.syncWithCloud();
    expect(await b.waiting(), 0);
    expect(cloud.latest('products', sodaId)?['retailPriceCents'], 7000, reason: 'the shop server has the new price');

    await a.syncWithCloud();
    final onA = await rowOf(a, 'products', sodaId);
    expect(onA['retail_price_cents'], 7000, reason: 'A has the new price');
    expect(onA['created_by_device_id'], b.id, reason: 'on A it stays B\'s change');
    expect(await a.waiting(), 0, reason: 'B\'s change is not A\'s to upload again');
  });

  test('the change keeps the time it was made: becoming B\'s revision is not another edit', () async {
    clock.value = clock.value.add(const Duration(hours: 1));
    await b.setPrice(sodaId, 7000);
    expect((await rowOf(b, 'products', sodaId))['updated_at'], clock.value.toIso8601String());
  });

  test('a row that comes down from the server keeps the device that sent it', () async {
    final onB = await rowOf(b, 'products', sodaId);
    final onA = await rowOf(a, 'products', sodaId);
    expect(onB['created_by_device_id'], a.id);
    expect(onB['local_rev'], onA['local_rev'], reason: 'A\'s change number, as A sent it');
    expect(await b.waiting(), 0, reason: 'nothing of A\'s is B\'s to upload');
  });

  test('a row that comes over the LAN keeps the device that sent it', () async {
    final c = await SyncDevice.create('C', cloud, clock);
    addTearDown(c.db.close);
    await c.join();
    clock.value = clock.value.add(const Duration(hours: 1));
    await b.setPrice(sodaId, 7500);

    await c.takeOverLan(b);

    final onC = await rowOf(c, 'products', sodaId);
    expect(onC['retail_price_cents'], 7500);
    expect(onC['created_by_device_id'], b.id);
    expect(onC['local_rev'], (await rowOf(b, 'products', sodaId))['local_rev']);
    expect(await c.waiting(), 0, reason: 'C only passes it on (relays it); it is not C\'s own change');
  });

  test('a change over the LAN travels as the device that made it, not as the item\'s first device', () async {
    clock.value = clock.value.add(const Duration(hours: 1));
    await b.setPrice(sodaId, 7000);
    a.hasInternet = false;

    await a.takeOverLan(b);
    expect((await rowOf(a, 'products', sodaId))['retail_price_cents'], 7000);
    expect(await a.waiting(), 0, reason: 'B\'s change is not A\'s to upload as its own');
    final cursors = await a.sync.lanRevisionCursors();
    expect(cursors[a.id], lessThan(await a.meta.nextLocalRev()),
        reason: 'B\'s number did not end up counted as one of A\'s (A would then skip its own real change of that number)');

    a.hasInternet = true;
    await a.syncWithCloud();
    expect(cloud.latest('products', sodaId)?['retailPriceCents'], 7000, reason: 'A passed B\'s change on to the server');
    expect(cloud.pushedBy[a.id]!.expand((batch) => batch).any((c) => c['source_device_id'] == b.id), isTrue);
  });

  test('a removed expense of another device goes up as removed', () async {
    final expenseId = await a.expenses.create(Expense(
      id: '',
      expenseDate: clock.value,
      title: 'Transport',
      amount: const Money(50000),
      createdAt: clock.value,
    ));
    await a.syncWithCloud();
    await b.syncWithCloud();
    clock.value = clock.value.add(const Duration(hours: 1));

    expect(await b.expenses.delete(expenseId), isTrue);
    await b.syncWithCloud();
    await a.syncWithCloud();

    expect((await rowOf(a, 'expenses', expenseId))['deleted_at'], isNotNull);
  });

  group('changes made before 1.0.96 (still only on the device that made them)', () {
    /// What 1.0.95 left behind: B changed A's item, but the row kept A's name with B's number.
    Future<void> leaveAnEditUnderTheOtherDevicesName() async {
      clock.value = clock.value.add(const Duration(hours: 1));
      await b.setPrice(sodaId, 7000);
      await b.db.customStatement(
        'UPDATE products SET created_by_device_id = ? WHERE id = ?',
        [a.id, sodaId],
      );
      await b.db.customStatement("DELETE FROM local_safety_state WHERE id='$editsBeforeRevisionOwnersSentFlag'");
      expect(await b.waiting(), 0, reason: 'the 1.0.95 state: not even counted as waiting');
    }

    test('go up once after the update, with what they say and their time kept', () async {
      await leaveAnEditUnderTheOtherDevicesName();
      final before = await rowOf(b, 'products', sodaId);

      await b.syncWithCloud();

      final after = await rowOf(b, 'products', sodaId);
      expect(after['created_by_device_id'], b.id);
      expect(after['updated_at'], before['updated_at'], reason: 'the change keeps its own time');
      expect(after['retail_price_cents'], 7000);
      expect(cloud.latest('products', sodaId)?['retailPriceCents'], 7000);
      await a.syncWithCloud();
      expect((await rowOf(a, 'products', sodaId))['retail_price_cents'], 7000, reason: 'it finally reaches A');
    });

    test('only once: the next sync sends nothing again', () async {
      await leaveAnEditUnderTheOtherDevicesName();
      await b.syncWithCloud();
      final pushed = cloud.pushRequests;

      await b.syncWithCloud();

      expect(cloud.pushRequests, pushed, reason: 'nothing left to upload');
    });

    test('a row nobody ever changed is not sent again', () async {
      await b.db.customStatement("DELETE FROM local_safety_state WHERE id='$editsBeforeRevisionOwnersSentFlag'");

      await b.syncWithCloud();

      expect((await rowOf(b, 'products', sodaId))['created_by_device_id'], a.id);
      expect(cloud.pushedBy[b.id], isNull, reason: 'B had nothing of its own to send');
    });

    test('an older copy sent again never replaces a newer change on another device', () async {
      // B holds the price from before A changed it again; sent again as B's, it still carries its old time.
      clock.value = clock.value.add(const Duration(hours: 1));
      await a.setPrice(sodaId, 6500);
      await a.syncWithCloud();
      await b.syncWithCloud();
      clock.value = clock.value.add(const Duration(hours: 1));
      await a.setPrice(sodaId, 9000);
      await a.syncWithCloud();
      await b.db.customStatement("DELETE FROM local_safety_state WHERE id='$editsBeforeRevisionOwnersSentFlag'");

      await b.sync.pushLocalChanges(syncDeviceBaseUrl, 'device-key');
      await a.syncWithCloud();
      await b.syncWithCloud();

      expect((await rowOf(a, 'products', sodaId))['retail_price_cents'], 9000);
      expect((await rowOf(b, 'products', sodaId))['retail_price_cents'], 9000);
    });

    test('a device that joins a shop has nothing of its own to send', () async {
      final c = await SyncDevice.create('C', cloud, clock);
      addTearDown(c.db.close);
      // A device from before 1.0.96 (its database not new) that now joins the shop.
      await c.db.customStatement("DELETE FROM local_safety_state WHERE id='$editsBeforeRevisionOwnersSentFlag'");
      clock.value = clock.value.add(const Duration(hours: 1));
      await a.setPrice(sodaId, 6500);
      await a.syncWithCloud();
      await c.join();

      await c.syncWithCloud();

      expect(cloud.pushedBy[c.id], isNull);
    });
  });
}
