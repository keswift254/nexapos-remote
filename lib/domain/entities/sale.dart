import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/utils/money.dart';

part 'sale.freezed.dart';

/// saleType: 'retail', 'wholesale'.
/// paymentMethod: 'cash', 'mpesa', 'mpesa_manual', 'paystack', 'intasend'
/// (the first 4 match PHP; intasend is mobile-only, added 1.0.32).
/// status: 'paid', 'pending' (paystack/intasend only, while awaiting
/// gateway confirmation), 'cancelled' (a pending online-gateway sale the
/// cashier abandoned - stock has been restored).
@freezed
abstract class Sale with _$Sale {
  const factory Sale({
    required String id,
    required String saleNumber,
    required String userId,
    required String customerName,
    String? customerPhone,
    required String saleType,
    required String paymentMethod,
    required Money subtotal,
    required Money discount,
    required Money total,
    required String status,
    required DateTime createdAt,
  }) = _Sale;

  const Sale._();

  bool get isPaid => status == 'paid';

  bool get isPending => status == 'pending';
}
