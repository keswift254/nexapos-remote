import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/payment_records_table.dart';

part 'payment_records_dao.g.dart';

@DriftAccessor(tables: [PaymentRecords])
class PaymentRecordsDao extends DatabaseAccessor<AppDatabase> with _$PaymentRecordsDaoMixin {
  PaymentRecordsDao(super.db);

  Future<void> insertRecord(PaymentRecordsCompanion companion) {
    return into(paymentRecords).insert(companion);
  }

  Future<PaymentRecord?> forSale(String saleId) {
    return (select(paymentRecords)..where((p) => p.saleId.equals(saleId) & p.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// [referenceNote] is only overwritten when a non-null value is
  /// passed, since a paystack confirmation supplies the gateway
  /// reference here while an mpesa/mpesa_manual sale already wrote its
  /// cashier-entered note at insert time and has nothing to update.
  Future<void> updateStatus(String id, String status, String updatedAt, int localRev, {String? referenceNote}) {
    return (update(paymentRecords)..where((p) => p.id.equals(id))).write(
      PaymentRecordsCompanion(
        status: Value(status),
        updatedAt: Value(updatedAt),
        localRev: Value(localRev),
        referenceNote: referenceNote == null ? const Value.absent() : Value(referenceNote),
      ),
    );
  }
}
