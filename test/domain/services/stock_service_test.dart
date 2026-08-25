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
import 'package:nexapos_mobile/domain/services/stock_service.dart';

void main() {
  late AppDatabase db;
  late StockService stockService;
  late ProductRepositoryImpl productRepository;
  late String productId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final syncMeta = SyncMetadataService(db);
    const clock = SystemClock();
    final idGen = UuidIdGenerator();

    final categoryRepository = CategoryRepositoryImpl(db, db.categoriesDao, syncMeta, clock, idGen);
    productRepository = ProductRepositoryImpl(db, db.productsDao, syncMeta, clock, idGen);
    stockService = StockService(db, db.productsDao, db.stockMovementsDao, syncMeta, clock, idGen);

    final category = Category(id: idGen.newId(), name: 'General', status: 'active');
    await categoryRepository.create(category);

    productId = await productRepository.create(Product(
      id: idGen.newId(),
      sku: 'TST-001',
      name: 'Test Widget',
      categoryId: category.id,
      retailPrice: const Money(10000),
      wholesalePrice: const Money(8000),
      costPrice: const Money(5000),
      stockQty: 999, // deliberately nonzero - create() must force this to 0
      reorderLevel: 5,
      status: 'active',
    ));
  });

  tearDown(() async {
    await db.close();
  });

  test('ProductRepository.create() always starts stock_qty at 0, ignoring the entity field', () async {
    final product = await productRepository.findById(productId);
    expect(product!.stockQty, 0);
  });

  test('applyMovement with a positive delta increases stock_qty and logs a movement', () async {
    final result = await stockService.applyMovement(
      productId: productId,
      movementType: 'purchase',
      delta: 20,
      note: 'Initial stock',
    );
    expect(result.isOk, isTrue);

    final product = await productRepository.findById(productId);
    expect(product!.stockQty, 20);

    final movements = await db.stockMovementsDao.forProduct(productId);
    expect(movements, hasLength(1));
    expect(movements.single.quantity, 20);
    expect(movements.single.movementType, 'purchase');
  });

  test('applyMovement rejects a delta that would take stock negative, with the exact quantity in the message', () async {
    await stockService.applyMovement(productId: productId, movementType: 'purchase', delta: 5);

    final result = await stockService.applyMovement(
      productId: productId,
      movementType: 'sale',
      delta: -10,
    );

    expect(result.isFailure, isTrue);
    result.when(
      ok: (_) => fail('expected failure'),
      failure: (message) => expect(message, 'Only 5 Test Widget in stock.'),
    );

    // Stock must be unchanged, and no movement row logged for the
    // rejected attempt - the guard and the log insert are atomic.
    final product = await productRepository.findById(productId);
    expect(product!.stockQty, 5);
    final movements = await db.stockMovementsDao.forProduct(productId);
    expect(movements, hasLength(1), reason: 'only the earlier successful +5 should be logged');
  });

  test('stock_qty is always exactly the sum of logged movements', () async {
    await stockService.applyMovement(productId: productId, movementType: 'purchase', delta: 50);
    await stockService.applyMovement(productId: productId, movementType: 'sale', delta: -12);
    await stockService.applyMovement(productId: productId, movementType: 'adjustment', delta: -3);
    await stockService.applyMovement(productId: productId, movementType: 'return', delta: 4);

    final product = await productRepository.findById(productId);
    final movements = await db.stockMovementsDao.forProduct(productId);
    final sum = movements.fold<int>(0, (total, m) => total + m.quantity);

    expect(product!.stockQty, sum);
    expect(product.stockQty, 50 - 12 - 3 + 4);
  });
}
