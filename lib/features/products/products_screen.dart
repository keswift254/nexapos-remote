import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/result.dart';
import '../../data/import/xlsx_catalog_reader.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../../domain/services/catalog_import_service.dart';
import '../../domain/services/category_service.dart';
import '../../domain/services/product_service.dart';
import '../../domain/services/session_service.dart';
import 'product_form_sheet.dart';
import 'stock_adjustment_sheet.dart';

part 'products_screen.g.dart';

@riverpod
Future<List<Product>> allProducts(Ref ref) {
  return ref.watch(productServiceProvider).getAll();
}

@riverpod
Future<List<Category>> productFormCategories(Ref ref) {
  return ref.watch(categoryServiceProvider).getAll();
}

/// Port of PHP's Inventory page: product list, search, add/edit, and
/// (via the trailing icon) the Adjust Stock action - all routed through
/// ProductService/StockService so the stock_qty invariant holds.
class ProductsScreen extends ConsumerStatefulWidget {
  final bool lowStockOnly;

  const ProductsScreen({super.key, this.lowStockOnly = false});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  static const _pageSize = 10;

  String _query = '';
  int _page = 0;

  Future<void> _openForm(BuildContext context, {Product? existing}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProductFormSheet(existing: existing),
    );
    ref.invalidate(allProductsProvider);
  }

  Future<void> _openStockAdjustment(BuildContext context, Product product) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StockAdjustmentSheet(product: product),
    );
    ref.invalidate(allProductsProvider);
  }

  Future<void> _confirmDelete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          '"${product.name}" will be removed from Inventory. Any past sales that '
          'included it keep showing correctly - this only affects new sales.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(foregroundColor: Theme.of(dialogContext).colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await ref.read(productServiceProvider).delete(product.id);
    if (!mounted) return;
    result.when(
      ok: (_) => ref.invalidate(allProductsProvider),
      failure: (message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))),
    );
  }

  Future<void> _importCatalog(BuildContext context) async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    final path = picked?.path;
    if (path == null) return;
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    Result<CatalogImportSummary> result;
    try {
      final rows = ref.read(xlsxCatalogReaderProvider).read(path);
      final userId = ref.read(sessionProvider)?.id;
      result = await ref.read(catalogImportServiceProvider).importRows(rows, userId: userId);
    } catch (e) {
      result = Result.failure('Could not read the file: $e');
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    result.when(
      ok: (summary) {
        ref.invalidate(allProductsProvider);
        ref.invalidate(productFormCategoriesProvider);
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Import complete'),
            content: Text(
              '${summary.created} created, ${summary.updated} updated, '
              '${summary.skipped} skipped, ${summary.duplicatesMerged} duplicate rows merged.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      },
      failure: (message) {
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Import failed'),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(allProductsProvider);
    final categoriesAsync = ref.watch(productFormCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lowStockOnly ? 'Low Stock' : 'Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import from Excel',
            onPressed: () => _importCatalog(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search products...',
                prefixIcon: Icon(Icons.search),
                filled: true,
                isDense: true,
              ),
              onChanged: (value) => setState(() {
                _query = value.trim().toLowerCase();
                _page = 0;
              }),
            ),
          ),
        ),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load products: $error')),
        data: (products) {
          final categories = categoriesAsync.when(
            data: (data) => data,
            loading: () => const <Category>[],
            error: (_, _) => const <Category>[],
          );
          final categoryNames = {for (final c in categories) c.id: c.name};
          final scoped = widget.lowStockOnly ? products.where((p) => p.isLowStock).toList() : products;
          final filtered = _query.isEmpty
              ? scoped
              : scoped.where((p) => p.name.toLowerCase().contains(_query)).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Text(widget.lowStockOnly ? 'No products at or below reorder level.' : 'No products found.'),
            );
          }

          final pageCount = (filtered.length / _pageSize).ceil();
          final page = _page.clamp(0, pageCount - 1);
          final pageItems = filtered.skip(page * _pageSize).take(_pageSize).toList();

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: pageItems.length,
                  itemBuilder: (context, index) {
                    final product = pageItems[index];
                    return ListTile(
                      title: Text(product.name),
                      subtitle: Text(
                        '${categoryNames[product.categoryId] ?? 'Uncategorized'} · ${product.retailPrice.format()}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${product.stockQty} in stock',
                                style: product.isLowStock
                                    ? TextStyle(color: Theme.of(context).colorScheme.error)
                                    : null,
                              ),
                              if (!product.isActive)
                                Text('Disabled', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.tune),
                            tooltip: 'Adjust stock',
                            onPressed: () => _openStockAdjustment(context, product),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete',
                            onPressed: () => _confirmDelete(product),
                          ),
                        ],
                      ),
                      onTap: () => _openForm(context, existing: product),
                    );
                  },
                ),
              ),
              if (pageCount > 1)
                Padding(
                  // Extra bottom inset so the FAB (which floats over the
                  // body rather than reserving space for itself) doesn't
                  // sit on top of these controls.
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        tooltip: 'Previous page',
                        onPressed: page > 0 ? () => setState(() => _page = page - 1) : null,
                      ),
                      Text('Page ${page + 1} of $pageCount'),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Next page',
                        onPressed: page < pageCount - 1 ? () => setState(() => _page = page + 1) : null,
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }
}
