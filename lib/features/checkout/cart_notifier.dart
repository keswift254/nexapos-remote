import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/product.dart';
import 'cart_state.dart';

part 'cart_notifier.g.dart';

/// The one row this key ever occupies in local_safety_state (see
/// database.dart's own use of that table for sync/shop-change markers)
/// - a device-local draft of whatever's in the cart, never synced to
/// other devices, so a half-finished sale survives the app being
/// closed, the device restarting, or an update being installed over
/// it, exactly like the rest of the shop's data already does by living
/// in the same SQLite file.
const _cartDraftKey = 'cart_draft';

@Riverpod(keepAlive: true)
class CartNotifier extends _$CartNotifier {
  @override
  CartState build() {
    // listenSelf calls its listener once immediately after build()
    // completes, with previous == null (see its own doc comment) - not
    // just on later changes, as its name might suggest. Persisting on
    // that first call would immediately overwrite local_safety_state
    // with this fresh, still-empty initial CartState() the moment
    // ANYTHING first reads cartProvider, wiping out a real draft before
    // restore() (called separately, see below) ever gets a chance to
    // read it back - confirmed for real via a failing "survives an app
    // restart" test before this guard was added. Only a genuine
    // subsequent state change (previous != null) is worth writing.
    listenSelf((previous, next) {
      if (previous != null) _persist(next);
    });
    return const CartState();
  }

  /// Called once from app.dart's real startup sequence (alongside
  /// pendingPaystackSalesProvider.reconcile() and the rest) - not from
  /// build() itself, since almost every feature widget test constructs
  /// a bare CartScreen/DashboardScreen without ever mounting the real
  /// app root that would call this. Reading the database eagerly and
  /// unconditionally inside build() used to fire the instant anything
  /// first watched this provider, including in those tests, which don't
  /// override appDatabaseProvider and have no reason to - the resulting
  /// real (non-memory) connection's own background timers routinely
  /// outlived a test's handful of pump() calls, failing it with "A
  /// Timer is still pending even after the widget tree was disposed."
  Future<void> restore() async {
    final db = ref.read(appDatabaseProvider);
    final row = await db
        .customSelect(
          "SELECT value FROM local_safety_state WHERE id='$_cartDraftKey'",
        )
        .getSingleOrNull();
    if (row == null) return;
    try {
      final restored = _cartStateFromJson(
        jsonDecode(row.data['value'] as String) as Map<String, dynamic>,
      );
      if (restored.isNotEmpty) state = restored;
    } catch (_) {
      // A draft from an older, incompatible app version, or genuinely
      // corrupt - dropping it silently is safer than crashing the cart
      // on every future launch.
    }
  }

  Future<void> _persist(CartState draft) async {
    final db = ref.read(appDatabaseProvider);
    if (draft.isEmpty) {
      await db.customStatement(
        "DELETE FROM local_safety_state WHERE id='$_cartDraftKey'",
      );
      return;
    }
    await db.customStatement(
      "INSERT OR REPLACE INTO local_safety_state(id,value) VALUES('$_cartDraftKey',?)",
      [jsonEncode(_cartStateToJson(draft))],
    );
  }

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

  void setPaymentMethod(String method) {
    // 'intasend' retired alongside 'mpesa'/'mpesa_manual' - no cashier
    // can select it anymore (cart_screen.dart's picker no longer offers
    // it), so a new cart should never be settable to it either. Already
    // recorded/still-pending 'intasend' sales are untouched by this -
    // this only governs new cart state, never historical data.
    if (method != 'cash' && method != 'paystack') return;
    state = state.copyWith(paymentMethod: method);
  }

  void setReferenceNote(String note) => state = state.copyWith(referenceNote: note);

  void setCashReceived(Money amount) => state = state.copyWith(cashReceived: amount);

  void clear() => state = const CartState();
}

/// Hand-written rather than json_serializable-generated: CartState only
/// ever needs to round-trip through this one local draft slot, so a
/// generated file (and wiring CartItem/Money into it too) would be a
/// lot of build_runner output for two small, stable shapes.
Map<String, dynamic> _cartStateToJson(CartState state) => {
  'items': state.items.map(_cartItemToJson).toList(),
  'saleType': state.saleType,
  'discount': state.discount.cents,
  'customerName': state.customerName,
  'customerPhone': state.customerPhone,
  'paymentMethod': state.paymentMethod,
  'referenceNote': state.referenceNote,
  'cashReceived': state.cashReceived.cents,
};

CartState _cartStateFromJson(Map<String, dynamic> json) => CartState(
  items: (json['items'] as List)
      .map((raw) => _cartItemFromJson(raw as Map<String, dynamic>))
      .toList(),
  saleType: json['saleType'] as String,
  discount: Money(json['discount'] as int),
  customerName: json['customerName'] as String,
  customerPhone: json['customerPhone'] as String,
  paymentMethod: json['paymentMethod'] as String,
  referenceNote: json['referenceNote'] as String,
  cashReceived: Money(json['cashReceived'] as int),
);

Map<String, dynamic> _cartItemToJson(CartItem item) => {
  'productId': item.productId,
  'name': item.name,
  'unitPriceCents': item.unitPrice.cents,
  'costPriceCents': item.costPrice.cents,
  'quantity': item.quantity,
};

CartItem _cartItemFromJson(Map<String, dynamic> json) => CartItem(
  productId: json['productId'] as String?,
  name: json['name'] as String,
  unitPrice: Money(json['unitPriceCents'] as int),
  costPrice: Money(json['costPriceCents'] as int),
  quantity: json['quantity'] as int,
);
