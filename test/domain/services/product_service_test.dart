import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/core/utils/id_generator.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Category, Product, User;
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/data/repositories/category_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/payment_record_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/product_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/sale_item_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/sale_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/user_repository_impl.dart';
import 'package:nexapos_mobile/domain/entities/cart_item.dart';
import 'package:nexapos_mobile/domain/entities/category.dart';
import 'package:nexapos_mobile/domain/entities/product.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/checkout_service.dart';
import 'package:nexapos_mobile/domain/services/product_service.dart';
import 'package:nexapos_mobile/domain/services/stock_service.dart';

void main() {
  late AppDatabase db;
  late ProductService productService;
  late ProductRepositoryImpl productRepository;
  late CheckoutService checkout;
  late String categoryId;
  late String userId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final syncMeta = SyncMetadataService(db);
    const clock = SystemClock();
    final idGen = UuidIdGenerator();

    final categoryRepository = CategoryRepositoryImpl(db, db.categoriesDao, syncMeta, clock, idGen);
    productRepository = ProductRepositoryImpl(db, db.productsDao, syncMeta, clock, idGen);
    productService = ProductService(productRepository, StockService(db, db.productsDao, db.stockMovementsDao, syncMeta, clock, idGen), idGen);
    final saleRepository = SaleRepositoryImpl(db, db.salesDao, syncMeta, clock, idGen);
    final saleItemRepository = SaleItemRepositoryImpl(db, db.saleItemsDao, syncMeta, clock, idGen);
    final paymentRecordRepository = PaymentRecordRepositoryImpl(db, db.paymentRecordsDao, syncMeta, clock, idGen);
    final stockService = StockService(db, db.productsDao, db.stockMovementsDao, syncMeta, clock, idGen);
    checkout = CheckoutService(
      db,
      saleRepository,
      saleItemRepository,
      paymentRecordRepository,
      productRepository,
      stockService,
      syncMeta,
      clock,
      idGen,
    );

    final category = Category(id: idGen.newId(), name: 'General', status: 'active');
    await categoryRepository.create(category);
    categoryId = category.id;

    final userRepository = UserRepositoryImpl(db, db.usersDao, syncMeta, clock, idGen);
    final user = User(
      id: idGen.newId(),
      role: UserRole.cashier,
      name: 'Cashier',
      username: 'cashier',
      passwordHash: 'irrelevant-for-this-test',
      status: 'active',
    );
    await userRepository.create(user);
    userId = user.id;
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> seedProduct({int stock = 10}) async {
    final id = await productRepository.create(Product(
      id: '',
      sku: 'SKU-${DateTime.now().microsecondsSinceEpoch}',
      name: 'Widget',
      categoryId: categoryId,
      retailPrice: const Money(10000),
      wholesalePrice: const Money(8000),
      costPrice: const Money(5000),
      stockQty: 0,
      reorderLevel: 2,
      status: 'active',
    ));
    if (stock != 0) {
      final stockService = StockService(db, db.productsDao, db.stockMovementsDao, SyncMetadataService(db), const SystemClock(), UuidIdGenerator());
      await stockService.applyMovement(productId: id, movementType: 'purchase', delta: stock);
    }
    return id;
  }

  test('delete() removes a never-sold product from getAll and findById', () async {
    final id = await seedProduct(stock: 0);

    final result = await productService.delete(id);

    expect(result.isOk, isTrue);
    expect(await productRepository.findById(id), isNull);
    expect(await productRepository.getAll(), isEmpty);
  });

  test('deleting a nonexistent product fails clearly instead of silently no-opping', () async {
    final result = await productService.delete('does-not-exist');

    expect(result.isFailure, isTrue);
    result.when(ok: (_) => fail('expected failure'), failure: (m) => expect(m, 'Product was not found.'));
  });

  test('deleting a product with stock movement history leaves that history intact', () async {
    final id = await seedProduct(stock: 20);
    final before = await db.stockMovementsDao.forProduct(id);
    expect(before, hasLength(1), reason: 'the initial-stock movement from seedProduct');

    await productService.delete(id);

    final after = await db.stockMovementsDao.forProduct(id);
    expect(after, hasLength(1));
    expect(after.single.quantity, 20);
  });

  test(
    'deleting a product that has already been sold does not affect that sale\'s line item - '
    'the whole point of soft-delete over a real DELETE',
    () async {
      final id = await seedProduct(stock: 5);
      final result = await checkout.checkout(
        cart: [CartItem(productId: id, name: 'Widget', unitPrice: const Money(10000), costPrice: const Money(5000), quantity: 2)],
        discount: const Money(0),
        saleType: 'retail',
        paymentMethod: 'cash',
        userId: userId,
      );
      expect(result.isOk, isTrue, reason: result.when(ok: (_) => '', failure: (m) => m));
      final saleId = result.when(ok: (sale) => sale.id, failure: (_) => '');

      final deleteResult = await productService.delete(id);
      expect(deleteResult.isOk, isTrue);
      expect(await productRepository.findById(id), isNull, reason: 'gone from normal product queries');

      // The actual promise made to the user: the historical sale still
      // reads back correctly, unaffected by the product no longer
      // existing in the active catalog - because sale_items snapshots
      // its own itemName/prices rather than joining back to products.
      final items = await db.saleItemsDao.forSale(saleId);
      expect(items, hasLength(1));
      expect(items.single.itemName, 'Widget');
      expect(items.single.quantity, 2);
      expect(items.single.unitPriceCents, 10000);
    },
  );
}
