import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/utils/money.dart';

part 'payment_record.freezed.dart';

/// method mirrors sale.paymentMethod for the external methods (mpesa,
/// mpesa_manual, paystack, intasend) - cash sales never get a
/// payment_records row, same as PHP. [referenceNote] is free text the
/// cashier can type for mpesa/mpesa_manual (e.g. an M-Pesa confirmation
/// code); for paystack/intasend it holds the gateway's own transaction
/// reference (IntaSend: the same value as its invoice's api_ref) once
/// confirmed.
/// status: 'initiated' (paystack/intasend only, while awaiting
/// confirmation), 'paid', 'failed' (paystack/intasend only, cashier
/// cancelled/gateway declined).
@freezed
abstract class PaymentRecord with _$PaymentRecord {
  const factory PaymentRecord({
    required String id,
    required String saleId,
    required String method,
    required Money amount,
    String? referenceNote,
    required String status,
  }) = _PaymentRecord;

  const PaymentRecord._();
}
