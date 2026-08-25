import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/data/local/tables/roles_table.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('onCreate seeds exactly one device_meta row with a real uuid', () async {
    final rows = await db.select(db.deviceMeta).get();
    expect(rows, hasLength(1));
    expect(rows.single.deviceId, isNotEmpty);
    // 4 seed rows (3 roles + business_settings) each consume a distinct
    // rev via SyncMetadataService, so the counter should sit one past
    // the last one handed out - not a hardcoded 1 shared by every seed
    // row, which would make two of them indistinguishable to a
    // rev-cursor sync.
    expect(rows.single.nextLocalRev, 5);
  });

  test('no two seeded rows share a local_rev', () async {
    final roleRevs = (await db.select(db.roles).get()).map((r) => r.localRev);
    final settingsRevs = (await db.select(db.businessSettings).get()).map((r) => r.localRev);
    final allRevs = [...roleRevs, ...settingsRevs];
    expect(allRevs.toSet(), hasLength(allRevs.length),
        reason: 'every seeded row must consume its own distinct local_rev');
  });

  test('onCreate seeds the 3 roles with fixed ids matching RoleIds', () async {
    final rows = await db.select(db.roles).get();
    expect(rows, hasLength(3));
    final byId = {for (final r in rows) r.id: r.name};
    expect(byId[RoleIds.admin], 'admin');
    expect(byId[RoleIds.manager], 'manager');
    expect(byId[RoleIds.cashier], 'cashier');
  });

  test('seeded roles are all attributed to the same seeded device id', () async {
    final device = (await db.select(db.deviceMeta).get()).single;
    final roles = await db.select(db.roles).get();
    for (final role in roles) {
      expect(role.createdByDeviceId, device.deviceId,
          reason: 'role ${role.name} was attributed to a different device id than device_meta - '
              'this was the exact ordering bug caught and fixed during Step 2');
    }
  });

  test('onCreate seeds exactly one business_settings row', () async {
    final rows = await db.select(db.businessSettings).get();
    expect(rows, hasLength(1));
    expect(rows.single.currency, 'KES');
  });

  test('foreign_keys pragma is on - inserting a user with an unknown role is rejected', () async {
    final now = DateTime.now().toUtc().toIso8601String();
    final device = (await db.select(db.deviceMeta).get()).single;
    expect(
      () => db.into(db.users).insert(
            UsersCompanion.insert(
              id: 'u1',
              roleId: 'not-a-real-role-id',
              name: 'Test User',
              username: 'testuser',
              passwordHash: 'irrelevant-for-this-test',
              createdAt: now,
              updatedAt: now,
              localRev: 1,
              createdByDeviceId: device.deviceId,
            ),
          ),
      throwsA(anything),
    );
  });

  test('updated_at trigger backstop stamps a new value when a caller forgets to pass one', () async {
    final role = (await db.select(db.roles).get()).first;
    final beforeUpdatedAt = role.updatedAt;

    // Deliberately update without touching updated_at, simulating a
    // caller that forgot - the trigger (WHEN NEW.updated_at =
    // OLD.updated_at) should fire and stamp a fresh value.
    await db.customStatement(
      "UPDATE roles SET description = 'changed' WHERE id = '${role.id}'",
    );

    final after = await (db.select(db.roles)..where((r) => r.id.equals(role.id))).getSingle();
    expect(after.description, 'changed');
    expect(after.updatedAt, isNot(beforeUpdatedAt),
        reason: 'trigger should have stamped a new updated_at when the UPDATE left it unchanged');

    final triggers = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'trigger'",
    ).get();
    final triggerNames = triggers.map((r) => r.data['name'] as String).toSet();
    for (final table in [
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
    ]) {
      expect(triggerNames, contains('trg_${table}_updated_at'),
          reason: 'missing updated_at backstop trigger for $table');
    }
  });
}
