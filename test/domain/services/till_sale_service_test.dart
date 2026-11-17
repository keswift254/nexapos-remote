import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/core/utils/id_generator.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Category, Product, User;
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/data/payments/payment_inbox_gateway.dart';
import 'package:nexapos_mobile/data/payments/platform_http_client.dart';
import 'package:nexapos_mobile/data/repositories/category_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/payment_record_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/product_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/sale_item_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/sale_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/user_repository_impl.dart';
import 'package:nexapos_mobile/domain/entities/cart_item.dart';
import 'package:nexapos_mobile/domain/entities/category.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/entities/product.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/checkout_service.dart';
import 'package:nexapos_mobile/domain/services/stock_service.dart';
import 'package:nexapos_mobile/domain/services/till_sale_service.dart';

/// The shop's payment inbox as the till sale sees it: every claim and release is recorded, and [answer] decides what the
/// shop says (a payment, or a refusal / exception to throw).
class _FakeInbox extends PaymentInboxGateway {
  final claims = <({String code, String saleId, String saleNumber, int amountCents, bool acceptAmount})>[];
  final releases = <({String code, String saleId})>[];
  Object Function(({String code, String saleId, String saleNumber, int amountCents, bool acceptAmount}) claim) answer =
      (claim) => TillPayment(code: claim.code, messageReceived: true, amount: Money(claim.amountCents), payerName: 'JOHN DOE');

  @override
  Future<TillPayment> claim({
    required String baseUrl,
    required String apiKey,
    required String code,
    required String saleId,
    required String saleNumber,
    required Money amount,
    bool acceptAmount = false,
  }) async {
    final claim = (code: code, saleId: saleId, saleNumber: saleNumber, amountCents: amount.cents, acceptAmount: acceptAmount);
    claims.add(claim);
    final result = answer(claim);
    if (result is TillPayment) return result;
    throw result;
  }

  @override
  Future<void> release({required String baseUrl, required String apiKey, required String code, required String saleId}) async {
    releases.add((code: code, saleId: saleId));
  }
}

