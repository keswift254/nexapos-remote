import '../entities/business_settings.dart';

/// Single-row settings - unlike every other repository in this app,
/// there's no id to look up by: get()/update() always mean "the one
/// business_settings row", seeded once at database creation time.
abstract class BusinessSettingsRepository {
  Future<BusinessSettings> get();

  Future<void> update(BusinessSettings settings);
}
