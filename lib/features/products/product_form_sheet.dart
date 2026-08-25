import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/product.dart';
import '../../domain/services/product_service.dart';
import 'products_screen.dart';

/// Shared add/edit form. Initial stock quantity is only collected when
/// creating a new product - editing never touches stock_qty, matching
/// the invariant that only StockService.applyMovement() may write it
/// (see ProductRepository.update's doc comment).
class ProductFormSheet extends ConsumerStatefulWidget {
  final Product? existing;

  const ProductFormSheet({super.key, this.existing});

  @override
  ConsumerState<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends ConsumerState<ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.existing?.name);
  late final _retailController =
      TextEditingController(text: widget.existing?.retailPrice.toMajorDouble.toStringAsFixed(2));
  late final _wholesaleController =
      TextEditingController(text: widget.existing?.wholesalePrice.toMajorDouble.toStringAsFixed(2));
  late final _costController =
      TextEditingController(text: widget.existing?.costPrice.toMajorDouble.toStringAsFixed(2));
  late final _reorderController =
      TextEditingController(text: (widget.existing?.reorderLevel ?? 0).toString());
  final _initialStockController = TextEditingController(text: '0');
  String? _categoryId;
  String? _imagePath;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.existing?.categoryId;
    _imagePath = widget.existing?.imagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _retailController.dispose();
    _wholesaleController.dispose();
    _costController.dispose();
    _reorderController.dispose();
    _initialStockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final docsDir = await getApplicationDocumentsDirectory();
    final productImagesDir = Directory(p.join(docsDir.path, 'product_images'));
    if (!await productImagesDir.exists()) {
      await productImagesDir.create(recursive: true);
    }
    final destination = p.join(
      productImagesDir.path,
      '${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}',
    );
    await File(picked.path).copy(destination);
    setState(() => _imagePath = destination);
  }

  Money? _parseMoney(String text) {
    final value = double.tryParse(text.trim());
    return value == null ? null : Money.fromMajor(value);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      setState(() => _error = 'Select a category.');
      return;
    }
    final retail = _parseMoney(_retailController.text);
    final wholesale = _parseMoney(_wholesaleController.text) ?? const Money.zero();
    final cost = _parseMoney(_costController.text) ?? const Money.zero();
    if (retail == null) {
      setState(() => _error = 'Enter a valid retail price.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final service = ref.read(productServiceProvider);
    final result = _isEdit
        ? await service.update(
            id: widget.existing!.id,
            name: _nameController.text,
            categoryId: _categoryId!,
            retailPrice: retail,
            wholesalePrice: wholesale,
            costPrice: cost,
            reorderLevel: int.tryParse(_reorderController.text) ?? 0,
            imagePath: _imagePath,
          )
        : await service.create(
            name: _nameController.text,
            categoryId: _categoryId!,
            retailPrice: retail,
            wholesalePrice: wholesale,
            costPrice: cost,
            reorderLevel: int.tryParse(_reorderController.text) ?? 0,
            initialStockQty: int.tryParse(_initialStockController.text) ?? 0,
            imagePath: _imagePath,
          );

    result.when(
      ok: (_) {
        if (mounted) Navigator.of(context).pop();
      },
      failure: (message) => setState(() {
        _submitting = false;
        _error = message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(productFormCategoriesProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEdit ? 'Edit product' : 'Add product', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: _imagePath != null ? FileImage(File(_imagePath!)) : null,
                    child: _imagePath == null ? const Icon(Icons.add_a_photo) : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Product name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Failed to load categories: $e'),
                data: (categories) => DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories
                      .where((c) => c.isActive)
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (id) => setState(() => _categoryId = id),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _retailController,
                      decoration: const InputDecoration(labelText: 'Retail price'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _wholesaleController,
                      decoration: const InputDecoration(labelText: 'Wholesale price'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      decoration: const InputDecoration(labelText: 'Cost price'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _reorderController,
                      decoration: const InputDecoration(labelText: 'Reorder level'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _initialStockController,
                  decoration: const InputDecoration(labelText: 'Initial stock quantity'),
                  keyboardType: TextInputType.number,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEdit ? 'Save changes' : 'Create product'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
