import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
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
      if (restored.isNotEmpty) state = await _withCatalogPrices(restored);
    } catch (_) {
      // A draft from an older, incompatible app version, or genuinely
      // corrupt - dropping it silently is safer than crashing the cart
      // on every future launch.
    }
  }

  /// A draft saved by an older version has no catalog prices on its lines, so
  /// switching it to wholesale could not re-price them. Fill them in from the
  /// products as they are now (the lines keep the price they were added at until
  /// the sale type is switched). Best effort: a product that is gone, or a
  /// database that cannot be read, just leaves that line as it was.
  Future<CartState> _withCatalogPrices(CartState draft) async {
    final missing = [
      for (final item in draft.items)
        if (!item.isManual && (item.retailPrice == null || item.wholesalePrice == null)) item.productId!,
    ];
    if (missing.isEmpty) return draft;
    try {
      final rows = await ref
          .read(appDatabaseProvider)
          .customSelect(
            'SELECT id, retail_price_cents, wholesale_price_cents FROM products '
            'WHERE id IN (${List.filled(missing.length, '?').join(',')})',
            variables: [for (final id in missing) Variable.withString(id)],
          )
          .get();
      final prices = {
        for (final row in rows)
          row.data['id'] as String: (
            Money(row.data['retail_price_cents'] as int),
            Money(row.data['wholesale_price_cents'] as int),
          ),
      };
      return draft.copyWith(
        items: [
          for (final item in draft.items)
            if (!item.isManual && prices.containsKey(item.productId))
              item.copyWith(
                retailPrice: item.retailPrice ?? prices[item.productId]!.$1,
                wholesalePrice: item.wholesalePrice ?? prices[item.productId]!.$2,
              )
            else
              item,
        ],
      );
    } catch (_) {
      return draft;
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
    final price = product.priceFor(state.saleType);
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
      retailPrice: product.retailPrice,
      wholesalePrice: product.wholesalePrice,
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

  /// Switching between retail and wholesale re-prices every catalog line already
  /// in the cart, not just the ones added afterwards (manual items keep the price
  /// they were typed with).
  void setSaleType(String saleType) => state = state.copyWith(
    saleType: saleType,
    items: [for (final item in state.items) item.repricedFor(saleType)],
  );

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
  if (item.retailPrice != null) 'retailPriceCents': item.retailPrice!.cents,
  if (item.wholesalePrice != null) 'wholesalePriceCents': item.wholesalePrice!.cents,
};

CartItem _cartItemFromJson(Map<String, dynamic> json) => CartItem(
  productId: json['productId'] as String?,
  name: json['name'] as String,
  unitPrice: Money(json['unitPriceCents'] as int),
  costPrice: Money(json['costPriceCents'] as int),
  quantity: json['quantity'] as int,
  retailPrice: json['retailPriceCents'] is int ? Money(json['retailPriceCents'] as int) : null,
  wholesalePrice: json['wholesalePriceCents'] is int ? Money(json['wholesalePriceCents'] as int) : null,
);