void main() {
  late AppDatabase db;
  late CheckoutService checkout;
  late ProductRepositoryImpl products;
  late SaleRepositoryImpl sales;
  late PaymentRecordRepositoryImpl payments;
  late StockService stock;
  late _FakeInbox inbox;
  late TillSaleService service;
  late String productId;
  late String cashierId;
  var connected = true;

  setUp(() async {
    connected = true;
    db = AppDatabase(NativeDatabase.memory());
    final meta = SyncMetadataService(db);
    const clock = SystemClock();
    final ids = UuidIdGenerator();
    final categories = CategoryRepositoryImpl(db, db.categoriesDao, meta, clock, ids);
    products = ProductRepositoryImpl(db, db.productsDao, meta, clock, ids);
    sales = SaleRepositoryImpl(db, db.salesDao, meta, clock, ids);
    final items = SaleItemRepositoryImpl(db, db.saleItemsDao, meta, clock, ids);
    payments = PaymentRecordRepositoryImpl(db, db.paymentRecordsDao, meta, clock, ids);
    stock = StockService(db, db.productsDao, db.stockMovementsDao, meta, clock, ids);
    checkout = CheckoutService(db, sales, items, payments, products, stock, meta, clock, ids);
    final category = Category(id: ids.newId(), name: 'General', status: 'active');
    await categories.create(category);
    productId = await products.create(Product(
      id: '',
      sku: 'SODA',
      name: 'Soda',
      categoryId: category.id,
      retailPrice: const Money(6000),
      wholesalePrice: const Money(5000),
      costPrice: const Money(4000),
      stockQty: 0,
      reorderLevel: 2,
      status: 'active',
    ));
    await stock.applyMovement(productId: productId, movementType: 'purchase', delta: 10);
    final cashier = User(id: ids.newId(), role: UserRole.cashier, name: 'Cashier', username: 'cashier', passwordHash: 'x', status: 'active');
    await UserRepositoryImpl(db, db.usersDao, meta, clock, ids).create(cashier);
    cashierId = cashier.id;
    inbox = _FakeInbox();
    service = TillSaleService(
      loadCredentials: () async => PaystackCredentials(
        baseUrl: connected ? 'https://sync.test/index.php' : '',
        apiKey: connected ? 'device-key' : '',
        currency: 'KES',
        defaultEmail: 'x@y.z',
      ),
      gateway: inbox,
      checkout: checkout,
      ids: ids,
    );
  });

  tearDown(() => db.close());

  List<CartItem> sodas(int quantity) =>
      [CartItem(productId: productId, name: 'Soda', unitPrice: const Money(6000), costPrice: const Money(4000), quantity: quantity)];

  Future<TillSaleOutcome> sell({int quantity = 2, String code = 'SJK2TILL9X', bool acceptAmount = false, Money discount = const Money.zero()}) =>
      service.complete(cart: sodas(quantity), discount: discount, saleType: 'retail', userId: cashierId, typedCode: code, acceptAmount: acceptAmount);

  Future<int> salesCount() async => (await db.select(db.sales).get()).length;
  Future<int> sodaStock() async => (await products.findById(productId))!.stockQty;

  test('the code is used on THIS sale (its id, number and total) before the sale is saved as an M-Pesa (Manual) sale', () async {
    final outcome = await sell(code: ' sjk2 till-9x ');
    expect(outcome, isA<TillSaleDone>());
    final done = outcome as TillSaleDone;
    final claim = inbox.claims.single;
    expect(claim.code, 'SJK2TILL9X');
    expect(claim.amountCents, 12000);
    expect(claim.acceptAmount, isFalse);
    expect(claim.saleId, done.sale.id, reason: 'the very sale that was saved');
    expect(claim.saleNumber, done.sale.saleNumber);
    final saved = (await sales.findById(done.sale.id))!;
    expect(saved.paymentMethod, 'mpesa_manual');
    expect(saved.status, 'paid');
    expect(saved.total, const Money(12000));
    expect(saved.cashReceived, isNull);
    final record = (await payments.forSale(done.sale.id))!;
    expect((record.method, record.amount, record.referenceNote, record.status), ('mpesa_manual', const Money(12000), 'SJK2TILL9X', 'paid'));
    expect(await sodaStock(), 8, reason: 'the stock goes out as for any sale');
    expect(done.change, const Money.zero());
    expect(inbox.releases, isEmpty);
  });

  test('a code that cannot be one, or a device not connected to the shop, is refused before anything is sent', () async {
    for (final bad in ['', 'short', 'ABCDEFGHIJ', '1234567890']) {
      final outcome = await sell(code: bad);
      expect(outcome, isA<TillSaleRefused>(), reason: bad);
      expect((outcome as TillSaleRefused).message, contains('M-Pesa code'));
    }
    connected = false;
    final outcome = await sell();
    expect((outcome as TillSaleRefused).message, contains('not connected to the shop sync service'));
    expect(inbox.claims, isEmpty);
    expect(await salesCount(), 0);
  });

  test('a cart that cannot be sold never takes a code (out of stock, empty)', () async {
    final tooMany = await sell(quantity: 11);
    expect((tooMany as TillSaleRefused).message, 'Only 10 Soda in stock.');
    final empty = await service.complete(cart: const [], discount: const Money.zero(), saleType: 'retail', userId: 'c', typedCode: 'SJK2TILL9X');
    expect(empty, isA<TillSaleRefused>());
    final free = await sell(discount: const Money(12000));
    expect((free as TillSaleRefused).message, 'The total is zero, so there is nothing to charge.');
    expect(inbox.claims, isEmpty);
    expect(await salesCount(), 0);
  });

  test('no payment with the code, a code already used, an old server: nothing is sold, said in the cashier\'s words', () async {
    inbox.answer = (_) => const TillClaimRefused('not_received', 'No M-Pesa message with this code has arrived yet.');
    final notThere = await sell() as TillSaleRefused;
    expect(notThere.message, startsWith('No M-Pesa payment with this code has reached the shop yet.'));
    expect(notThere.refreshList, isTrue);
    inbox.answer = (_) => const TillClaimRefused('used', 'This M-Pesa code was already used on sale ABC-1.');
    final used = await sell() as TillSaleRefused;
    expect(used.message, 'This M-Pesa code was already used on sale ABC-1.');
    expect(used.refreshList, isTrue);
    inbox.answer = (_) => const TillClaimRefused('unavailable', 'The shop server cannot check M-Pesa payments yet. Ask the owner to update it.');
    final old = await sell() as TillSaleRefused;
    expect(old.message, 'The shop server cannot check M-Pesa payments yet. Ask the owner to update it.');
    expect(old.refreshList, isFalse);
    expect(await salesCount(), 0);
    expect(await sodaStock(), 10);
    expect(inbox.releases, isEmpty, reason: 'a refused code was never held');
  });

  test('a SMALLER payment is refused outright: there is no going ahead', () async {
    inbox.answer = (_) => const TillClaimRefused('amount_differs', 'x', paidAmount: Money(10000));
    final outcome = await sell() as TillSaleRefused;
    expect(outcome.message, 'The customer paid KES 100.00, which is KES 20.00 less than this sale (KES 120.00). Use a payment that covers the whole sale.');
    expect(await salesCount(), 0);
  });

  test('a BIGGER payment asks first; going ahead sends accept_amount and the cash to give back is worked out', () async {
    inbox.answer = (claim) => claim.acceptAmount
        ? TillPayment(code: claim.code, messageReceived: true, amount: const Money(15000))
        : const TillClaimRefused('amount_differs', 'x', paidAmount: Money(15000));
    final asked = await sell() as TillSaleNeedsConfirmation;
    expect((asked.paid, asked.total), (const Money(15000), const Money(12000)));
    expect(await salesCount(), 0);
    final done = await sell(acceptAmount: true) as TillSaleDone;
    expect(inbox.claims.last.acceptAmount, isTrue);
    expect(done.change, const Money(3000));
    expect((await payments.forSale(done.sale.id))!.amount, const Money(12000), reason: 'the record is for the sale total, as always');
  });

  test('an amount that could not be read asks first too', () async {
    inbox.answer = (_) => const TillClaimRefused('amount_unknown', 'x');
    final asked = await sell() as TillSaleNeedsConfirmation;
    expect((asked.paid, asked.total), (null, const Money(12000)));
    expect(await salesCount(), 0);
  });

  test('no internet: nothing is sold', () async {
    inbox.answer = (_) => const PaystackOfflineException();
    final outcome = await sell() as TillSaleRefused;
    expect(outcome.message, TillSaleService.offlineMessage);
    expect(await salesCount(), 0);
    expect(inbox.releases, isEmpty);
  });

  test('an answer that could not be read: nothing is sold and the code is given back', () async {
    inbox.answer = (_) => const PaystackException('The shop server sent an answer this device cannot read.');
    final outcome = await sell() as TillSaleRefused;
    expect(outcome.message, contains('Nothing was sold'));
    expect(await salesCount(), 0);
    expect(inbox.releases.single, (code: 'SJK2TILL9X', saleId: inbox.claims.single.saleId));
  });

  test('the shop took the code but the sale could not be saved (sold out meanwhile): the code is given back', () async {
    inbox.answer = (claim) {
      // another till sold the last sodas while this one was asking the shop
      stock.applyMovement(productId: productId, movementType: 'adjustment', delta: -9);
      return TillPayment(code: claim.code, messageReceived: true, amount: Money(claim.amountCents));
    };
    final outcome = await sell() as TillSaleRefused;
    expect(outcome.message, contains('in stock'));
    expect(outcome.message, contains('the M-Pesa payment can still be used'));
    expect(inbox.releases.single, (code: 'SJK2TILL9X', saleId: inbox.claims.single.saleId));
    expect(await salesCount(), 0);
  });
}
