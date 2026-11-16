import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/result.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/core/utils/id_generator.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart'
    hide Category, Product, User, Sale, SaleItem, PaymentRecord;
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
import 'package:nexapos_mobile/domain/entities/sale.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/auth_service.dart';
import 'package:nexapos_mobile/domain/services/checkout_service.dart';
import 'package:nexapos_mobile/domain/services/refund_service.dart';
import 'package:nexapos_mobile/domain/services/sensitive_action_service.dart';
import 'package:nexapos_mobile/domain/services/stock_service.dart';

import '../../support/fake_secure_storage.dart';

class _Clock implements Clock {
  DateTime value = DateTime.utc(2026, 11, 16, 9);
  @override
  DateTime now() => value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _Clock clock;
  late CheckoutService checkout;
  late RefundService refunds;
  late SensitiveActionService security;
  late ProductRepositoryImpl products;
  late SaleRepositoryImpl sales;
  late SaleItemRepositoryImpl saleItems;
  late PaymentRecordRepositoryImpl payments;
  late StockService stock;
  late String widgetId; // price 100.00, cost 60.00
  late String gadgetId; // price 250.50, cost 150.00
  late String categoryId;
  late User owner;
  late User manager;
  late User cashier;
  late User? current;
  late int syncs;

  Future<String> seedProduct(String name, int price, int cost, int qty) async {
    final id = await products.create(
      Product(
        id: '',
        sku: 'SKU-$name',
        name: name,
        categoryId: categoryId,
        retailPrice: Money(price),
        wholesalePrice: Money(price),
        costPrice: Money(cost),
        stockQty: 0,
        reorderLevel: 2,
        status: 'active',
      ),
    );
    await stock.applyMovement(
      productId: id,
      movementType: 'purchase',
      delta: qty,
    );
    return id;
  }

  Future<int> stockOf(String id) async => (await products.findById(id))!.stockQty;

  CartItem line(String? productId, String name, int price, int cost, int qty) =>
      CartItem(
        productId: productId,
        name: name,
        unitPrice: Money(price),
        costPrice: Money(cost),
        quantity: qty,
      );

  Future<Sale> sell(
    List<CartItem> cart, {
    String method = 'cash',
    int discount = 0,
  }) async {
    final result = await checkout.checkout(
      cart: cart,
      discount: Money(discount),
      saleType: 'retail',
      paymentMethod: method,
      userId: cashier.id,
      customerName: 'Mama Njeri',
      customerPhone: method == 'cash' ? '' : '0712345678',
    );
    return result.when(ok: (s) => s, failure: (m) => throw StateError(m));
  }

  /// A split sale: [cash] collected up front, the rest by M-Pesa prompt (as the cart screen does it).
  Future<Sale> sellSplit(List<CartItem> cart, int cash, {int discount = 0}) async {
    final begun = await checkout.beginPaystackSale(
      cart: cart,
      discount: Money(discount),
      saleType: 'retail',
      userId: cashier.id,
      saleNumber: await checkout.generateSaleNumber(),
      paystackReference: 'ref-${DateTime.now().microsecondsSinceEpoch}',
      cashReceived: Money(cash),
    );
    final sale = begun.when(ok: (s) => s, failure: (m) => throw StateError(m));
    await checkout.finalizePaystackSale(sale.id);
    return (await sales.findById(sale.id))!;
  }

  Future<ActionApproval> approvalFor(User who, {Set<UserRole>? roles}) async {
    current = who;
    return security.approveWithPasswordOnly(
      username: who.username,
      password: 'long-password',
      action: refundApprovalAction,
      roles: roles ?? refundRoles,
    );
  }

  Future<Result<Sale>> refundIt(
    Sale sale,
    List<RefundChoice> choices, {
    String reason = 'Customer changed their mind',
    User? by,
  }) async {
    final approval = await approvalFor(by ?? manager);
    return refunds.refund(
      saleId: sale.id,
      choices: choices,
      reason: reason,
      approval: approval,
    );
  }

