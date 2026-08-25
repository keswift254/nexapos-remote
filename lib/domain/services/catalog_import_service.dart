import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../core/result.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/money.dart';
import '../../data/local/database.dart' hide Category, Product;
import '../../data/repositories/category_repository_impl.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../entities/category.dart';
import '../entities/product.dart';
import '../repositories/category_repository.dart';
import '../repositories/product_repository.dart';
import 'sku_generator.dart';
import 'stock_service.dart';

part 'catalog_import_service.g.dart';

@Riverpod(keepAlive: true)
CatalogImportService catalogImportService(Ref ref) {
  return CatalogImportService(
    ref.watch(appDatabaseProvider),
    ref.watch(productRepositoryProvider),
    ref.watch(categoryRepositoryProvider),
    ref.watch(stockServiceProvider),
    ref.watch(idGeneratorProvider),
  );
}

const _requiredColumns = ['product', 'category', 'retail', 'wholesale', 'stock', 'cost_price'];
const _zeroDefaultColumns = ['retail', 'wholesale', 'stock', 'cost_price'];
const _requiredColumnsMessage = 'product, category, retail, wholesale, stock, and cost price';

class CatalogImportSummary {
  final int created;
  final int updated;
  final int skipped;
  final int duplicatesMerged;

  const CatalogImportSummary({
    required this.created,
    required this.updated,
    required this.skipped,
    required this.duplicatesMerged,
  });
}

class _ImportAbort implements Exception {
  final String message;
  const _ImportAbort(this.message);
}

/// Dart port of PHP's `InventoryExcelService::import()` - same required
/// columns, same header aliases, same duplicate-row merge, same
/// create-vs-update-by-name+category decision. Takes a plain grid
/// (header row + data rows) rather than a file path, so it stays
/// file-format-agnostic and unit-testable without touching disk; see
/// XlsxCatalogReader for the adapter that turns a real .xlsx into this
/// shape. The one deliberate deviation from PHP: category is a real FK
/// here (see products_table.dart), so "ensure the category exists" means
/// find-or-create-by-name, returning an id, rather than upserting a
/// free-text column.
class CatalogImportService {
  final AppDatabase _db;
  final ProductRepository _productRepository;
  final CategoryRepository _categoryRepository;
  final StockService _stockService;
  final IdGenerator _idGenerator;

  CatalogImportService(
    this._db,
    this._productRepository,
    this._categoryRepository,
    this._stockService,
    this._idGenerator,
  );

  Future<Result<CatalogImportSummary>> importRows(
    List<List<String>> sheetRows, {
    String? userId,
  }) async {
    if (sheetRows.isEmpty) {
      return const Result.failure('The import file has no item rows.');
    }

    final keys = sheetRows.first.map(_normalizeHeader).toList();
    final missing = _requiredColumns.where((c) => !keys.contains(c)).toList();
    if (missing.isNotEmpty) {
      return const Result.failure('Missing required columns. Ensure you have $_requiredColumnsMessage.');
    }

    final dataRows = sheetRows.skip(1).map((values) => _mapRow(keys, values)).toList();
    if (dataRows.isEmpty) {
      return const Result.failure('The import file has no item rows.');
    }

    final List<Map<String, String>> merged;
    final int duplicates;
    try {
      final result = _mergeDuplicateRows(dataRows);
      merged = result.$1;
      duplicates = result.$2;
    } on _ImportAbort catch (e) {
      return Result.failure(e.message);
    }

    var created = 0;
    var updated = 0;
    var skipped = 0;

    try {
      await _db.transaction(() async {
        for (final row in merged) {
          final product = (row['product'] ?? '').trim();
          final category = (row['category'] ?? '').trim();
          if (product.isEmpty || category.isEmpty) {
            skipped++;
            continue;
          }

          final retail = _parseMoney(row['retail']);
          final wholesale = _parseMoney(row['wholesale']);
          final costPrice = _parseMoney(row['cost_price']);
          final stock = _parseStock(row['stock']);

          final categoryId = await _ensureCategory(category);
          final existing = await _productRepository.findByNameAndCategory(product, categoryId);

          if (existing != null) {
            await _productRepository.update(existing.copyWith(
              retailPrice: retail,
              wholesalePrice: wholesale,
              costPrice: costPrice,
              status: 'active',
            ));
            if (stock != 0) {
              await _applyStock(existing.id, 'adjustment', stock, userId);
            }
            updated++;
          } else {
            final sku = await SkuGenerator.generate(product, _productRepository, _idGenerator);
            final id = await _productRepository.create(Product(
              id: _idGenerator.newId(),
              sku: sku,
              name: product,
              categoryId: categoryId,
              retailPrice: retail,
              wholesalePrice: wholesale,
              costPrice: costPrice,
              stockQty: 0,
              reorderLevel: 5,
              status: 'active',
            ));
            if (stock != 0) {
              await _applyStock(id, 'purchase', stock, userId);
            }
            created++;
          }
        }
      });
    } on _ImportAbort catch (e) {
      return Result.failure(e.message);
    }

    return Result.ok(CatalogImportSummary(
      created: created,
      updated: updated,
      skipped: skipped,
      duplicatesMerged: duplicates,
    ));
  }

