import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/payment_record.dart';
import '../../domain/repositories/payment_record_repository.dart';
import '../local/database.dart' hide PaymentRecord;
import '../local/database.dart' as drift_db show PaymentRecord;
import '../local/daos/payment_records_dao.dart';
import '../local/sync_metadata.dart';

part 'payment_record_repository_impl.g.dart';

@Riverpod(keepAlive: true)
PaymentRecordRepository paymentRecordRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return PaymentRecordRepositoryImpl(
    db,
    db.paymentRecordsDao,
    ref.watch(syncMetadataProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
  );
}

class PaymentRecordRepositoryImpl implements PaymentRecordRepository {
  final AppDatabase _db;
  final PaymentRecordsDao _dao;
  final SyncMetadataService _syncMeta;
  final Clock _clock;
  final IdGenerator _idGenerator;

  PaymentRecordRepositoryImpl(this._db, this._dao, this._syncMeta, this._clock, this._idGenerator);

  PaymentRecord _toEntity(drift_db.PaymentRecord row) => PaymentRecord(
        id: row.id,
        saleId: row.saleId,
        method: row.method,
        amount: Money(row.amountCents),
        referenceNote: row.referenceNote,
        status: row.status,
      );

  @override
  Future<PaymentRecord?> forSale(String saleId) async {
    final row = await _dao.forSale(saleId);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<String> create(PaymentRecord record) async {
    final id = record.id.isEmpty ? _idGenerator.newId() : record.id;
    await _db.transaction(() async {
      final now = _clock.now().toIso8601String();
      final rev = await _syncMeta.nextLocalRev();
      final deviceId = await _syncMeta.deviceId();
      await _dao.insertRecord(PaymentRecordsCompanion.insert(
        id: id,
        saleId: record.saleId,
        method: record.method,
        amountCents: record.amount.cents,
        referenceNote: Value(record.referenceNote),
        status: Value(record.status),
        createdAt: now,
        updatedAt: now,
        localRev: rev,
        createdByDeviceId: deviceId,
      ));
    });
    return id;
  }

  @override
  Future<void> updateStatus(String id, String status, {String? referenceNote}) async {
    await _db.transaction(() async {
      final now = _clock.now().toIso8601String();
      final rev = await _syncMeta.nextLocalRev();
      await _dao.updateStatus(id, status, now, rev, referenceNote: referenceNote);
    });
  }
}
