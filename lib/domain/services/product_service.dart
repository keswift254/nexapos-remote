import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../core/result.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/money.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';
import 'sku_generator.dart';
import 'stock_service.dart';

part 'product_service.g.dart';

@Riverpod(keepAlive: true)
ProductService productService(Ref ref) {
  return ProductService(
    ref.watch(productRepositoryProvider),
    ref.watch(stockServiceProvider),
    ref.watch(idGeneratorProvider),
  );
}

class ProductService {
  final ProductRepository _repository;
  final StockService _stockService;
  final IdGenerator _idGenerator;

  ProductService(this._repository, this._stockService, this._idGenerator);

  Future<List<Product>> getAll() => _repository.getAll();

  /// Creates the product with stock_qty starting at 0, then - only if
  /// [initialStockQty] is nonzero - routes the initial quantity through
  /// StockService.applyMovement(type: 'purchase') so it's never a bare
  /// insert. PHP's equivalent path silently skips logging a movement
  /// for a product's starting quantity; this never does.
  Future<Result<Product>> create({
    required String name,
    required String categoryId,
    required Money retailPrice,
    required Money wholesalePrice,
    required Money costPrice,
    int reorderLevel = 0,
    int initialStockQty = 0,
    String? imagePath,
    String? userId,
  }) async {
    if (name.trim().isEmpty) return const Result.failure('Enter a product name.');
    if (categoryId.isEmpty) return const Result.failure('Select a category.');
    if (retailPrice.isNegative || retailPrice.isZero) {
      return const Result.failure('Retail price must be greater than 0.');
    }

    final existing = await _repository.findByNameAndCategory(name.trim(), categoryId);
    if (existing != null) {
      return const Result.failure('A product with that name already exists in this category.');
    }

    final sku = await SkuGenerator.generate(name, _repository, _idGenerator);
    final product = Product(
      id: _idGenerator.newId(),
      sku: sku,
      name: name.trim(),
      categoryId: categoryId,
      imagePath: imagePath,
      retailPrice: retailPrice,
      wholesalePrice: wholesalePrice,
      costPrice: costPrice,
      stockQty: 0,
      reorderLevel: reorderLevel,
      status: 'active',
    );
    final id = await _repository.create(product);

    if (initialStockQty != 0) {
      final movementResult = await _stockService.applyMovement(
        productId: id,
        movementType: 'purchase',
        delta: initialStockQty,
        note: 'Initial stock',
        userId: userId,
      );
      if (movementResult.isFailure) {
        return movementResult.when(
          ok: (_) => Result.ok(product.copyWith(id: id)),
          failure: Result.failure,
        );
      }
    }

    final created = await _repository.findById(id);
    return Result.ok(created ?? product.copyWith(id: id));
  }

  Future<Result<Product>> update({
    required String id,
    required String name,
    required String categoryId,
    required Money retailPrice,
    required Money wholesalePrice,
    required Money costPrice,
    required int reorderLevel,
    String? imagePath,
  }) async {
    if (name.trim().isEmpty) return const Result.failure('Enter a product name.');
    final existing = await _repository.findById(id);
    if (existing == null) return const Result.failure('Product not found.');

    final nameOwner = await _repository.findByNameAndCategory(name.trim(), categoryId);
    if (nameOwner != null && nameOwner.id != id) {
      return const Result.failure('A product with that name already exists in this category.');
    }

    final updated = existing.copyWith(
      name: name.trim(),
      categoryId: categoryId,
      retailPrice: retailPrice,
      wholesalePrice: wholesalePrice,
      costPrice: costPrice,
      reorderLevel: reorderLevel,
      imagePath: imagePath,
    );
    await _repository.update(updated);
    return Result.ok(updated);
  }

  Future<Result<void>> setActive(String id, bool active) async {
    final existing = await _repository.findById(id);
    if (existing == null) return const Result.failure('Product not found.');
    await _repository.update(existing.copyWith(status: active ? 'active' : 'disabled'));
    return const Result.ok(null);
  }

  Future<Result<void>> delete(String id) async {
    final deleted = await _repository.delete(id);
    return deleted
        ? const Result.ok(null)
        : const Result.failure('Product was not found.');
  }
}
