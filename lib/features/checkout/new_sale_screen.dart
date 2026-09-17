import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/money.dart';
import '../../data/repositories/product_repository_impl.dart' show productRepositoryProvider;
import '../products/products_screen.dart' show allProductsProvider;
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
    final code = value.trim();
    if (code.isEmpty) return;
    final product = await ref.read(productRepositoryProvider).findByBarcode(code);
    if (!mounted) return;
    if (product == null || !product.isActive) {
      // Not a recognized barcode - leave it as an ordinary (now
      // committed) name search; _query is already updated live via
      // onChanged, so there's nothing further to do here.
      return;
    }
    ref.read(cartProvider.notifier).addProduct(product);
    _searchController.clear();
    setState(() => _query = '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "${product.name}" from barcode scan.'), duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _addManualItem(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        void submit() => Navigator.pop(context, true);
        return AlertDialog(
        title: const Text('Add manual item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Item name'),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => submit(),
            ),
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => submit(),
            ),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Price'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
        );
      },
    );
    if (saved != true) return;

    final name = nameController.text.trim();
    final quantity = int.tryParse(qtyController.text.trim()) ?? 0;
    final price = double.tryParse(priceController.text.trim());
    if (name.isEmpty || quantity < 1 || price == null || price <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a name, quantity of at least 1, and a price above 0.')),
        );
      }
      return;
    }
    ref.read(cartProvider.notifier).addManualItem(
          name: name,
          quantity: quantity,
          price: Money.fromMajor(price),
        );
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
            onPressed: () => _addManualItem(context, ref),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search products, or scan a barcode...',
                prefixIcon: Icon(Icons.search),
                filled: true,
                isDense: true,
              ),
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
              final price = cart.saleType == 'wholesale' ? product.wholesalePrice : product.retailPrice;
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
