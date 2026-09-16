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
    // Cash sales only - see SalesTable.cashReceivedCents. Null means not
    // recorded, never a real 0 tendered.
    Money? cashReceived,
  }) = _Sale;

  const Sale._();

  bool get isPaid => status == 'paid';

  bool get isPending => status == 'pending';

  Money? get changeDue => cashReceived == null ? null : cashReceived! - total;

  /// True once cashReceived is recorded and fell short of total - the
  /// receipt labels this case "Still owed" rather than "Change due".
  bool get cashWasShort => changeDue?.isNegative ?? false;

  /// changeDue as a always-positive amount, however it's labeled -
  /// "Change due 200" or "Still owed 200", never a receipt showing a
  /// negative number either way.
  Money? get changeDueAbs =>
      changeDue == null ? null : Money(changeDue!.cents.abs());

  /// Customer-facing label for the receipt/on-screen totals - never the
  /// raw gateway name. 'paystack' shows as "M-Pesa" since that's what
  /// the customer actually experiences (an M-Pesa STK prompt); a
  /// receipt reading "PAYSTACK" would only ever confuse them. Historical
  /// 'intasend' sales still need a real label even though it's retired
  /// from the checkout picker.
  String get paymentMethodLabel => switch (paymentMethod) {
    'cash' => 'Cash',
    'paystack' => 'M-Pesa',
    'mpesa' => 'M-Pesa',
    'mpesa_manual' => 'M-Pesa (Manual)',
    'intasend' => 'M-Pesa (IntaSend)',
    _ => paymentMethod.toUpperCase(),
  };
}
