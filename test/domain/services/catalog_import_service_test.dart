import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/core/utils/id_generator.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Category, Product;
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/data/repositories/category_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/product_repository_impl.dart';
import 'package:nexapos_mobile/domain/entities/category.dart';
import 'package:nexapos_mobile/domain/entities/product.dart';
import 'package:nexapos_mobile/domain/services/catalog_import_service.dart';
import 'package:nexapos_mobile/domain/services/stock_service.dart';

void main() {
  late AppDatabase db;
  late CatalogImportService importService;
  late ProductRepositoryImpl productRepository;
  late CategoryRepositoryImpl categoryRepository;
  late StockService stockService;
  late IdGenerator idGen;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final syncMeta = SyncMetadataService(db);
    const clock = SystemClock();
    idGen = UuidIdGenerator();

    categoryRepository = CategoryRepositoryImpl(db, db.categoriesDao, syncMeta, clock, idGen);
    productRepository = ProductRepositoryImpl(db, db.productsDao, syncMeta, clock, idGen);
    stockService = StockService(db, db.productsDao, db.stockMovementsDao, syncMeta, clock, idGen);
    importService = CatalogImportService(db, productRepository, categoryRepository, stockService, idGen);
  });

  tearDown(() async {
    await db.close();
  });

  test('imports new rows, auto-creating categories and logging a purchase movement', () async {
    final result = await importService.importRows([
      ['product', 'category', 'retail', 'wholesale', 'stock', 'cost_price'],
      ['Envelope A5', 'Stationery', '50', '40', '100', '30'],
      ['Blue Pen', 'Stationery', '20', '15', '200', '10'],
    ]);

    expect(result.isOk, isTrue);
    result.when(
      ok: (summary) {
        expect(summary.created, 2);
        expect(summary.updated, 0);
        expect(summary.skipped, 0);
        expect(summary.duplicatesMerged, 0);
      },
      failure: (m) => fail('expected success, got: $m'),
    );

    final products = await productRepository.getAll();
    expect(products, hasLength(2));
    final envelope = products.firstWhere((p) => p.name == 'Envelope A5');
    expect(envelope.retailPrice.toMajorDouble, 50);
    expect(envelope.stockQty, 100);
    expect(envelope.reorderLevel, 5);

    final categories = await categoryRepository.getAll();
    expect(categories, hasLength(1));
    expect(categories.single.name, 'Stationery');
  });

  test('recognizes header aliases used by the PHP export format', () async {
    final result = await importService.importRows([
      ['Item Name', 'Product Category', 'Selling Price', 'Wholesale Price', 'Qty', 'Buying Price'],
      ['Notebook', 'Stationery', '100', '80', '25', '60'],
    ]);

    expect(result.isOk, isTrue);
    final products = await productRepository.getAll();
    expect(products.single.name, 'Notebook');
    expect(products.single.stockQty, 25);
  });

  test('fails with a clear message when a required column is missing', () async {
    final result = await importService.importRows([
      ['product', 'category', 'retail', 'wholesale'],
      ['Notebook', 'Stationery', '100', '80'],
    ]);

    expect(result.isFailure, isTrue);
    result.when(
      ok: (_) => fail('expected failure'),
      failure: (message) => expect(message, contains('Missing required columns')),
    );
    expect(await productRepository.getAll(), isEmpty);
  });

  test('matching an existing product by name+category updates prices and tops up stock', () async {
    final category = Category(id: 'cat-1', name: 'Stationery', status: 'active');
    await categoryRepository.create(category);
    final productId = await productRepository.create(Product(
      id: idGen.newId(),
      sku: 'NOT-0001',
      name: 'notebook',
      categoryId: category.id,
      retailPrice: const Money(10000),
      wholesalePrice: const Money(8000),
      costPrice: const Money(6000),
      stockQty: 0,
      reorderLevel: 5,
      status: 'active',
    ));
    await stockService.applyMovement(productId: productId, movementType: 'purchase', delta: 5);

    final result = await importService.importRows([
      ['product', 'category', 'retail', 'wholesale', 'stock', 'cost_price'],
      // Different case on the product name - must still match.
      ['Notebook', 'Stationery', '120', '90', '10', '70'],
    ]);

    expect(result.isOk, isTrue);
    result.when(
      ok: (summary) {
        expect(summary.created, 0);
        expect(summary.updated, 1);
      },
      failure: (m) => fail('expected success, got: $m'),
    );

    final products = await productRepository.getAll();
    expect(products, hasLength(1));
    expect(products.single.retailPrice.toMajorDouble, 120);
    // Started at 5 (seeded below), import adds 10 more.
    expect(products.single.stockQty, 15);
  });

  test('duplicate rows for the same product+category are merged: stock summed, price latest-wins', () async {
    final result = await importService.importRows([
      ['product', 'category', 'retail', 'wholesale', 'stock', 'cost_price'],
      ['Notebook', 'Stationery', '100', '80', '10', '60'],
      ['notebook', 'stationery', '110', '85', '5', '65'],
    ]);

    expect(result.isOk, isTrue);
    result.when(
      ok: (summary) {
        expect(summary.created, 1);
        expect(summary.duplicatesMerged, 1);
      },
      failure: (m) => fail('expected success, got: $m'),
    );

    final product = (await productRepository.getAll()).single;
    expect(product.stockQty, 15);
    expect(product.retailPrice.toMajorDouble, 110);
  });

  test('blank optional columns default to zero instead of failing', () async {
    final result = await importService.importRows([
      ['product', 'category', 'retail', 'wholesale', 'stock', 'cost_price'],
      ['Notebook', 'Stationery', '', '', '', ''],
    ]);

    expect(result.isOk, isTrue);
    final product = (await productRepository.getAll()).single;
    expect(product.retailPrice.cents, 0);
    expect(product.stockQty, 0);
  });

  test('a non-numeric price aborts the whole import with nothing written', () async {
    final result = await importService.importRows([
      ['product', 'category', 'retail', 'wholesale', 'stock', 'cost_price'],
      ['Notebook', 'Stationery', 'free', '80', '10', '60'],
    ]);

    expect(result.isFailure, isTrue);
    result.when(
      ok: (_) => fail('expected failure'),
      failure: (message) => expect(message, contains('numeric')),
    );
    expect(await productRepository.getAll(), isEmpty);
    expect(await categoryRepository.getAll(), isEmpty);
  });

  test('a row missing only one of product/category aborts before writing anything', () async {
    final result = await importService.importRows([
      ['product', 'category', 'retail', 'wholesale', 'stock', 'cost_price'],
      ['Notebook', '', '100', '80', '10', '60'],
    ]);

    expect(result.isFailure, isTrue);
    expect(await productRepository.getAll(), isEmpty);
  });
}
