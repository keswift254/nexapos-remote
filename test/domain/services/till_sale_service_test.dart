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

  group('a split sale: part in cash, the rest paid to the till', () {
    Future<TillSaleOutcome> sellSplit(int cashCents, {bool acceptAmount = false}) => service.complete(
          cart: sodas(2),
          discount: const Money.zero(),
          saleType: 'retail',
          userId: cashierId,
          typedCode: 'SJK2TILL9X',
          acceptAmount: acceptAmount,
          cashReceived: Money(cashCents),
        );

    test('the till payment has to cover only the rest; the sale keeps the cash part and one payment record for the rest', () async {
      final outcome = await sellSplit(5000); // 120.00 sale, 50.00 in cash
      expect(outcome, isA<TillSaleDone>());
      final done = outcome as TillSaleDone;
      expect(inbox.claims.single.amountCents, 7000, reason: 'the shop is asked for the 70.00 the cash did not cover');
      final saved = (await sales.findById(done.sale.id))!;
      expect(saved.paymentMethod, 'mpesa_manual');
      expect(saved.status, 'paid');
      expect(saved.total, const Money(12000));
      expect(saved.cashReceived, const Money(5000));
      expect(saved.isSplitPayment, isTrue);
      expect(saved.gatewayPortion, const Money(7000));
      final record = (await payments.forSale(done.sale.id))!;
      expect(record.method, 'mpesa_manual');
      expect(record.amount, const Money(7000), reason: 'the payment record is the till part only');
      expect(record.referenceNote, 'SJK2TILL9X');
      expect(record.status, 'paid');
      expect(done.change, const Money.zero());
      expect(await sodaStock(), 8);
    });

    test('a bigger till payment asks first; the change is worked out against the rest, not the whole sale', () async {
      inbox.answer = (claim) => claim.acceptAmount
          ? TillPayment(code: claim.code, messageReceived: true, amount: const Money(10000))
          : TillClaimRefused('amount_differs', 'The customer paid a different amount.', paidAmount: const Money(10000));
      final asked = await sellSplit(5000);
      expect(asked, isA<TillSaleNeedsConfirmation>());
      final question = asked as TillSaleNeedsConfirmation;
      expect(question.paid, const Money(10000));
      expect(question.total, const Money(7000));
      expect(question.split, isTrue);
      final done = await sellSplit(5000, acceptAmount: true) as TillSaleDone;
      expect(done.change, const Money(3000), reason: '100.00 paid towards the 70.00 still owed');
    });

    test('a smaller till payment is refused in words about what is still owed', () async {
      inbox.answer = (claim) => TillClaimRefused('amount_differs', 'The customer paid a different amount.', paidAmount: const Money(6000));
      final refused = await sellSplit(5000) as TillSaleRefused;
      expect(refused.message, contains('KES 10.00 less than the KES 70.00 still owed'));
      expect(await salesCount(), 0);
    });

    test('a cash part of nothing, or of the whole sale or more, is refused before the shop is asked', () async {
      for (final cash in [0, 12000, 15000]) {
        final refused = await sellSplit(cash);
        expect(refused, isA<TillSaleRefused>(), reason: 'cash $cash');
        expect((refused as TillSaleRefused).message, contains('more than zero and less than the total'));
      }
      expect(inbox.claims, isEmpty);
      expect(await salesCount(), 0);
    });
  });

  group('the customer paid in two or more payments (say 200, then 50)', () {
    // A 120.00 sale (two sodas) paid as 80.00, then 40.00.
    const first = 'SJK2TILL9X';
    const second = 'SJK3TILL8Y';
    const third = 'SJK4TILL7Z';
    final amounts = {first: const Money(8000), second: const Money(4000), third: const Money(1000)};

    Future<TillSaleOutcome> sellWith(String codes,
            {bool acceptAmount = false, Money? cash, Map<String, Money>? known}) =>
        service.complete(
          cart: sodas(2),
          discount: const Money.zero(),
          saleType: 'retail',
          userId: cashierId,
          typedCode: codes,
          acceptAmount: acceptAmount,
          cashReceived: cash,
          knownAmounts: known ?? amounts,
        );

    test('each code is used on THIS sale for exactly its own amount; the sale is saved once, with every code', () async {
      final done = await sellWith('$first, $second') as TillSaleDone;

      expect(inbox.claims.map((c) => (c.code, c.amountCents, c.acceptAmount)), [(first, 8000, false), (second, 4000, false)]);
      expect(inbox.claims.map((c) => c.saleId).toSet(), {done.sale.id}, reason: 'both on the very sale that was saved');
      expect(inbox.claims.map((c) => c.saleNumber).toSet(), {done.sale.saleNumber});
      expect(await salesCount(), 1);
      final saved = (await sales.findById(done.sale.id))!;
      expect((saved.paymentMethod, saved.status, saved.total), ('mpesa_manual', 'paid', const Money(12000)));
      final record = (await payments.forSale(done.sale.id))!;
      expect((record.amount, record.referenceNote), (const Money(12000), '$first, $second'),
          reason: 'one payment record, as for any till sale, naming both payments');
      expect(done.paid, const Money(12000));
      expect(done.change, const Money.zero());
      expect(await sodaStock(), 8);
      expect(inbox.releases, isEmpty);
    });

    test('codes may be typed with a plus or a comma, in any case, each one only once', () async {
      final done = await sellWith(' sjk2 till-9x + SJK3TILL8Y,sjk2till9x ') as TillSaleDone;
      expect(inbox.claims.map((c) => c.code), [first, second]);
      expect((await payments.forSale(done.sale.id))!.referenceNote, '$first, $second');
    });

    test('payments that add up to less than the sale are refused before anything is used', () async {
      final refused = await sellWith('$first, $third') as TillSaleRefused;
      expect(refused.message, contains('add up to KES 90.00, which is KES 30.00 less than this sale (KES 120.00)'));
      expect(inbox.claims, isEmpty);
      expect(await salesCount(), 0);
    });

    test('a payment the sale does not need is refused (a slip of the finger), naming it', () async {
      final refused = await sellWith('$first, $second, $third') as TillSaleRefused;
      expect(refused.message, contains('without $third'));
      expect(inbox.claims, isEmpty);
    });

    test('more than the sale asks first; going ahead works out the change, and no code is sent as a different amount',
        () async {
      final more = {...amounts, second: const Money(5000)};
      final asked = await sellWith('$first, $second', known: more) as TillSaleNeedsConfirmation;
      expect((asked.paid, asked.total, asked.payments), (const Money(13000), const Money(12000), 2));
      expect(inbox.claims, isEmpty);

      final done = await sellWith('$first, $second', known: more, acceptAmount: true) as TillSaleDone;
      expect(done.change, const Money(1000));
      expect(inbox.claims.map((c) => (c.amountCents, c.acceptAmount)), [(8000, false), (5000, false)]);
      expect((await payments.forSale(done.sale.id))!.amount, const Money(12000), reason: 'the record is for the sale');
    });

    test('a code that is not in the list of payments is refused: its amount is not known', () async {
      final refused = await sellWith('$first, SJK9TILL1Q') as TillSaleRefused;
      expect(refused.message, contains('SJK9TILL1Q is not one of the payments in the list'));
      expect(refused.refreshList, isTrue);
      expect(inbox.claims, isEmpty);
    });

    test('when the shop refuses one code (another sale used it), the codes already used are given back', () async {
      inbox.answer = (claim) => claim.code == second
          ? const TillClaimRefused('used', 'This M-Pesa code was already used on sale S-0007.')
          : TillPayment(code: claim.code, messageReceived: true, amount: Money(claim.amountCents));
      final refused = await sellWith('$first, $second') as TillSaleRefused;
      expect(refused.message, 'This M-Pesa code was already used on sale S-0007.');
      expect(inbox.releases, [(code: first, saleId: inbox.claims.first.saleId)]);
      expect(await salesCount(), 0);
      expect(await sodaStock(), 10);
    });

    test('no internet half-way: nothing is sold and the code already used is given back', () async {
      inbox.answer = (claim) => claim.code == second
          ? const PaystackOfflineException()
          : TillPayment(code: claim.code, messageReceived: true, amount: Money(claim.amountCents));
      final refused = await sellWith('$first, $second') as TillSaleRefused;
      expect(refused.message, TillSaleService.offlineMessage);
      expect(inbox.releases.map((r) => r.code), [first]);
      expect(await salesCount(), 0);
    });

    test('the sale could not be saved after the codes were used: every code is given back', () async {
      inbox.answer = (claim) {
        if (claim.code == second) stock.applyMovement(productId: productId, movementType: 'adjustment', delta: -9);
        return TillPayment(code: claim.code, messageReceived: true, amount: Money(claim.amountCents));
      };
      final refused = await sellWith('$first, $second') as TillSaleRefused;
      expect(refused.message, contains('the M-Pesa payments can still be used'));
      expect(inbox.releases.map((r) => r.code), [first, second]);
      expect(await salesCount(), 0);
    });

    test('cash first, then two till payments for the rest', () async {
      // 120.00 sale: 20.00 cash, then 80.00 and 20.00 to the till.
      final split = {first: const Money(8000), second: const Money(2000)};
      final done = await sellWith('$first, $second', cash: const Money(2000), known: split) as TillSaleDone;
      final saved = (await sales.findById(done.sale.id))!;
      expect((saved.cashReceived, saved.gatewayPortion), (const Money(2000), const Money(10000)));
      final record = (await payments.forSale(done.sale.id))!;
      expect((record.amount, record.referenceNote), (const Money(10000), '$first, $second'));
    });

    test('at most five payments for one sale', () async {
      final six = List.generate(6, (i) => 'SJK${i}TILL0A').join(', ');
      final refused = await sellWith(six) as TillSaleRefused;
      expect(refused.message, contains('at most 5'));
      expect(inbox.claims, isEmpty);
    });

    test('one code still works exactly as before (the shop checks its amount against the sale)', () async {
      final done = await sellWith(first, known: const {}) as TillSaleDone;
      expect(inbox.claims.single.amountCents, 12000);
      expect(done.payments.single.code, first);
    });
  });
}
