// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_settings_dao.dart';

// ignore_for_file: type=lint
mixin _$BusinessSettingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $BusinessSettingsTable get businessSettings =>
      attachedDatabase.businessSettings;
  BusinessSettingsDaoManager get managers => BusinessSettingsDaoManager(this);
}

class BusinessSettingsDaoManager {
  final _$BusinessSettingsDaoMixin _db;
  BusinessSettingsDaoManager(this._db);
  $$BusinessSettingsTableTableManager get businessSettings =>
      $$BusinessSettingsTableTableManager(
        _db.attachedDatabase,
        _db.businessSettings,
      );
}
