import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money.dart';
import '../../data/repositories/product_repository_impl.dart' show productRepositoryProvider;
import 'cart_notifier.dart';

/// Shared between NewSaleScreen (the product browser) and CartScreen
/// (which offers the same shortcut so a cashier doesn't have to leave
/// checkout to add one more item) - kept in one place so the dialog and
/// its validation can't drift between the two call sites.
Future<void> showAddManualItemDialog(BuildContext context, WidgetRef ref) async {
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

/// Looks [code] up as a barcode and adds it straight to the cart if it
/// matches an active product. Returns true when it did (so the caller
/// knows to clear its own search field/controller) - false leaves the
/// text as an ordinary, still-uncommitted search query for the caller
/// to keep handling itself (NewSaleScreen filters its product grid by
/// it; CartScreen has no such grid, so it just leaves the text alone).
Future<bool> handleBarcodeSearchSubmitted(BuildContext context, WidgetRef ref, String code) async {
  final trimmed = code.trim();
  if (trimmed.isEmpty) return false;
  final product = await ref.read(productRepositoryProvider).findByBarcode(trimmed);
  if (!context.mounted) return false;
  if (product == null || !product.isActive) return false;
  ref.read(cartProvider.notifier).addProduct(product);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Added "${product.name}" from barcode scan.'), duration: const Duration(seconds: 1)),
  );
  return true;
}
