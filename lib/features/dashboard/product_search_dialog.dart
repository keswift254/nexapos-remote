import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/product.dart';
import '../checkout/cart_notifier.dart';
import '../products/products_screen.dart' show allProductsProvider;

/// Quick add-to-cart search reachable straight from the dashboard,
/// without navigating into the full New Sale screen first. Mirrors
/// NewSaleScreen's own search+tap-to-add behavior (same provider, same
/// active-only/in-stock rules) so the cart stays consistent no matter
/// which entry point was used.
class ProductSearchDialog extends ConsumerStatefulWidget {
  const ProductSearchDialog({super.key});

  @override
  ConsumerState<ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends ConsumerState<ProductSearchDialog> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addToCart(Product product) {
    ref.read(cartProvider.notifier).addProduct(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${product.name} to cart'), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(allProductsProvider);
    final cart = ref.watch(cartProvider);

    return AlertDialog(
      title: const Text('Search Inventory'),
      content: SizedBox(
        width: 420,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Search products...', prefixIcon: Icon(Icons.search)),
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Failed to load products: $error')),
                data: (products) {
                  final sellable = products.where((p) => p.isActive).toList();
                  final filtered =
                      _query.isEmpty ? sellable : sellable.where((p) => p.name.toLowerCase().contains(_query)).toList();
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
                        onTap: () => _addToCart(product),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            context.push('/checkout/cart');
          },
          icon: const Icon(Icons.shopping_cart_outlined),
          label: Text(cart.isEmpty ? 'View Cart' : 'View Cart (${cart.itemCount})'),
        ),
      ],
    );
  }
}
