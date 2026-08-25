import '../entities/payment_record.dart';

abstract class PaymentRecordRepository {
  Future<PaymentRecord?> forSale(String saleId);

  Future<String> create(PaymentRecord record);

  /// The only way a payment record changes after creation: a paystack
  /// record moving 'initiated' -> 'paid' (with the gateway's reference
  /// written into referenceNote) or 'initiated' -> 'failed'.
  Future<void> updateStatus(String id, String status, {String? referenceNote});
}
