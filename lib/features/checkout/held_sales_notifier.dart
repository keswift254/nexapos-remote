import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/utils/money.dart';
import 'cart_notifier.dart';
import 'cart_state.dart';

/// The one row this ever occupies in local_safety_state: every sale this device is
/// holding, as one JSON list. Like the cart draft next to it, it is device-local (never
/// synced) and lives in the same database file, so a held sale survives the app being
/// closed, the device restarting, or an update being installed over it.
const heldSalesKey = 'held_sales';

/// A sale a cashier set aside so they could serve the next customer, and will come back
/// to. It is a saved cart, not a sale: it has taken no stock and recorded no payment.
class HeldSale {
  final String id;
  final String label;
  final DateTime heldAt;
  final String heldBy;
  final CartState cart;

  const HeldSale({
    required this.id,
    required this.label,
    required this.heldAt,
    required this.heldBy,
    required this.cart,
  });

  Money get total {
    final subtotal = cart.subtotal;
    return cart.discount > subtotal ? const Money.zero() : subtotal - cart.discount;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'heldAt': heldAt.toUtc().toIso8601String(),
    'heldBy': heldBy,
    'cart': cartStateToJson(cart),
  };

  static HeldSale fromJson(Map<String, dynamic> json) => HeldSale(
    id: json['id'] as String,
    label: json['label'] as String,
    heldAt: DateTime.parse(json['heldAt'] as String),
    heldBy: json['heldBy'] as String,
    cart: cartStateFromJson(json['cart'] as Map<String, dynamic>),
  );
}

final heldSalesProvider = NotifierProvider<HeldSalesNotifier, List<HeldSale>>(
  HeldSalesNotifier.new,
);

class HeldSalesNotifier extends Notifier<List<HeldSale>> {
  @override
  List<HeldSale> build() => const [];

  /// Called once from app.dart's startup sequence, next to the cart's own restore().
  Future<void> restore() async {
    final row = await ref
        .read(appDatabaseProvider)
        .customSelect("SELECT value FROM local_safety_state WHERE id='$heldSalesKey'")
        .getSingleOrNull();
    if (row == null) return;
    try {
      final list = (jsonDecode(row.data['value'] as String) as List)
          .map((raw) => HeldSale.fromJson(raw as Map<String, dynamic>))
          .toList();
      // Anything set aside before this finished loading is kept in front.
      state = [...state, ...list.where((h) => !state.any((s) => s.id == h.id))];
    } catch (_) {
      // Written by an incompatible version, or corrupt: dropping it is safer than
      // failing every launch. (The cart draft does the same.)
    }
  }

  Future<void> _persist() async {
    final db = ref.read(appDatabaseProvider);
    if (state.isEmpty) {
      await db.customStatement("DELETE FROM local_safety_state WHERE id='$heldSalesKey'");
      return;
    }
    await db.customStatement(
      "INSERT OR REPLACE INTO local_safety_state(id,value) VALUES('$heldSalesKey',?)",
      [jsonEncode([for (final held in state) held.toJson()])],
    );
  }

  String _autoLabel(CartState cart) {
    final customer = cart.customerName.trim();
    if (customer.isNotEmpty) return customer;
    var n = 1;
    while (state.any((h) => h.label == 'Held sale $n')) {
      n += 1;
    }
    return 'Held sale $n';
  }

  /// Sets the current cart aside and empties it, ready for the next customer. Nothing is
  /// lost if the app stops half way: the held copy is saved BEFORE the cart is emptied.
  Future<HeldSale?> holdCurrent({String? label, required String heldBy}) async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return null;
    final typed = label?.trim() ?? '';
    final held = HeldSale(
      id: ref.read(idGeneratorProvider).newId(),
      label: typed.isNotEmpty ? typed : _autoLabel(cart),
      heldAt: ref.read(clockProvider).now(),
      heldBy: heldBy,
      cart: cart,
    );
    state = [held, ...state];
    await _persist();
    ref.read(cartProvider.notifier).clear();
    return held;
  }

  /// Brings a held sale back into the cart. If the cart already has something in it this
  /// does nothing (returns false) unless [holdCurrentFirst]: then that is held in turn, so
  /// neither sale is ever thrown away by opening the other.
  Future<bool> resume(String id, {String heldBy = 'Cashier', bool holdCurrentFirst = false}) async {
    final held = state.where((h) => h.id == id).firstOrNull;
    if (held == null) return false;
    if (ref.read(cartProvider).isNotEmpty) {
      if (!holdCurrentFirst) return false;
      await holdCurrent(heldBy: heldBy);
    }
    // The cart gets it first and only then does it leave the held list: stopping half way
    // leaves it in both places rather than in neither.
    await ref.read(cartProvider.notifier).replaceWith(held.cart);
    state = [for (final h in state) if (h.id != id) h];
    await _persist();
    return true;
  }

  Future<void> discard(String id) async {
    state = [for (final h in state) if (h.id != id) h];
    await _persist();
  }

  /// The shop this device belongs to changed: held sales name the old shop's products.
  Future<void> clearAll() async {
    state = const [];
    await _persist();
  }
}
