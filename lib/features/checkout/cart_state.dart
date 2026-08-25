import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/cart_item.dart';

part 'cart_state.freezed.dart';

/// UI-workflow state for an in-progress sale - not a domain concept
/// reused elsewhere, so unlike CartItem this lives in features/, not
/// domain/entities/. CheckoutService only ever sees the plain
/// `List<CartItem>` this produces at checkout time.
@freezed
abstract class CartState with _$CartState {
  const factory CartState({
    @Default([]) List<CartItem> items,
    @Default('retail') String saleType,
    @Default(Money.zero()) Money discount,
    @Default('') String customerName,
    @Default('') String customerPhone,
    @Default('cash') String paymentMethod,
    @Default('') String referenceNote,
  }) = _CartState;

  const CartState._();

  Money get subtotal => items.fold(const Money.zero(), (sum, item) => sum + item.lineTotal);

  bool get isEmpty => items.isEmpty;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
}
