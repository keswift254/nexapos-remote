import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/data/import/legacy_pos_mapper.dart';
import 'package:nexapos_mobile/features/dashboard/dashboard_screen.dart';

import '../../data/import/shop_archive_test.dart' show legacyFixture;

void main() {
  test(
    'dashboard refreshes after import and successive incoming stock writes',
    () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final db = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      final subscription = container.listen(dashboardDataProvider, (_, _) {});
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await db.close();
      });
      expect(
        (await container.read(dashboardDataProvider.future)).stockValue.cents,
        0,
      );
      await LegacyPosMapper('refresh-test')
          .convert(legacyFixture())
          .mergeInto(db);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        (await container.read(dashboardDataProvider.future)).stockValue.cents,
        4160,
      );
      for (final quantity in [7, 6, 5]) {
        await db.customUpdate(
          'UPDATE products SET stock_qty = ?',
          variables: [Variable.withInt(quantity)],
          updates: {db.products},
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          (await container.read(dashboardDataProvider.future)).stockValue.cents,
          520 * quantity,
        );
      }
    },
  );
}
