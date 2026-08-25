import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../core/result.dart';
import '../../core/utils/id_generator.dart';
import '../../data/repositories/category_repository_impl.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';

part 'category_service.g.dart';

@Riverpod(keepAlive: true)
CategoryService categoryService(Ref ref) {
  return CategoryService(ref.watch(categoryRepositoryProvider), ref.watch(idGeneratorProvider));
}

class CategoryService {
  final CategoryRepository _repository;
  final IdGenerator _idGenerator;

  CategoryService(this._repository, this._idGenerator);

  Future<List<Category>> getAll() => _repository.getAll();

  Future<Result<Category>> create(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return const Result.failure('Enter a category name.');
    final existing = await _repository.findByName(trimmed);
    if (existing != null) {
      return const Result.failure('A category with that name already exists.');
    }
    final category = Category(id: _idGenerator.newId(), name: trimmed, status: 'active');
    await _repository.create(category);
    return Result.ok(category);
  }

  Future<Result<Category>> update(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return const Result.failure('Enter a category name.');
    final existing = await _repository.findById(id);
    if (existing == null) return const Result.failure('Category not found.');
    final nameOwner = await _repository.findByName(trimmed);
    if (nameOwner != null && nameOwner.id != id) {
      return const Result.failure('A category with that name already exists.');
    }
    final updated = existing.copyWith(name: trimmed);
    await _repository.update(updated);
    return Result.ok(updated);
  }

  Future<Result<void>> setActive(String id, bool active) async {
    final existing = await _repository.findById(id);
    if (existing == null) return const Result.failure('Category not found.');
    await _repository.update(existing.copyWith(status: active ? 'active' : 'disabled'));
    return const Result.ok(null);
  }
}
