import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/product.dart';
import 'cart_state.dart';

part 'cart_notifier.g.dart';

@Riverpod(keepAlive: true)
class CartNotifier extends _$CartNotifier {
  @override
  CartState build() => const CartState();

  /// Adding the same product twice increments its existing line rather
  /// than creating a second one, so the cart screen never shows a
  /// product listed twice - CheckoutService also defensively merges
  /// duplicate lines, but the cart UI shouldn't rely on that.
  void addProduct(Product product) {
    final price = state.saleType == 'wholesale' ? product.wholesalePrice : product.retailPrice;
    final index = state.items.indexWhere((item) => item.productId == product.id);
    if (index >= 0) {
      updateQuantity(index, state.items[index].quantity + 1);
      return;
    }
    final item = CartItem(
      productId: product.id,
      name: product.name,
      unitPrice: price,
      costPrice: product.costPrice,
      quantity: 1,
    );
    state = state.copyWith(items: [...state.items, item]);
  }

  void addManualItem({required String name, required int quantity, required Money price}) {
    final item = CartItem(name: name, unitPrice: price, costPrice: const Money.zero(), quantity: quantity);
    state = state.copyWith(items: [...state.items, item]);
  }

  void updateQuantity(int index, int quantity) {
    if (quantity < 1) {
      removeAt(index);
      return;
    }
    final items = [...state.items];
    items[index] = items[index].copyWith(quantity: quantity);
    state = state.copyWith(items: items);
  }

  void removeAt(int index) {
    final items = [...state.items]..removeAt(index);
    state = state.copyWith(items: items);
  }

  void setSaleType(String saleType) => state = state.copyWith(saleType: saleType);

  void setDiscount(Money discount) => state = state.copyWith(discount: discount);

  void setCustomerName(String name) => state = state.copyWith(customerName: name);

  void setCustomerPhone(String phone) => state = state.copyWith(customerPhone: phone);

  void setPaymentMethod(String method) => state = state.copyWith(paymentMethod: method);

  void setReferenceNote(String note) => state = state.copyWith(referenceNote: note);

  void clear() => state = const CartState();
}
