import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/utils/money.dart';

part 'cart_item.freezed.dart';

/// One line in an in-progress sale, before checkout. Not persisted as
/// its own table - CheckoutService turns a list of these into sale_items
/// rows (plus stock movements) atomically at checkout time.
///
/// [unitPrice] is carried on the cart line rather than re-read from the
/// product at checkout, matching PHP's checkout route (it trusts
/// whatever price the client sent, since retail-vs-wholesale selection
/// and any manual discounting already happened when the item was added
/// to the cart). [costPrice] is snapshotted the same way so sale_items
/// always has an accurate profit basis even if the product's cost
/// changes later. [productId] null means a manual (non-catalog) item,
/// which CheckoutService never stock-checks or stock-decrements.
@freezed
abstract class CartItem with _$CartItem {
  const factory CartItem({
    String? productId,
    required String name,
    required Money unitPrice,
    required Money costPrice,
    required int quantity,
    // The catalog prices at the moment the product was added, kept so that
    // switching the sale between retail and wholesale can re-price the lines
    // already in the cart (null for a manual item, which has no catalog price).
    Money? retailPrice,
    Money? wholesalePrice,
  }) = _CartItem;

  const CartItem._();

  bool get isManual => productId == null;

  /// This line at the price for [saleType] - unchanged for a manual item or one
  /// whose catalog prices are not known. The same rule as Product.priceFor: a
  /// wholesale price that was never set means the retail price.
  CartItem repricedFor(String saleType) {
    final retail = retailPrice;
    final wholesale = wholesalePrice;
    if (isManual || retail == null || wholesale == null) return this;
    final price = saleType == 'wholesale' && wholesale > const Money.zero() ? wholesale : retail;
    return price == unitPrice ? this : copyWith(unitPrice: price);
  }

  Money get lineTotal => unitPrice * quantity;
}
