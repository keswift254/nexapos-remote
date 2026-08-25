import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../local/database.dart' hide Product;
import '../local/database.dart' as drift_db show Product;
import '../local/daos/products_dao.dart';
import '../local/sync_metadata.dart';

part 'product_repository_impl.g.dart';

@Riverpod(keepAlive: true)
ProductRepository productRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return ProductRepositoryImpl(
    db,
    db.productsDao,
    ref.watch(syncMetadataProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
  );
}

class ProductRepositoryImpl implements ProductRepository {
  final AppDatabase _db;
  final ProductsDao _dao;
  final SyncMetadataService _syncMeta;
  final Clock _clock;
  final IdGenerator _idGenerator;

  ProductRepositoryImpl(this._db, this._dao, this._syncMeta, this._clock, this._idGenerator);

  Product _toEntity(drift_db.Product row) => Product(
        id: row.id,
        sku: row.sku,
        name: row.name,
        categoryId: row.categoryId,
        imagePath: row.imagePath,
        retailPrice: Money(row.retailPriceCents),
        wholesalePrice: Money(row.wholesalePriceCents),
        costPrice: Money(row.costPriceCents),
        stockQty: row.stockQty,
        reorderLevel: row.reorderLevel,
        status: row.status,
      );

  @override
  Future<List<Product>> getAll() async {
    final rows = await _dao.getAll();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<Product?> findById(String id) async {
    final row = await _dao.findById(id);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<Product?> findBySku(String sku) async {
    final row = await _dao.findBySku(sku);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<Product?> findByNameAndCategory(String name, String categoryId) async {
    final row = await _dao.findByNameAndCategory(name, categoryId);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<String> create(Product product) async {
    final id = product.id.isEmpty ? _idGenerator.newId() : product.id;
    await _db.transaction(() async {
      final now = _clock.now().toIso8601String();
      final rev = await _syncMeta.nextLocalRev();
      final deviceId = await _syncMeta.deviceId();
      await _dao.insertProduct(ProductsCompanion.insert(
        id: id,
        sku: product.sku,
        name: product.name,
        categoryId: product.categoryId,
        imagePath: Value(product.imagePath),
        retailPriceCents: product.retailPrice.cents,
        wholesalePriceCents: product.wholesalePrice.cents,
        costPriceCents: product.costPrice.cents,
        stockQty: const Value(0),
        reorderLevel: Value(product.reorderLevel),
        status: Value(product.status),
        createdAt: now,
        updatedAt: now,
        localRev: rev,
        createdByDeviceId: deviceId,
      ));
    });
    return id;
  }

  @override
  Future<void> update(Product product) async {
    await _db.transaction(() async {
      final now = _clock.now().toIso8601String();
      final rev = await _syncMeta.nextLocalRev();
      await _dao.updateProduct(
        product.id,
        ProductsCompanion(
          sku: Value(product.sku),
          name: Value(product.name),
          categoryId: Value(product.categoryId),
          imagePath: Value(product.imagePath),
          retailPriceCents: Value(product.retailPrice.cents),
          wholesalePriceCents: Value(product.wholesalePrice.cents),
          costPriceCents: Value(product.costPrice.cents),
          reorderLevel: Value(product.reorderLevel),
          status: Value(product.status),
          updatedAt: Value(now),
          localRev: Value(rev),
          // stockQty deliberately omitted - see class doc comment.
        ),
      );
    });
  }

  @override
  Future<bool> delete(String id) async {
    return _db.transaction(() async {
      final now = _clock.now().toIso8601String();
      final rev = await _syncMeta.nextLocalRev();
      final rows = await _dao.softDelete(id, now, rev);
      return rows > 0;
    });
  }
}
