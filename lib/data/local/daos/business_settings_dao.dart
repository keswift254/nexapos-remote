import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/business_settings_table.dart';

part 'business_settings_dao.g.dart';

@DriftAccessor(tables: [BusinessSettings])
class BusinessSettingsDao extends DatabaseAccessor<AppDatabase> with _$BusinessSettingsDaoMixin {
  BusinessSettingsDao(super.db);

  Future<BusinessSetting> get() => (select(businessSettings)..limit(1)).getSingle();

  Future<void> updateRow(String id, BusinessSettingsCompanion companion) {
    return (update(businessSettings)..where((s) => s.id.equals(id))).write(companion);
  }
}
