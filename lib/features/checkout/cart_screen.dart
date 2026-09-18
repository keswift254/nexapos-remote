import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/money.dart';
import '../../domain/entities/product.dart';
import '../../domain/services/checkout_service.dart';
import '../../domain/services/paystack_payment_service.dart';
import '../../domain/services/session_service.dart';
import '../dashboard/dashboard_screen.dart';
import '../products/products_screen.dart' show allProductsProvider;
import 'add_item_actions.dart';
import 'cart_notifier.dart';
import 'paystack_waiting_screen.dart';

// IntaSend deliberately removed from here, not from CheckoutService/
// IntaSendPaymentService/IntaSendWaitingScreen - those stay, since a sale
// already recorded with paymentMethod 'intasend' (or still 'pending' from
// before this change) still needs to read/reconcile correctly. This map
// is the one and only place a cashier can newly choose it, so removing
// the entry here is the whole of "remove the option".
const _paymentMethodLabels = {'cash': 'Cash', 'paystack': 'M-Pesa Prompt'};

/// Cart review + checkout details. Cash completes
/// immediately through CheckoutService; paystack hands off to its own
/// PaymentService and, on success, its own waiting screen.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  late final _discountController = TextEditingController(
    text: ref.read(cartProvider).discount.cents == 0
        ? ''
        : ref.read(cartProvider).discount.toMajorDouble.toStringAsFixed(2),
  );
  late final _cashReceivedController = TextEditingController(
    text: ref.read(cartProvider).cashReceived.cents == 0
        ? ''
        : ref.read(cartProvider).cashReceived.toMajorDouble.toStringAsFixed(2),
  );
  final _searchController = TextEditingController();
  String _query = '';
  bool _submitting = false;

  @override
  void dispose() {
    _discountController.dispose();
    _cashReceivedController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _matchesFor(List<Product> products, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    return products
        .where((p) => p.isActive && p.name.toLowerCase().contains(needle))
        .toList();
  }

  void _addFromSearch(CartNotifier cart, Product product) {
    cart.addProduct(product);
    _searchController.clear();
    setState(() => _query = '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "${product.name}".'), duration: const Duration(seconds: 1)),
    );
  }

  /// Same shortcut NewSaleScreen offers, so a cashier mid-checkout who
  /// realizes one more item is needed doesn't have to leave the cart to
  /// go find it. Enter first tries an exact barcode match (what a
  /// keyboard-wedge scanner actually sends); failing that, if typing has
  /// already turned up name matches below the field, those are left
  /// showing rather than second-guessed with an error - only truly
  /// nothing (no barcode, no name matches either) gets its own message,
  /// since this screen has no product grid to fall back to for feedback
  /// the way NewSaleScreen's does.
  Future<void> _handleSearchSubmitted(String value) async {
    final added = await handleBarcodeSearchSubmitted(context, ref, value);
    if (!mounted) return;
    if (added) {
      _searchController.clear();
      setState(() => _query = '');
      return;
    }
    final products = ref.read(allProductsProvider).value ?? const [];
    if (value.trim().isNotEmpty && _matchesFor(products, value).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No product found for "${value.trim()}".')),
      );
    }
  }

  Future<void> _submit(
    CartNotifier cart,
    String paymentMethod,
    String userId,
  ) async {
    setState(() => _submitting = true);

    if (paymentMethod == 'paystack') {
      final service = ref.read(paystackPaymentServiceProvider);
      final state = ref.read(cartProvider);
      final result = await service.start(
        cart: state.items,
        discount: state.discount,
        saleType: state.saleType,
        userId: userId,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      result.when(
        ok: (session) {
          cart.clear();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PaystackWaitingScreen(session: session),
            ),
          );
        },
        failure: (message) => _showError(message),
      );
      return;
    }

    final service = ref.read(checkoutServiceProvider);
    final state = ref.read(cartProvider);
    final result = await service.checkout(
      cart: state.items,
      discount: state.discount,
      saleType: state.saleType,
      paymentMethod: paymentMethod,
      referenceNote: '',
      userId: userId,
      cashReceived: paymentMethod == 'cash' && state.cashReceived.cents > 0
          ? state.cashReceived
          : null,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    result.when(
      ok: (sale) {
        cart.clear();
        // Explicit, not just relying on dashboardChangeTicker to have
        // caught this write reactively - the dashboard may not have
        // been mounted/watching at all during checkout, and this
        // guarantees a fresh read the moment we land back on it
        // regardless of that.
        ref.invalidate(dashboardDataProvider);
        // go() alone would replace the whole stack with just the
        // receipt, leaving no way back to the dashboard - collapse to
        // the dashboard first, then push the receipt on top of it.
        context.go('/');
        context.push('/receipt/${sale.id}');
      },
      failure: (message) => _showError(message),
    );
  }

  /// Cash fell short of the total, so "Complete Sale" is disabled (see
  /// build()'s onPressed) - this sends an M-Pesa prompt for just the
  /// shortfall instead of the full total, so the cash already collected
  /// isn't charged again. On confirmation the sale completes as a
  /// single paid sale recording both the cash portion and this M-Pesa
  /// portion - see Sale.isSplitPayment/gatewayPortion.
  Future<void> _submitSplitPaystack(
    CartNotifier cart,
    String userId,
    Money cashReceived,
  ) async {
    setState(() => _submitting = true);
    final service = ref.read(paystackPaymentServiceProvider);
    final state = ref.read(cartProvider);
    final result = await service.start(
      cart: state.items,
      discount: state.discount,
      saleType: state.saleType,
      userId: userId,
      cashReceived: cashReceived,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    result.when(
      ok: (session) {
        cart.clear();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaystackWaitingScreen(session: session),
          ),
        );
      },
      failure: (message) => _showError(message),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final cart = ref.read(cartProvider.notifier);
    final userId = ref.watch(sessionProvider)?.id;
    final discount = cartState.discount;
    final total = discount > cartState.subtotal
        ? const Money.zero()
        : cartState.subtotal - discount;
    // A genuine, entered-but-insufficient cash amount - not simply
    // "nothing typed in" (cents == 0), which is the existing "didn't
    // bother recording it" case and completes as an ordinary cash sale.
    final cashShortfall = cartState.paymentMethod == 'cash' &&
        cartState.cashReceived.cents > 0 &&
        cartState.cashReceived < total;
    final searchMatches = _matchesFor(
      ref.watch(allProductsProvider).value ?? const [],
      _query,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Cart & Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search by name, or scan a barcode...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  // Not digits-only (unlike a plain barcode field) -
                  // this doubles as a live name search, which needs
                  // letters. A real barcode scan still works the same
                  // way regardless: it types digits then Enter, handled
                  // below by onSubmitted's exact-match lookup.
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value),
                  onSubmitted: _handleSearchSubmitted,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.playlist_add),
                tooltip: 'Add manual item',
                onPressed: () => showAddManualItemDialog(context, ref),
              ),
            ],
          ),
          if (_query.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            if (searchMatches.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No products found.'),
              )
            else
              for (final product in searchMatches)
                Card(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    dense: true,
                    title: Text(product.name),
                    subtitle: Text(product.retailPrice.format()),
                    onTap: () => _addFromSearch(cart, product),
                  ),
                ),
          ],
          const SizedBox(height: 12),
          if (cartState.isEmpty) const Text('Your cart is empty.'),
          for (var i = 0; i < cartState.items.length; i++)
            Card(
              child: ListTile(
                title: Text(cartState.items[i].name),
                subtitle: Text('${cartState.items[i].unitPrice.format()} each'),
                leading: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () =>
                      cart.updateQuantity(i, cartState.items[i].quantity - 1),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${cartState.items[i].quantity}'),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => cart.updateQuantity(
                        i,
                        cartState.items[i].quantity + 1,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => cart.removeAt(i),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('Sale type', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Retail'),
                selected: cartState.saleType == 'retail',
                onSelected: (_) => cart.setSaleType('retail'),
              ),
              ChoiceChip(
                label: const Text('Wholesale'),
                selected: cartState.saleType == 'wholesale',
                onSelected: (_) => cart.setSaleType('wholesale'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Payment method', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _paymentMethodLabels.entries
                .map(
                  (entry) => ChoiceChip(
                    label: Text(entry.value),
                    selected: cartState.paymentMethod == entry.key,
                    onSelected: (_) => cart.setPaymentMethod(entry.key),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _discountController,
            decoration: const InputDecoration(labelText: 'Discount'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) => cart.setDiscount(
              Money.fromMajor(double.tryParse(value.trim()) ?? 0),
            ),
          ),
          const SizedBox(height: 16),
          _TotalsRow(label: 'Subtotal', value: cartState.subtotal),
          _TotalsRow(label: 'Discount', value: discount),
          _TotalsRow(label: 'Total', value: total, emphasize: true),
          if (cartState.paymentMethod == 'cash') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _cashReceivedController,
              decoration: const InputDecoration(
                labelText: 'Cash received (optional)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) => cart.setCashReceived(
                Money.fromMajor(double.tryParse(value.trim()) ?? 0),
              ),
            ),
            if (cartState.cashReceived.cents > 0) ...[
              const SizedBox(height: 4),
              _ChangeDueRow(cashReceived: cartState.cashReceived, total: total),
            ],
            if (cashShortfall) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _submitting || userId == null
                    ? null
                    : () => _submitSplitPaystack(
                          cart,
                          userId,
                          cartState.cashReceived,
                        ),
                icon: const Icon(Icons.phone_android),
                label: Text(
                  'Send M-Pesa prompt for ${(total - cartState.cashReceived).format()}',
                ),
              ),
            ],
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: (_submitting || cartState.isEmpty || userId == null || cashShortfall)
                ? null
                : () => _submit(cart, cartState.paymentMethod, userId),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Complete Sale'),
          ),
        ),
      ),
    );
  }
}

/// Live calculator, shown for any entered cash amount. A shortfall
/// ("Still owed") does gate "Complete Sale" (see build()'s onPressed) -
/// the cashier resolves it either by entering more cash or by sending
/// an M-Pesa prompt for the remainder, both surfaced right below this.
class _ChangeDueRow extends StatelessWidget {
  final Money cashReceived;
  final Money total;

  const _ChangeDueRow({required this.cashReceived, required this.total});

  @override
  Widget build(BuildContext context) {
    final change = cashReceived - total;
    final short = change.isNegative;
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: short ? Theme.of(context).colorScheme.error : null,
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(short ? 'Still owed' : 'Change due', style: style),
        Text((short ? Money(-change.cents) : change).format(), style: style),
      ],
    );
  }
}

class _TotalsRow extends StatelessWidget {
  final String label;
  final Money value;
  final bool emphasize;

  const _TotalsRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value.format(), style: style),
        ],
      ),
    );
  }
}
