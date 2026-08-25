import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/category.dart';
import '../../domain/services/category_service.dart';

part 'categories_screen.g.dart';

@riverpod
Future<List<Category>> allCategories(Ref ref) {
  return ref.watch(categoryServiceProvider).getAll();
}

/// Admin/manager port of PHP's Categories page (save_category,
/// update_category, disable_category).
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _openForm(BuildContext context, WidgetRef ref, {Category? existing}) async {
    final controller = TextEditingController(text: existing?.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add category' : 'Edit category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Category name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;

    final service = ref.read(categoryServiceProvider);
    final saveResult = existing == null
        ? await service.create(result)
        : await service.update(existing.id, result);

    saveResult.when(
      ok: (_) => ref.invalidate(allCategoriesProvider),
      failure: (message) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
      },
    );
  }

  Future<void> _toggleActive(WidgetRef ref, Category category) async {
    final result = await ref.read(categoryServiceProvider).setActive(category.id, !category.isActive);
    result.when(ok: (_) => ref.invalidate(allCategoriesProvider), failure: (_) {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(allCategoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load categories: $error')),
        data: (categories) => ListView.builder(
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return ListTile(
              title: Text(category.name),
              trailing: Switch(
                value: category.isActive,
                onChanged: (_) => _toggleActive(ref, category),
              ),
              onTap: () => _openForm(context, ref, existing: category),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
    );
  }
}