  Future<void> _applyStock(String productId, String movementType, int stock, String? userId) async {
    final movement = await _stockService.applyMovement(
      productId: productId,
      movementType: movementType,
      delta: stock,
      note: 'Inventory import',
      userId: userId,
    );
    if (movement.isFailure) {
      movement.when(ok: (_) {}, failure: (message) => throw _ImportAbort(message));
    }
  }

  Future<String> _ensureCategory(String name) async {
    final existing = await _categoryRepository.findByName(name);
    if (existing != null) {
      if (!existing.isActive) {
        await _categoryRepository.update(existing.copyWith(status: 'active'));
      }
      return existing.id;
    }
    final category = Category(id: _idGenerator.newId(), name: name, status: 'active');
    await _categoryRepository.create(category);
    return category.id;
  }

  /// Mirrors PHP's mergeDuplicateRows(): a row with both product and
  /// category blank is a spacer row and is dropped; a row with exactly
  /// one of them blank is a real data problem and aborts the whole
  /// import before anything is written. Rows sharing the same
  /// product+category (case-insensitive) sum their stock and take the
  /// latest occurrence's prices.
  (List<Map<String, String>>, int) _mergeDuplicateRows(List<Map<String, String>> rows) {
    final merged = <String, Map<String, String>>{};
    var duplicates = 0;

    for (final rawRow in rows) {
      final row = Map<String, String>.from(rawRow);
      final product = (row['product'] ?? '').trim();
      final category = (row['category'] ?? '').trim();
      if (product.isEmpty && category.isEmpty) continue;

      for (final column in _requiredColumns) {
        if (!_isBlank(row[column])) continue;
        if (_zeroDefaultColumns.contains(column)) {
          row[column] = '0';
          continue;
        }
        throw const _ImportAbort('Ensure you have $_requiredColumnsMessage filled.');
      }

      final key = '${product.toLowerCase()}|${category.toLowerCase()}';
      final existing = merged[key];
      if (existing == null) {
        merged[key] = row;
        continue;
      }
      final existingStock = _parseStock(existing['stock']);
      final rowStock = _parseStock(row['stock']);
      existing['stock'] = (existingStock + rowStock).toString();
      existing['retail'] = row['retail']!;
      existing['wholesale'] = row['wholesale']!;
      existing['cost_price'] = row['cost_price']!;
      duplicates++;
    }

    return (merged.values.toList(), duplicates);
  }

  static bool _isBlank(String? value) => value == null || value.trim().isEmpty;

  /// Mirrors PHP's decimal(): blank -> 0, strips commas/"KES", clamps
  /// negative to 0. Throws on a non-numeric value, aborting the import.
  static Money _parseMoney(String? raw) {
    if (_isBlank(raw)) return const Money.zero();
    final cleaned = raw!.trim().replaceAll(',', '').replaceAll(RegExp('KES', caseSensitive: false), '').trim();
    final value = double.tryParse(cleaned);
    if (value == null) {
      throw const _ImportAbort('Retail, wholesale, stock, and cost price values must be numeric.');
    }
    return Money.fromMajor(value < 0 ? 0 : value);
  }

  /// Mirrors PHP's integer(): blank -> 0, strips commas, clamps negative
  /// to 0, rounds to the nearest whole unit.
  static int _parseStock(String? raw) {
    if (_isBlank(raw)) return 0;
    final cleaned = raw!.trim().replaceAll(',', '');
    final value = double.tryParse(cleaned);
    if (value == null) {
      throw const _ImportAbort('Stock values must be numeric.');
    }
    return value < 0 ? 0 : value.round();
  }

  static String _normalizeHeader(String header) {
    final key = header.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    switch (key) {
      case 'product':
      case 'item':
      case 'item name':
      case 'name':
        return 'product';
      case 'category':
      case 'product category':
        return 'category';
      case 'retail':
      case 'retail price':
      case 'selling price':
        return 'retail';
      case 'wholesale':
      case 'wholesale price':
        return 'wholesale';
      case 'cost':
      case 'cost price':
      case 'buying price':
        return 'cost_price';
      case 'stock':
      case 'stock qty':
      case 'stock quantity':
      case 'quantity':
      case 'qty':
        return 'stock';
      default:
        return key;
    }
  }

  static Map<String, String> _mapRow(List<String> keys, List<String> values) {
    final row = <String, String>{};
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      if (key.isEmpty) continue;
      row[key] = i < values.length ? values[i] : '';
    }
    return row;
  }
}
