import '../entities/category.dart';

abstract class CategoryRepository {
  Future<List<Category>> getAll();

  Future<Category?> findById(String id);

  Future<Category?> findByName(String name);

  Future<void> create(Category category);

  Future<void> update(Category category);
}
