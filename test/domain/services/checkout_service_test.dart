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
import 'package:nexapos_mobile/domain/services/stock_service.dart';

void main() {
  late AppDatabase db;
  late CheckoutService checkout;
  late ProductRepositoryImpl productRepository;
  late SaleRepositoryImpl saleRepository;
  late SaleItemRepositoryImpl saleItemRepository;
  late PaymentRecordRepositoryImpl paymentRecordRepository;
  late String categoryId;
  late String productId;
  late String userId;

  Future<String> seedProduct({int stock = 10, int priceCents = 10000}) async {
    final id = await productRepository.create(Product(
      id: '',
      sku: 'SKU-${DateTime.now().microsecondsSinceEpoch}',
      name: 'Widget',
      categoryId: categoryId,
      retailPrice: Money(priceCents),
      wholesalePrice: Money((priceCents * 0.8).round()),
      costPrice: Money((priceCents * 0.5).round()),
      stockQty: 0,
      reorderLevel: 2,
      status: 'active',
    ));
    if (stock != 0) {
      final stockService = StockService(
        db,
        db.productsDao,
        db.stockMovementsDao,
        SyncMetadataService(db),
        const SystemClock(),
        UuidIdGenerator(),
      );
      await stockService.applyMovement(productId: id, movementType: 'purchase', delta: stock);
    }
    return id;
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final syncMeta = SyncMetadataService(db);
    const clock = SystemClock();
    final idGen = UuidIdGenerator();

    final categoryRepository = CategoryRepositoryImpl(db, db.categoriesDao, syncMeta, clock, idGen);
    productRepository = ProductRepositoryImpl(db, db.productsDao, syncMeta, clock, idGen);
    saleRepository = SaleRepositoryImpl(db, db.salesDao, syncMeta, clock, idGen);
    saleItemRepository = SaleItemRepositoryImpl(db, db.saleItemsDao, syncMeta, clock, idGen);
    paymentRecordRepository = PaymentRecordRepositoryImpl(db, db.paymentRecordsDao, syncMeta, clock, idGen);
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
    productId = await seedProduct();

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

  test('cash sale records paid immediately, decrements stock, and logs a sale movement', () async {
    final result = await checkout.checkout(
      cart: [CartItem(productId: productId, name: 'Widget', unitPrice: const Money(10000), costPrice: const Money(5000), quantity: 3)],
      discount: const Money.zero(),
      saleType: 'retail',
      paymentMethod: 'cash',
      userId: userId,
    );

    expect(result.isOk, isTrue);
    late String saleId;
    result.when(
      ok: (sale) {
        saleId = sale.id;
        expect(sale.status, 'paid');
        expect(sale.total.cents, 30000);
        expect(sale.customerName, 'Walk-in customer');
      },
      failure: (m) => fail('expected success, got: $m'),
    );

    final product = await productRepository.findById(productId);
    expect(product!.stockQty, 7);

    final movements = await db.stockMovementsDao.forProduct(productId);
    expect(movements, hasLength(2)); // seed purchase + this sale
    expect(movements.first.movementType, 'sale');
    expect(movements.first.quantity, -3);

    final items = await saleItemRepository.forSale(saleId);
    expect(items, hasLength(1));
    expect(items.single.lineTotal.cents, 30000);

    final paymentRecord = await paymentRecordRepository.forSale(saleId);
    expect(paymentRecord, isNull, reason: 'cash sales never get a payment_records row');
  });

  test('manual items skip stock checks entirely', () async {
    final result = await checkout.checkout(
      cart: [CartItem(name: 'Custom engraving', unitPrice: const Money(500), costPrice: const Money.zero(), quantity: 2)],
      discount: const Money.zero(),
      saleType: 'retail',
      paymentMethod: 'cash',
      userId: userId,
    );

    expect(result.isOk, isTrue);
    result.when(ok: (sale) => expect(sale.total.cents, 1000), failure: (m) => fail(m));
  });

  test('rejects a cart that would oversell, with the exact available count in the message', () async {
    final result = await checkout.checkout(
      cart: [CartItem(productId: productId, name: 'Widget', unitPrice: const Money(10000), costPrice: const Money(5000), quantity: 999)],
      discount: const Money.zero(),
      saleType: 'retail',
      paymentMethod: 'cash',
      userId: userId,
    );

    expect(result.isFailure, isTrue);
    result.when(ok: (_) => fail('expected failure'), failure: (m) => expect(m, 'Only 10 Widget in stock.'));
    final product = await productRepository.findById(productId);
    expect(product!.stockQty, 10, reason: 'a rejected checkout must not touch stock');
  });

  test('rejects a completely out-of-stock product with a distinct message', () async {
    final outOfStockId = await seedProduct(stock: 0);
    // seedProduct with stock:0 skips the purchase movement, so stock_qty stays 0.
    final result = await checkout.checkout(
      cart: [CartItem(productId: outOfStockId, name: 'Widget', unitPrice: const Money(10000), costPrice: const Money(5000), quantity: 1)],
      discount: const Money.zero(),
      saleType: 'retail',
      paymentMethod: 'cash',
      userId: userId,
    );

    expect(result.isFailure, isTrue);
    result.when(ok: (_) => fail('expected failure'), failure: (m) => expect(m, 'Widget is out of stock.'));
  });

  test('discount is clamped to the subtotal, never producing a negative total', () async {
    final result = await checkout.checkout(
      cart: [CartItem(productId: productId, name: 'Widget', unitPrice: const Money(10000), costPrice: const Money(5000), quantity: 1)],
      discount: const Money(50000),
      saleType: 'retail',
      paymentMethod: 'cash',
      userId: userId,
    );

    result.when(
      ok: (sale) {
        expect(sale.discount.cents, 10000);
        expect(sale.total.cents, 0);
      },
      failure: (m) => fail(m),
    );
  });

  test('duplicate cart lines for the same product are merged: quantity summed, latest price wins', () async {
    final result = await checkout.checkout(
      cart: [
        CartItem(productId: productId, name: 'Widget', unitPrice: const Money(10000), costPrice: const Money(5000), quantity: 2),
        CartItem(productId: productId, name: 'Widget', unitPrice: const Money(9000), costPrice: const Money(5000), quantity: 1),
      ],
      discount: const Money.zero(),
      saleType: 'retail',
      paymentMethod: 'cash',
      userId: userId,
    );

    result.when(
      ok: (sale) => expect(sale.total.cents, 9000 * 3), // merged qty 3 at the latest price 9000
      failure: (m) => fail(m),
    );
  });

  test('mpesa sale records a payment_records row with the cashier note', () async {
    final result = await checkout.checkout(
      cart: [CartItem(productId: productId, name: 'Widget', unitPrice: const Money(10000), costPrice: const Money(5000), quantity: 1)],
      discount: const Money.zero(),
      customerPhone: '0712345678',
      saleType: 'retail',
      paymentMethod: 'mpesa',
      referenceNote: 'QWE123 confirmation',
      userId: userId,
    );

    late String saleId;
    result.when(
      ok: (sale) {
        saleId = sale.id;
        expect(sale.customerPhone, '0712345678');
      },
      failure: (m) => fail(m),
    );

    final record = await paymentRecordRepository.forSale(saleId);
    expect(record, isNotNull);
    expect(record!.status, 'paid');
    expect(record.referenceNote, 'QWE123 confirmation');
  });

  test('an empty cart is rejected before anything is written', () async {
    final result = await checkout.checkout(
      cart: const [],
      discount: const Money.zero(),
      saleType: 'retail',
      paymentMethod: 'cash',
      userId: userId,
    );
    expect(result.isFailure, isTrue);
  });

  test('checkout() refuses paystack - it must go through beginPaystackSale', () async {
    final result = await checkout.checkout(
      cart: [CartItem(productId: productId, name: 'Widget', unitPrice: const Money(10000), costPrice: const Money(5000), quantity: 1)],
      discount: const Money.zero(),
      saleType: 'retail',
      paymentMethod: 'paystack',
      userId: userId,
    );
    expect(result.isFailure, isTrue);
  });

  test('beginPaystackSale reserves stock and records the sale as pending', () async {
    final saleNumber = await checkout.generateSaleNumber();
    final result = await checkout.beginPaystackSale(
      cart: [CartItem(productId: productId, name: 'Widget', unitPrice: const Money(10000), costPrice: const Money(5000), quantity: 4)],
      discount: const Money.zero(),
      saleType: 'retail',
      userId: userId,
      saleNumber: saleNumber,
      paystackReference: saleNumber,
    );

    expect(result.isOk, isTrue);
    result.when(ok: (sale) => expect(sale.status, 'pending'), failure: (m) => fail(m));

    final product = await productRepository.findById(productId);
    expect(product!.stockQty, 6, reason: 'stock is reserved immediately, before payment confirms');
  });

  test('finalizePaystackSale marks the sale and payment record paid, idempotently', () async {
    final saleNumber = await checkout.generateSaleNumber();
    final beginResult = await checkout.beginPaystackSale(
      cart: [CartItem(productId: productId, name: 'Widget', unitPrice: const Money(10000), costPrice: const Money(5000), quantity: 1)],
      discount: const Money.zero(),
      saleType: 'retail',
      userId: userId,
      saleNumber: saleNumber,
      paystackReference: saleNumber,
    );
    late String saleId;
    beginResult.when(ok: (sale) => saleId = sale.id, failure: (m) => fail(m));

    final finalized = await checkout.finalizePaystackSale(saleId);
    finalized.when(ok: (sale) => expect(sale.status, 'paid'), failure: (m) => fail(m));
    final record = await paymentRecordRepository.forSale(saleId);
    expect(record!.status, 'paid');

    // Calling it again must not throw or double-process.
    final secondCall = await checkout.finalizePaystackSale(saleId);
    expect(secondCall.isOk, isTrue);
  });

  test('cancelPaystackSale restores stock and marks the sale cancelled, idempotently', () async {
    final saleNumber = await checkout.generateSaleNumber();
    final beginResult = await checkout.beginPaystackSale(
      cart: [CartItem(productId: productId, name: 'Widget', unitPrice: const Money(10000), costPrice: const Money(5000), quantity: 4)],
      discount: const Money.zero(),
      saleType: 'retail',
      userId: userId,
      saleNumber: saleNumber,
      paystackReference: saleNumber,
    );
    late String saleId;
    beginResult.when(ok: (sale) => saleId = sale.id, failure: (m) => fail(m));

    var product = await productRepository.findById(productId);
    expect(product!.stockQty, 6);

    final cancelled = await checkout.cancelPaystackSale(saleId);
    expect(cancelled.isOk, isTrue);

    product = await productRepository.findById(productId);
    expect(product!.stockQty, 10, reason: 'the reserved stock must be fully returned');

    final sale = await saleRepository.findById(saleId);
    expect(sale!.status, 'cancelled');
    final record = await paymentRecordRepository.forSale(saleId);
    expect(record!.status, 'failed');

    // Calling it again must not restore stock a second time.
    await checkout.cancelPaystackSale(saleId);
    product = await productRepository.findById(productId);
    expect(product!.stockQty, 10);
  });
}
