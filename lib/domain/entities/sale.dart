import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/utils/money.dart';

part 'sale.freezed.dart';

/// saleType: 'retail', 'wholesale'.
/// paymentMethod: 'cash', 'mpesa', 'mpesa_manual', 'paystack' (same 4
/// values as PHP).
/// status: 'paid', 'pending' (paystack only, while awaiting gateway
/// confirmation), 'cancelled' (a pending paystack sale the cashier
/// abandoned - stock has been restored).
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
