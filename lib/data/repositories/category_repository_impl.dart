import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/id_generator.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../local/database.dart' hide Category;
import '../local/database.dart' as drift_db show Category;
import '../local/daos/categories_dao.dart';
import '../local/sync_metadata.dart';

part 'category_repository_impl.g.dart';

@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return CategoryRepositoryImpl(
    db,
    db.categoriesDao,
    ref.watch(syncMetadataProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
  );
}

class CategoryRepositoryImpl implements CategoryRepository {
  final AppDatabase _db;
  final CategoriesDao _dao;
  final SyncMetadataService _syncMeta;
  final Clock _clock;
  final IdGenerator _idGenerator;

  CategoryRepositoryImpl(this._db, this._dao, this._syncMeta, this._clock, this._idGenerator);

  Category _toEntity(drift_db.Category row) =>
      Category(id: row.id, name: row.name, status: row.status);

  @override
  Future<List<Category>> getAll() async {
    final rows = await _dao.getAll();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<Category?> findById(String id) async {
    final row = await _dao.findById(id);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<Category?> findByName(String name) async {
    final row = await _dao.findByName(name);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> create(Category category) async {
    await _db.transaction(() async {
      final now = _clock.now().toIso8601String();
      final rev = await _syncMeta.nextLocalRev();
      final deviceId = await _syncMeta.deviceId();
      await _dao.insertCategory(CategoriesCompanion.insert(
        id: category.id.isEmpty ? _idGenerator.newId() : category.id,
        name: category.name,
        status: Value(category.status),
        createdAt: now,
        updatedAt: now,
        localRev: rev,
        createdByDeviceId: deviceId,
      ));
    });
  }

  @override
  Future<void> update(Category category) async {
    await _db.transaction(() async {
      final now = _clock.now().toIso8601String();
      final rev = await _syncMeta.nextLocalRev();
      await _dao.updateCategory(
        category.id,
        CategoriesCompanion(
          name: Value(category.name),
          status: Value(category.status),
          updatedAt: Value(now),
          localRev: Value(rev),
        ),
      );
    });
  }
}