  Future<Sale> mustRefund(Sale sale, List<RefundChoice> choices, {String reason = 'Faulty'}) async {
    final result = await refundIt(sale, choices, reason: reason);
    return result.when(ok: (s) => s, failure: (m) => throw StateError('refund failed: $m'));
  }

  Future<List<RefundChoice>> everything(String saleId, {bool restock = true}) async {
    final source = (await refunds.refundableSale(saleId))!;
    return [
      for (final l in source.lines)
        if (l.remaining > 0) RefundChoice(itemId: l.item.id, quantity: l.remaining, restock: restock),
    ];
  }

  String failureOf(Result<Object?> r) =>
      r.when(ok: (_) => fail('expected a failure'), failure: (m) => m);

  setUp(() async {
    installFakeSecureStorage();
    syncs = 0;
    db = AppDatabase(NativeDatabase.memory());
    clock = _Clock();
    final syncMeta = SyncMetadataService(db);
    final idGen = UuidIdGenerator();
    products = ProductRepositoryImpl(db, db.productsDao, syncMeta, clock, idGen);
    sales = SaleRepositoryImpl(db, db.salesDao, syncMeta, clock, idGen);
    saleItems = SaleItemRepositoryImpl(db, db.saleItemsDao, syncMeta, clock, idGen);
    payments = PaymentRecordRepositoryImpl(db, db.paymentRecordsDao, syncMeta, clock, idGen);
    stock = StockService(db, db.productsDao, db.stockMovementsDao, syncMeta, clock, idGen);
    checkout = CheckoutService(db, sales, saleItems, payments, products, stock, syncMeta, clock, idGen);

    categoryId = idGen.newId();
    await CategoryRepositoryImpl(db, db.categoriesDao, syncMeta, clock, idGen)
        .create(Category(id: categoryId, name: 'General', status: 'active'));
    widgetId = await seedProduct('Widget', 10000, 6000, 20);
    gadgetId = await seedProduct('Gadget', 25050, 15000, 20);

    final users = UserRepositoryImpl(db, db.usersDao, syncMeta, clock, idGen);
    final auth = AuthService(users, idGen);
    Future<User> make(String name, UserRole role) async => (await auth.createUser(
          name: name,
          username: name.toLowerCase(),
          password: 'long-password',
          role: role,
        ))
            .when(ok: (u) => u, failure: (m) => throw StateError(m));
    owner = await make('Owner', UserRole.admin);
    manager = await make('Manager', UserRole.manager);
    cashier = await make('Cashier', UserRole.cashier);
    current = manager;

    security = SensitiveActionService(
      auth,
      const FlutterSecureStorage(),
      clock,
      () => current?.id,
    );
    refunds = RefundService(
      db,
      sales,
      saleItems,
      payments,
      products,
      stock,
      security,
      idGen,
      newSaleNumber: checkout.generateSaleNumber,
      currentUser: () => current,
      onRefundCommitted: () async => syncs++,
    );
  });

  tearDown(() => db.close());

