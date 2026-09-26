import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../products/products_screen.dart' show allProductsProvider;
import 'add_item_actions.dart';
import 'cart_notifier.dart';

/// Cashier-facing product browser: tap a product to add it to the cart.
/// Deliberately separate from ProductsScreen, which is the admin
/// inventory-management view (edit/disable/adjust stock) - this one is
/// read-only and only ever active products are sellable.
class NewSaleScreen extends ConsumerStatefulWidget {
  const NewSaleScreen({super.key});

  @override
  ConsumerState<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends ConsumerState<NewSaleScreen> {
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Fires on Enter, which is exactly how a keyboard-wedge barcode
  /// scanner (the standard, driver-free kind that types the decoded
  /// digits then a return keystroke, on both Windows and Android) hands
  /// off a scan - no separate "scan mode" toggle needed, the same
  /// search box a cashier can also just type a product name into.
  Future<void> _handleSearchSubmitted(String value) async {
    final added = await handleBarcodeSearchSubmitted(context, ref, value);
    if (!added || !mounted) return;
    // Not a recognized barcode leaves the query alone - _query is
    // already updated live via onChanged, so there's nothing further to
    // do for that case here.
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(allProductsProvider);
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Add manual item',
            onPressed: () => showAddManualItemDialog(context, ref),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search products, or scan a barcode...',
                prefixIcon: Icon(Icons.search),
                filled: true,
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
              onSubmitted: _handleSearchSubmitted,
            ),
          ),
        ),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load products: $error')),
        data: (products) {
          final sellable = products.where((p) => p.isActive).toList();
          final filtered = _query.isEmpty
              ? sellable
              : sellable.where((p) => p.name.toLowerCase().contains(_query)).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('No products found.'));
          }

          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final product = filtered[index];
              final price = product.priceFor(cart.saleType);
              return ListTile(
                title: Text(product.name),
                subtitle: Text('${price.format()} · ${product.stockQty} in stock'),
                trailing: const Icon(Icons.add_circle_outline),
                enabled: product.stockQty > 0,
                onTap: () => ref.read(cartProvider.notifier).addProduct(product),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: () => context.push('/checkout/cart'),
            child: Text(
              cart.isEmpty ? 'View cart' : 'View cart (${cart.itemCount}) · ${cart.subtotal.format()}',
            ),
          ),
        ),
      ),
    );
  }
}
