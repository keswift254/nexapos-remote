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
import 'package:nexapos_mobile/data/repositories/expense_repository_impl.dart';
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
import 'package:nexapos_mobile/domain/services/expense_service.dart';
import 'package:nexapos_mobile/domain/services/refund_service.dart';
import 'package:nexapos_mobile/domain/services/reports_service.dart';
import 'package:nexapos_mobile/domain/services/sensitive_action_service.dart';
import 'package:nexapos_mobile/domain/services/stock_service.dart';

import 'fake_secure_storage.dart';

class HarnessClock implements Clock {
  DateTime value;
  HarnessClock(this.value);
  @override
  DateTime now() => value;
}

/// A small shop on an in-memory database with the real services wired together: ring up sales, refund them,
/// read the reports. Used by the refund tests that need more than the refund service itself.
class ShopHarness {
  final AppDatabase db;
  final HarnessClock clock;
  final CheckoutService checkout;
  final RefundService refunds;
  final ReportsService reports;
  final ExpenseService expenses;
  final SensitiveActionService security;
  final ProductRepositoryImpl products;
  final SaleRepositoryImpl sales;
  final SaleItemRepositoryImpl saleItems;
  final PaymentRecordRepositoryImpl payments;
  final StockService stock;
  final String widgetId;
  final String gadgetId;
  final User owner;
  final User manager;
  final User cashier;
  User? current;

  ShopHarness._(
    this.db,
    this.clock,
    this.checkout,
    this.refunds,
    this.reports,
    this.expenses,
    this.security,
    this.products,
    this.sales,
    this.saleItems,
    this.payments,
    this.stock,
    this.widgetId,
    this.gadgetId,
    this.owner,
    this.manager,
    this.cashier,
  ) {
    current = manager;
  }

  /// Local noon on 16 Nov 2026, as the clock the repositories stamp rows with (always UTC).
  static DateTime noon([int day = 16]) => DateTime(2026, 11, day, 12).toUtc();

  static Future<ShopHarness> create({DateTime? now}) async {
    installFakeSecureStorage();
    final db = AppDatabase(NativeDatabase.memory());
    final clock = HarnessClock(now ?? noon());
    final syncMeta = SyncMetadataService(db);
    final idGen = UuidIdGenerator();
    final products = ProductRepositoryImpl(db, db.productsDao, syncMeta, clock, idGen);
    final sales = SaleRepositoryImpl(db, db.salesDao, syncMeta, clock, idGen);
    final saleItems = SaleItemRepositoryImpl(db, db.saleItemsDao, syncMeta, clock, idGen);
    final payments = PaymentRecordRepositoryImpl(db, db.paymentRecordsDao, syncMeta, clock, idGen);
    final stock = StockService(db, db.productsDao, db.stockMovementsDao, syncMeta, clock, idGen);
    final checkout = CheckoutService(db, sales, saleItems, payments, products, stock, syncMeta, clock, idGen);
    final categoryId = idGen.newId();
    await CategoryRepositoryImpl(db, db.categoriesDao, syncMeta, clock, idGen)
        .create(Category(id: categoryId, name: 'General', status: 'active'));

    Future<String> seed(String name, int price, int cost, int qty) async {
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
      await stock.applyMovement(productId: id, movementType: 'purchase', delta: qty);
      return id;
    }

    final widgetId = await seed('Widget', 10000, 6000, 20);
    final gadgetId = await seed('Gadget', 25050, 15000, 20);

    final users = UserRepositoryImpl(db, db.usersDao, syncMeta, clock, idGen);
    final auth = AuthService(users, idGen);
    Future<User> make(String name, UserRole role) async => (await auth.createUser(
          name: name,
          username: name.toLowerCase(),
          password: 'long-password',
          role: role,
        ))
            .when(ok: (u) => u, failure: (m) => throw StateError(m));
    final owner = await make('Owner', UserRole.admin);
    final manager = await make('Manager', UserRole.manager);
    final cashier = await make('Cashier', UserRole.cashier);

    late ShopHarness harness;
    final security = SensitiveActionService(
      auth,
      const FlutterSecureStorage(),
      clock,
      () => harness.current?.id,
    );
    final refunds = RefundService(
      db,
      sales,
      saleItems,
      payments,
      products,
      stock,
      security,
      idGen,
      newSaleNumber: checkout.generateSaleNumber,
      currentUser: () => harness.current,
    );
    final expenseService = ExpenseService(
      ExpenseRepositoryImpl(db, db.expensesDao, syncMeta, clock, idGen),
      idGen,
      clock,
    );
    harness = ShopHarness._(
      db,
      clock,
      checkout,
      refunds,
      ReportsService(db.reportsDao, clock),
      expenseService,
      security,
      products,
      sales,
      saleItems,
      payments,
      stock,
      widgetId,
      gadgetId,
      owner,
      manager,
      cashier,
    );
    return harness;
  }

  Future<void> close() => db.close();

  CartItem line(String? productId, String name, int price, int cost, int qty) => CartItem(
        productId: productId,
        name: name,
        unitPrice: Money(price),
        costPrice: Money(cost),
        quantity: qty,
      );

  Future<int> stockOf(String id) async => (await products.findById(id))!.stockQty;

  Future<Sale> sell(List<CartItem> cart, {String method = 'cash', int discount = 0}) async {
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

  /// A split sale: [cash] collected up front, the rest by M-Pesa prompt (as the cart screen does it), then confirmed paid.
  Future<Sale> sellSplit(List<CartItem> cart, int cash, {int discount = 0}) async {
    final begun = await checkout.beginPaystackSale(
      cart: cart,
      discount: Money(discount),
      saleType: 'retail',
      userId: cashier.id,
      saleNumber: await checkout.generateSaleNumber(),
      paystackReference: 'PAYSTACK-REF-TEST',
      cashReceived: Money(cash),
    );
    final sale = begun.when(ok: (s) => s, failure: (m) => throw StateError(m));
    await checkout.finalizePaystackSale(sale.id);
    return (await sales.findById(sale.id))!;
  }

  Future<ActionApproval> approvalFor(User who) async {
    current = who;
    return security.approveWithPasswordOnly(
      username: who.username,
      password: 'long-password',
      action: refundApprovalAction,
      roles: refundRoles,
    );
  }

  Future<Result<Sale>> refund(
    Sale sale,
    List<RefundChoice> choices, {
    String reason = 'Customer changed their mind',
    User? by,
  }) async {
    final approval = await approvalFor(by ?? manager);
    return refunds.refund(saleId: sale.id, choices: choices, reason: reason, approval: approval);
  }

  Future<Sale> mustRefund(Sale sale, List<RefundChoice> choices, {String reason = 'Faulty', User? by}) async {
    final result = await refund(sale, choices, reason: reason, by: by);
    return result.when(ok: (s) => s, failure: (m) => throw StateError('refund failed: $m'));
  }

  /// Every line of [sale] that still has something left, in full.
  Future<List<RefundChoice>> everything(String saleId, {bool restock = true}) async {
    final source = (await refunds.refundableSale(saleId))!;
    return [
      for (final l in source.lines)
        if (l.remaining > 0)
          RefundChoice(itemId: l.item.id, quantity: l.remaining, restock: restock),
    ];
  }

  /// The choice of [quantity] of the (only) line for [productId] in [saleId].
  Future<RefundChoice> choose(String saleId, String productId, int quantity, {bool restock = true}) async {
    final lines = await saleItems.forSale(saleId);
    return RefundChoice(
      itemId: lines.firstWhere((l) => l.productId == productId).id,
      quantity: quantity,
      restock: restock,
    );
  }
}