  group('what a refund records', () {
    test('a whole cash sale: its own negative sale, negative lines, stock back, the sale itself untouched', () async {
      final sale = await sell([
        line(widgetId, 'Widget', 10000, 6000, 2),
        line(gadgetId, 'Gadget', 25050, 15000, 1),
      ]);
      expect(sale.total.cents, 45050);
      expect(await stockOf(widgetId), 18);
      final before = await db.salesDao.findById(sale.id);

      final refund = await mustRefund(sale, await everything(sale.id), reason: 'Wrong goods');

      expect(refund.saleType, 'refund');
      expect(refund.isRefund, isTrue);
      expect(refund.status, 'paid');
      expect(refund.refundOfSaleId, sale.id);
      expect(refund.refundReason, 'Wrong goods');
      expect(refund.userId, manager.id, reason: 'the person who refunded, not the cashier');
      expect(refund.paymentMethod, 'cash');
      expect(refund.customerName, 'Mama Njeri');
      expect(refund.subtotal.cents, -45050);
      expect(refund.discount.cents, 0);
      expect(refund.total.cents, -45050);
      expect(refund.cashReceived, isNull);
      expect(refund.saleNumber, isNot(sale.saleNumber));

      final lines = await saleItems.forSale(refund.id);
      expect(lines, hasLength(2));
      final original = await saleItems.forSale(sale.id);
      for (final l in lines) {
        final from = original.firstWhere((o) => o.id == l.refundOfItemId);
        expect(l.quantity, -from.quantity);
        expect(l.unitPrice, from.unitPrice);
        expect(l.costPrice, from.costPrice, reason: 'restocked, so the cost comes back too');
        expect(l.lineTotal.cents, -from.lineTotal.cents);
        expect(l.itemName, from.itemName);
        expect(l.productId, from.productId);
      }

      expect(await stockOf(widgetId), 20);
      expect(await stockOf(gadgetId), 20);
      final back = (await db.stockMovementsDao.forProduct(widgetId)).singleWhere((m) => m.movementType == 'return');
      expect(back.movementType, 'return');
      expect(back.quantity, 2);
      expect(back.note, 'Refund ${refund.saleNumber}');
      expect(back.userId, manager.id);

      expect(await payments.forSale(refund.id), isNull, reason: 'cash has no payment record, as with a cash sale');

      final after = await db.salesDao.findById(sale.id);
      expect(after!.status, 'paid');
      expect(after.localRev, before!.localRev, reason: 'the original sale is never edited');
      expect(after.updatedAt, before.updatedAt);
      expect(syncs, 1);
    });

    test('an M-Pesa sale gets a negative payment record that names the sale it refunds', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 1)], method: 'mpesa_manual');
      final refund = await mustRefund(sale, await everything(sale.id));
      expect(refund.paymentMethod, 'mpesa_manual');
      final record = await payments.forSale(refund.id);
      expect(record, isNotNull);
      expect(record!.amount.cents, -10000);
      expect(record.method, 'mpesa_manual');
      expect(record.status, 'refunded');
      expect(record.referenceNote, 'Refund of ${sale.saleNumber}');
    });

    test('part of a sale: only the chosen quantity, and the rest stays refundable', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 3)]);
      final item = (await saleItems.forSale(sale.id)).single;
      final refund = await mustRefund(sale, [RefundChoice(itemId: item.id, quantity: 1)]);
      expect(refund.total.cents, -10000);

      final source = (await refunds.refundableSale(sale.id))!;
      expect(source.lines.single.refunded, 1);
      expect(source.lines.single.remaining, 2);
      expect(source.refundedTotal.cents, 10000);
      expect(source.remainingTotal.cents, 20000);
      expect(source.refunds.map((r) => r.id), [refund.id]);
      expect(source.whyNot, isNull);
      expect(await stockOf(widgetId), 18, reason: '20 - 3 + 1');
    });

    test('several refunds of one sale add up to exactly the sale, then nothing is left', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 3)]);
      final item = (await saleItems.forSale(sale.id)).single;
      await mustRefund(sale, [RefundChoice(itemId: item.id, quantity: 1)]);
      await mustRefund(sale, [RefundChoice(itemId: item.id, quantity: 2)]);
      final source = (await refunds.refundableSale(sale.id))!;
      expect(source.refundedTotal, sale.total);
      expect(source.hasAnythingLeft, isFalse);
      expect(source.whyNot, 'This sale has already been refunded in full.');
      final again = await refundIt(sale, [RefundChoice(itemId: item.id, quantity: 1)]);
      expect(failureOf(again), 'This sale has already been refunded in full.');
      expect(await stockOf(widgetId), 20);
    });

    test('goods that cannot go back on the shelf: no stock movement and no cost given back', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 2)]);
      final item = (await saleItems.forSale(sale.id)).single;
      final refund = await mustRefund(sale, [RefundChoice(itemId: item.id, quantity: 2, restock: false)], reason: 'Damaged');
      expect(await stockOf(widgetId), 18, reason: 'still 20 - 2');
      final movements = await db.stockMovementsDao.forProduct(widgetId);
      expect(movements.where((m) => m.movementType == 'return'), isEmpty);
      final l = (await saleItems.forSale(refund.id)).single;
      expect(l.costPrice, const Money.zero());
      expect(l.quantity, -2);
    });

    test('each line can be restocked or not on its own', () async {
      final sale = await sell([
        line(widgetId, 'Widget', 10000, 6000, 1),
        line(gadgetId, 'Gadget', 25050, 15000, 1),
      ]);
      final items = await saleItems.forSale(sale.id);
      final w = items.firstWhere((i) => i.productId == widgetId);
      final g = items.firstWhere((i) => i.productId == gadgetId);
      await mustRefund(sale, [
        RefundChoice(itemId: w.id, quantity: 1),
        RefundChoice(itemId: g.id, quantity: 1, restock: false),
      ]);
      expect(await stockOf(widgetId), 20);
      expect(await stockOf(gadgetId), 19);
    });

    test('a manual item (no product) is refunded without any stock movement', () async {
      final sale = await sell([line(null, 'Delivery', 5000, 0, 1), line(widgetId, 'Widget', 10000, 6000, 1)]);
      final manual = (await saleItems.forSale(sale.id)).firstWhere((i) => i.productId == null);
      final refund = await mustRefund(sale, [RefundChoice(itemId: manual.id, quantity: 1)]);
      expect(refund.total.cents, -5000);
      expect(await stockOf(widgetId), 19, reason: 'the widget stays sold');
    });

    test('a product that has since been deleted: the refund still goes through, nothing is restocked', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 1)]);
      await products.delete(widgetId);
      final refund = await mustRefund(sale, await everything(sale.id));
      expect(refund.total.cents, -10000);
      final l = (await saleItems.forSale(refund.id)).single;
      expect(l.costPrice, const Money.zero());
      final movements = await db.stockMovementsDao.forProduct(widgetId);
      expect(movements.where((m) => m.movementType == 'return'), isEmpty);
    });

    test('the reason is kept trimmed', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 1)]);
      final refund = await mustRefund(sale, await everything(sale.id), reason: '   too small  ');
      expect(refund.refundReason, 'too small');
    });

    test('the refund is stamped by this device like any other sale, and starts a sync', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 1)]);
      final refund = await mustRefund(sale, await everything(sale.id));
      final row = await db.salesDao.findById(refund.id);
      final deviceId = await SyncMetadataService(db).deviceId();
      expect(row!.createdByDeviceId, deviceId);
      expect(row.localRev, greaterThan((await db.salesDao.findById(sale.id))!.localRev));
      expect(row.deletedAt, isNull);
      expect(syncs, 1);
    });
  });

  group('discounts and split payments are given back in proportion, to the cent', () {
    test('a discounted sale refunded in three parts adds up to exactly what was paid', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 3)], discount: 10000);
      expect(sale.total.cents, 20000);
      final item = (await saleItems.forSale(sale.id)).single;
      final totals = <int>[];
      for (var i = 0; i < 3; i++) {
        final refund = await mustRefund(sale, [RefundChoice(itemId: item.id, quantity: 1)]);
        totals.add(-refund.total.cents);
      }
      expect(totals.fold<int>(0, (a, b) => a + b), 20000);
      expect(totals, [6667, 6666, 6667], reason: 'the rounding is carried, never lost');
      final source = (await refunds.refundableSale(sale.id))!;
      expect(source.refundedTotal, sale.total);
      expect(source.refundedDiscount.cents, 10000);
    });

    test('refunding one cheap item out of a discounted basket gives back its share of the discount only', () async {
      final sale = await sell([
        line(widgetId, 'Widget', 10000, 6000, 1),
        line(gadgetId, 'Gadget', 25050, 15000, 1),
      ], discount: 3505);
      expect(sale.total.cents, 31545);
      final w = (await saleItems.forSale(sale.id)).firstWhere((i) => i.productId == widgetId);
      final refund = await mustRefund(sale, [RefundChoice(itemId: w.id, quantity: 1)]);
      // 10000 of 35050 -> 3505 * 10000 / 35050 = 1000 of the discount
      expect(refund.subtotal.cents, -10000);
      expect(refund.discount.cents, -1000);
      expect(refund.total.cents, -9000);
    });

    test('a split cash + M-Pesa sale hands back cash and M-Pesa in the same proportion', () async {
      final sale = await sellSplit([line(widgetId, 'Widget', 10000, 6000, 4)], 10000);
      expect(sale.isSplitPayment, isTrue);
      final item = (await saleItems.forSale(sale.id)).single;
      final first = await mustRefund(sale, [RefundChoice(itemId: item.id, quantity: 1)]);
      expect(first.total.cents, -10000);
      expect(first.cashReceived!.cents, -2500, reason: '10000 of 40000 paid in cash is a quarter of this refund');
      final rest = await mustRefund(sale, [RefundChoice(itemId: item.id, quantity: 3)]);
      expect(rest.cashReceived!.cents, -7500);
      expect(-first.cashReceived!.cents - rest.cashReceived!.cents, 10000, reason: 'all of the cash goes back, exactly');
    });

    test('a plain cash sale never carries a cash-received figure on its refund', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 1)]);
      final refund = await mustRefund(sale, await everything(sale.id));
      expect(refund.cashReceived, isNull);
    });

    test('roundedShare is exact for any size of amount', () {
      expect(roundedShare(10, 1, 3), 3);
      expect(roundedShare(10, 2, 3), 7);
      expect(roundedShare(5, 1, 2), 3, reason: 'halves go up');
      expect(roundedShare(0, 5, 7), 0);
      expect(roundedShare(7, 5, 0), 0, reason: 'nothing to divide by');
      expect(roundedShare(100000000, 100000000, 100000000), 100000000);
      expect(roundedShare(99999999, 99999999, 100000000), 99999998);
    });
  });

  group('what cannot be refunded', () {
    test('nothing chosen, an unknown line, a repeated line, zero or negative quantities', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 2)]);
      final item = (await saleItems.forSale(sale.id)).single;
      expect(failureOf(await refundIt(sale, [])), 'Choose at least one item to refund.');
      expect(failureOf(await refundIt(sale, [const RefundChoice(itemId: 'nope', quantity: 1)])), 'That item is not part of this sale.');
      expect(failureOf(await refundIt(sale, [RefundChoice(itemId: item.id, quantity: 1), RefundChoice(itemId: item.id, quantity: 1)])), 'An item is listed twice.');
      expect(failureOf(await refundIt(sale, [RefundChoice(itemId: item.id, quantity: 0)])), 'Enter a quantity of 1 or more.');
      expect(failureOf(await refundIt(sale, [RefundChoice(itemId: item.id, quantity: -1)])), 'Enter a quantity of 1 or more.');
      expect(await db.salesDao.refundsOf(sale.id), isEmpty);
      expect(await stockOf(widgetId), 18);
    });

    test('more than was sold, or more than is left', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 2)]);
      final item = (await saleItems.forSale(sale.id)).single;
      expect(failureOf(await refundIt(sale, [RefundChoice(itemId: item.id, quantity: 3)])), 'Only 2 of Widget can still be refunded.');
      await mustRefund(sale, [RefundChoice(itemId: item.id, quantity: 1)]);
      expect(failureOf(await refundIt(sale, [RefundChoice(itemId: item.id, quantity: 2)])), 'Only 1 of Widget can still be refunded.');
      expect((await db.salesDao.refundsOf(sale.id)), hasLength(1));
    });

    test('a line that is fully refunded cannot be picked again while another still can', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 1), line(gadgetId, 'Gadget', 25050, 15000, 1)]);
      final items = await saleItems.forSale(sale.id);
      final w = items.firstWhere((i) => i.productId == widgetId);
      await mustRefund(sale, [RefundChoice(itemId: w.id, quantity: 1)]);
      expect(failureOf(await refundIt(sale, [RefundChoice(itemId: w.id, quantity: 1)])), 'Widget has already been refunded.');
    });

    test('only a paid sale: a pending or cancelled online sale is refused', () async {
      final begun = await checkout.beginPaystackSale(
        cart: [line(widgetId, 'Widget', 10000, 6000, 1)],
        discount: const Money.zero(),
        saleType: 'retail',
        userId: cashier.id,
        saleNumber: await checkout.generateSaleNumber(),
        paystackReference: 'ref-pending',
      );
      final pending = begun.when(ok: (s) => s, failure: (m) => throw StateError(m));
      final choice = [RefundChoice(itemId: (await saleItems.forSale(pending.id)).single.id, quantity: 1)];
      expect(failureOf(await refundIt(pending, choice)), 'Only a paid sale can be refunded.');
      await checkout.cancelPaystackSale(pending.id);
      expect(failureOf(await refundIt(pending, choice)), 'Only a paid sale can be refunded.');
    });

    test('a refund itself cannot be refunded', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 1)]);
      final refund = await mustRefund(sale, await everything(sale.id));
      final line0 = (await saleItems.forSale(refund.id)).single;
      expect(failureOf(await refundIt(refund, [RefundChoice(itemId: line0.id, quantity: 1)])), 'A refund cannot be refunded.');
    });

    test('a sale that does not exist', () async {
      final approval = await approvalFor(manager);
      final result = await refunds.refund(saleId: 'no-such-sale', choices: const [RefundChoice(itemId: 'x', quantity: 1)], reason: 'x', approval: approval);
      expect(failureOf(result), 'Sale not found.');
    });

    test('a sale worth nothing has nothing to give back', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 1)], discount: 10000);
      expect(sale.total.cents, 0);
      final item = (await saleItems.forSale(sale.id)).single;
      expect(failureOf(await refundIt(sale, [RefundChoice(itemId: item.id, quantity: 1)])), 'There is nothing to refund on those items.');
    });

    test('a reason is needed, and not an endless one', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 1)]);
      final choices = await everything(sale.id);
      expect(failureOf(await refundIt(sale, choices, reason: '')), 'Enter the reason for the refund.');
      expect(failureOf(await refundIt(sale, choices, reason: '    ')), 'Enter the reason for the refund.');
      expect(failureOf(await refundIt(sale, choices, reason: 'x' * 201)), 'The reason is too long (200 characters at most).');
      expect((await refundIt(sale, choices, reason: 'x' * 200)).isOk, isTrue);
    });

    test('a refused refund writes nothing at all', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 2)]);
      final item = (await saleItems.forSale(sale.id)).single;
      final salesBefore = (await db.select(db.sales).get()).length;
      final movesBefore = (await db.stockMovementsDao.forProduct(widgetId)).length;
      await refundIt(sale, [RefundChoice(itemId: item.id, quantity: 9)]);
      expect((await db.select(db.sales).get()).length, salesBefore);
      expect((await db.stockMovementsDao.forProduct(widgetId)).length, movesBefore);
      expect(syncs, 0);
    });
  });

  group('who may refund', () {
    test('an administrator and a manager can; a cashier cannot', () async {
      current = owner;
      expect(refunds.canRefund, isTrue);
      current = manager;
      expect(refunds.canRefund, isTrue);
      current = cashier;
      expect(refunds.canRefund, isFalse);
      current = null;
      expect(refunds.canRefund, isFalse);
    });

    test('an administrator can refund too', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 1)]);
      final result = await refundIt(sale, await everything(sale.id), by: owner);
      expect(result.isOk, isTrue);
      expect(result.when(ok: (s) => s.userId, failure: (_) => ''), owner.id);
    });

    test('a cashier cannot get the password approval, and cannot refund even with someone else\'s', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 1)]);
      current = cashier;
      await expectLater(
        security.approveWithPasswordOnly(username: 'cashier', password: 'long-password', action: refundApprovalAction, roles: refundRoles),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'Your password was not accepted.')),
      );
      final managersApproval = await approvalFor(manager);
      current = cashier;
      final result = await refunds.refund(saleId: sale.id, choices: await everything(sale.id), reason: 'x', approval: managersApproval);
      expect(failureOf(result), 'Only an administrator or a manager can refund.');
      expect(await db.salesDao.refundsOf(sale.id), isEmpty);
    });

    test('the password must be right', () async {
      current = manager;
      await expectLater(
        security.approveWithPasswordOnly(username: 'manager', password: 'wrong', action: refundApprovalAction, roles: refundRoles),
        throwsStateError,
      );
    });

    test('an approval is for one refund only', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 2)]);
      final item = (await saleItems.forSale(sale.id)).single;
      final approval = await approvalFor(manager);
      final first = await refunds.refund(saleId: sale.id, choices: [RefundChoice(itemId: item.id, quantity: 1)], reason: 'a', approval: approval);
      expect(first.isOk, isTrue);
      final second = await refunds.refund(saleId: sale.id, choices: [RefundChoice(itemId: item.id, quantity: 1)], reason: 'b', approval: approval);
      expect(failureOf(second), 'Authorization expired. Verify your identity again.');
      expect(await db.salesDao.refundsOf(sale.id), hasLength(1));
    });

    test('an approval for another action does not count, and expires', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 1)]);
      current = manager;
      final other = await security.approveWithPasswordOnly(username: 'manager', password: 'long-password', action: 'Leave this shop', roles: refundRoles);
      expect(failureOf(await refunds.refund(saleId: sale.id, choices: await everything(sale.id), reason: 'x', approval: other)), 'Authorization expired. Verify your identity again.');
      final stale = await approvalFor(manager);
      clock.value = clock.value.add(const Duration(minutes: 6));
      expect(failureOf(await refunds.refund(saleId: sale.id, choices: await everything(sale.id), reason: 'x', approval: stale)), 'Authorization expired. Verify your identity again.');
      expect(await db.salesDao.refundsOf(sale.id), isEmpty);
    });

    test('an approval given by an administrator-only check is not enough for a manager\'s refund, and vice versa', () async {
      // The old administrator-only approvals still work for what they were made for and stay administrator-only.
      current = manager;
      await expectLater(
        security.approveWithPasswordOnly(username: 'manager', password: 'long-password', action: 'Leave this shop'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'Administrator credentials were not accepted.')),
      );
      current = owner;
      final adminApproval = await security.approveWithPasswordOnly(username: 'owner', password: 'long-password', action: 'Leave this shop');
      await security.consume(adminApproval, 'Leave this shop');
    });

    test('a refused approval does not use up the person\'s approval: a mistake in the choices can be fixed', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 1)]);
      final item = (await saleItems.forSale(sale.id)).single;
      final approval = await approvalFor(manager);
      final bad = await refunds.refund(saleId: sale.id, choices: [RefundChoice(itemId: item.id, quantity: 5)], reason: 'x', approval: approval);
      expect(bad.isFailure, isTrue);
      final good = await refunds.refund(saleId: sale.id, choices: [RefundChoice(itemId: item.id, quantity: 1)], reason: 'x', approval: approval);
      expect(good.isOk, isTrue, reason: 'the same approval still works because the first try never reached the books');
    });
  });

  group('two at once', () {
    test('two refunds of the same whole sale started together: exactly one gets through', () async {
      final sale = await sell([line(widgetId, 'Widget', 10000, 6000, 2)]);
      final choices = await everything(sale.id);
      final a = await approvalFor(manager);
      final b = await approvalFor(manager);
      final results = await Future.wait([
        refunds.refund(saleId: sale.id, choices: choices, reason: 'first', approval: a),
        refunds.refund(saleId: sale.id, choices: choices, reason: 'second', approval: b),
      ]);
      expect(results.where((r) => r.isOk), hasLength(1));
      expect(results.where((r) => r.isFailure), hasLength(1));
      expect(await db.salesDao.refundsOf(sale.id), hasLength(1));
      expect(await stockOf(widgetId), 20, reason: 'the goods came back once, not twice');
    });
  });
}
