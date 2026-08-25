import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../core/utils/clock.dart';
import '../../domain/entities/business_settings.dart';
import '../../domain/repositories/business_settings_repository.dart';
import '../local/database.dart';
import '../local/daos/business_settings_dao.dart';
import '../local/sync_metadata.dart';

part 'business_settings_repository_impl.g.dart';

@Riverpod(keepAlive: true)
BusinessSettingsRepository businessSettingsRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return BusinessSettingsRepositoryImpl(db, db.businessSettingsDao, ref.watch(syncMetadataProvider), ref.watch(clockProvider));
}

class BusinessSettingsRepositoryImpl implements BusinessSettingsRepository {
  final AppDatabase _db;
  final BusinessSettingsDao _dao;
  final SyncMetadataService _syncMeta;
  final Clock _clock;

  BusinessSettingsRepositoryImpl(this._db, this._dao, this._syncMeta, this._clock);

  BusinessSettings _toEntity(BusinessSetting row) => BusinessSettings(
        businessName: row.businessName,
        address: row.address,
        phone: row.phone,
        receiptFooter: row.receiptFooter,
        currency: row.currency,
        paperWidthMm: row.paperWidthMm,
      );

  @override
  Future<BusinessSettings> get() async {
    final row = await _dao.get();
    return _toEntity(row);
  }

  @override
  Future<void> update(BusinessSettings settings) async {
    await _db.transaction(() async {
      final row = await _dao.get();
      final now = _clock.now().toIso8601String();
      final rev = await _syncMeta.nextLocalRev();
      await _dao.updateRow(
        row.id,
        BusinessSettingsCompanion(
          businessName: Value(settings.businessName),
          address: Value(settings.address),
          phone: Value(settings.phone),
          receiptFooter: Value(settings.receiptFooter),
          currency: Value(settings.currency),
          paperWidthMm: Value(settings.paperWidthMm),
          updatedAt: Value(now),
          localRev: Value(rev),
        ),
      );
    });
  }
}
