import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/categories_table.dart';

part 'categories_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoriesDao extends DatabaseAccessor<AppDatabase> with _$CategoriesDaoMixin {
  CategoriesDao(super.db);

  Future<List<Category>> getAll() {
    return (select(categories)..where((c) => c.deletedAt.isNull())).get();
  }

  Future<Category?> findById(String id) {
    return (select(categories)..where((c) => c.id.equals(id) & c.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<Category?> findByName(String name) {
    return (select(categories)..where((c) => c.name.equals(name) & c.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<void> insertCategory(CategoriesCompanion companion) {
    return into(categories).insert(companion);
  }

  Future<void> updateCategory(String id, CategoriesCompanion companion) {
    return (update(categories)..where((c) => c.id.equals(id))).write(companion);
  }
}
