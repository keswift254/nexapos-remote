import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/data/local/tables/roles_table.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

void main() {
  for (final partial in [false, true]) {
    test('resumes interrupted creation (partial: $partial) preserving data', () async {
      final dir = await Directory.systemTemp.createTemp('nexapos_creation');
      final file = File('${dir.path}/app.db');
      final first = AppDatabase(NativeDatabase(file));
      final identity = (await first.select(first.deviceMeta).get()).single;
      await first.customStatement(
        "UPDATE roles SET description = 'Keep this role' WHERE id = ?",
        [RoleIds.admin],
      );
      await first.customStatement(
        "INSERT INTO categories (id, name, created_at, updated_at, local_rev, created_by_device_id) VALUES (?, ?, ?, ?, ?, ?)",
        ['saved-category', 'Saved stock', '2026-10-02', '2026-10-02', 100, identity.deviceId],
      );
      final adminBefore = (await (first.select(first.roles)
            ..where((t) => t.id.equals(RoleIds.admin))).getSingle()).toJson();
      final settingsBefore = (await first.select(first.businessSettings).get()).single.toJson();
      await first.close();

      // Tables/rows were persisted, but the first-open version write was not.
      final handle = raw.sqlite3.open(file.path);
      if (partial) {
        handle.execute('DELETE FROM roles WHERE id != ?', [RoleIds.admin]);
        handle.execute('DELETE FROM business_settings');
      }
      handle.execute('PRAGMA user_version = 0');
      handle.close();

      final recovered = AppDatabase(NativeDatabase(file));
      addTearDown(() async {
        await recovered.close();
        await dir.delete(recursive: true);
      });
      final device = (await recovered.select(recovered.deviceMeta).get()).single;
      expect(device.deviceId, identity.deviceId);
      expect(device.registrationSecret, identity.registrationSecret);
      expect(device.nextLocalRev, partial ? identity.nextLocalRev + 3 : identity.nextLocalRev);
      expect(await recovered.select(recovered.roles).get(), hasLength(3));
      final admin = await (recovered.select(recovered.roles)
            ..where((t) => t.id.equals(RoleIds.admin))).getSingle();
      expect(admin.toJson(), adminBefore);
      final settings = (await recovered.select(recovered.businessSettings).get()).single;
      if (!partial) expect(settings.toJson(), settingsBefore);
      expect((await recovered.select(recovered.categories).get()).single.name, 'Saved stock');
      expect((await recovered.customSelect('PRAGMA user_version').getSingle()).read<int>('user_version'), recovered.schemaVersion);
      expect(await recovered.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    });
  }
}
