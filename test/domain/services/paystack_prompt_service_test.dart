import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/core/utils/id_generator.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Category, Product, User;
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/data/payments/paystack_gateway.dart';
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
import 'package:nexapos_mobile/domain/services/paystack_credentials_service.dart';
import 'package:nexapos_mobile/domain/services/paystack_payment_service.dart';
import 'package:nexapos_mobile/domain/services/stock_service.dart';

/// A plain-Dart stand-in for the real secure-storage-backed service, so these tests never touch a platform channel.
class _FakeCredentialsService implements PaystackCredentialsService {
  PaystackCredentials credentials;
  _FakeCredentialsService(this.credentials);

  @override
  Future<PaystackCredentials> load() async => credentials;

  @override
  Future<void> save(PaystackCredentials value) async => credentials = value;

  @override
  Future<String> loadDeviceLabel() async => '';

  @override
  Future<void> saveDeviceLabel(String label) async {}

  @override
  Future<void> clearRegistration() async => credentials = credentials.copyWith(baseUrl: '', apiKey: '');
}

/// A pretend payments server: records every call, answers the prompt, and answers verification from [verifyStatus].
class _PretendServer {
  final calls = <String>[];
  final bodies = <Map<String, dynamic>>[];
  http.Response? chargeAnswer;
  Object? failWith;
  String verifyStatus = 'pay_offline';
  int? verifyAmount;
  String? lastReference;

  http.Client get client => MockClient((request) async {
        final action = request.url.queryParameters['action'] ?? '';
        calls.add(action);
        if (failWith != null) throw failWith!;
        if (action == 'charge_mobile_money') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          bodies.add(body);
          lastReference = body['reference'] as String;
          return chargeAnswer ??
              http.Response(jsonEncode({'status': true, 'data': {'reference': body['reference'], 'status': 'pay_offline'}}), 200);
        }
        if (action == 'initialize_transaction') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          bodies.add(body);
          lastReference = body['reference'] as String;
          return http.Response(
            jsonEncode({'status': true, 'data': {'authorization_url': 'https://paystack.test/pay/abc', 'reference': body['reference']}}),
            200,
          );
        }
        if (action == 'verify_transaction') {
          final reference = request.url.queryParameters['reference'];
          return http.Response(
            jsonEncode({
              'status': true,
              'data': {'status': verifyStatus, 'amount': verifyAmount ?? 10000, 'currency': 'KES', 'reference': reference},
            }),
            200,
          );
        }
        throw StateError('unexpected request: ${request.url}');
      });
}

void main() {
  late AppDatabase db;
  late CheckoutService checkoutService;
  late ProductRepositoryImpl productRepository;
  late SaleRepositoryImpl saleRepository;
  late String productId;
  late String userId;
  late _PretendServer server;
  late _FakeCredentialsService credentials;
  late PaystackPaymentService service;
  const configured = PaystackCredentials(
    baseUrl: 'http://localhost/nexapos_platform/public/index.php',
    apiKey: 'device_api_key_123',
    currency: 'KES',
    defaultEmail: 'customer@nexapos.co.ke',
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final syncMeta = SyncMetadataService(db);
    const clock = SystemClock();
    final idGen = UuidIdGenerator();

    final categoryRepository = CategoryRepositoryImpl(db, db.categoriesDao, syncMeta, clock, idGen);
    productRepository = ProductRepositoryImpl(db, db.productsDao, syncMeta, clock, idGen);
    saleRepository = SaleRepositoryImpl(db, db.salesDao, syncMeta, clock, idGen);
    final saleItemRepository = SaleItemRepositoryImpl(db, db.saleItemsDao, syncMeta, clock, idGen);
    final paymentRecordRepository = PaymentRecordRepositoryImpl(db, db.paymentRecordsDao, syncMeta, clock, idGen);
    final stockService = StockService(db, db.productsDao, db.stockMovementsDao, syncMeta, clock, idGen);
    checkoutService = CheckoutService(
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
    productId = await productRepository.create(Product(
      id: '',
      sku: 'SKU-1',
      name: 'Widget',
      categoryId: category.id,
      retailPrice: const Money(10000),
      wholesalePrice: const Money(8000),
      costPrice: const Money(5000),
      stockQty: 0,
      reorderLevel: 2,
      status: 'active',
    ));
    await stockService.applyMovement(productId: productId, movementType: 'purchase', delta: 10);

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

    server = _PretendServer();
    credentials = _FakeCredentialsService(configured);
    service = PaystackPaymentService(PaystackGateway(server.client), credentials, checkoutService);
  });

  tearDown(() async {
    await db.close();
  });

  List<CartItem> oneWidget() => [
        CartItem(productId: productId, name: 'Widget', unitPrice: const Money(10000), costPrice: const Money(5000), quantity: 1),
      ];

  Future<int> stock() async => (await productRepository.findById(productId))!.stockQty;

  Future<PaystackCheckoutSession> startPrompt({
    String phone = '0712 345 678',
    Money discount = const Money.zero(),
    Money? cashReceived,
    String saleType = 'retail',
  }) async {
    final result = await service.start(
      cart: oneWidget(),
      discount: discount,
      saleType: saleType,
      userId: userId,
      cashReceived: cashReceived,
      mpesaPhone: phone,
    );
    late PaystackCheckoutSession session;
    result.when(ok: (s) => session = s, failure: (m) => fail('start failed: $m'));
    server.calls.clear();
    return session;
  }

  group('sending the prompt', () {
    test('goes straight to the customer\'s phone: the prompt is asked for, the payment page never is', () async {
      final result = await service.start(
        cart: oneWidget(),
        discount: const Money.zero(),
        saleType: 'retail',
        userId: userId,
        mpesaPhone: '0712 345 678',
      );

      expect(server.calls, ['charge_mobile_money'], reason: 'no initialize_transaction: there is no checkout page');
      expect(server.bodies.single['phone'], '0712 345 678', reason: 'the number goes as typed; the server cleans it up');
      expect(server.bodies.single['amount'], 10000);
      expect(server.bodies.single['currency'], 'KES');
      result.when(
        ok: (session) {
          expect(session.viaPrompt, isTrue);
          expect(session.authorizationUrl, isEmpty);
          expect(session.phone, '0712 345 678');
          expect(session.reference, server.lastReference);
          expect(session.sale.status, 'pending');
          expect(session.sale.customerPhone, '0712 345 678');
        },
        failure: (m) => fail(m),
      );
      expect(await stock(), 9, reason: 'stock is reserved as soon as the prompt is sent');
      final pending = await checkoutService.pendingPaystackSales();
      expect(pending, hasLength(1));
      expect(await checkoutService.paystackReferenceFor(pending.single.id), server.lastReference,
          reason: 'the reference is kept so a restart can still find out whether it was paid');
    });

    test('the reference the server answers with is the one kept, so a restart looks the payment up by it', () async {
      server.chargeAnswer = http.Response(
        jsonEncode({'status': true, 'data': {'reference': 'PSK-ANSWERED-1', 'status': 'pay_offline'}}),
        200,
      );
      final result = await service.start(
        cart: oneWidget(),
        discount: const Money.zero(),
        saleType: 'retail',
        userId: userId,
        mpesaPhone: '0712 345 678',
      );
      late PaystackCheckoutSession session;
      result.when(ok: (s) => session = s, failure: (m) => fail(m));
      expect(session.reference, 'PSK-ANSWERED-1');
      expect(await checkoutService.paystackReferenceFor(session.sale.id), 'PSK-ANSWERED-1');
    });

    test('a sale started without a number still opens the payment page, exactly as before', () async {
      final result = await service.start(cart: oneWidget(), discount: const Money.zero(), saleType: 'retail', userId: userId);

      expect(server.calls, ['initialize_transaction']);
      result.when(
        ok: (session) {
          expect(session.viaPrompt, isFalse);
          expect(session.authorizationUrl, 'https://paystack.test/pay/abc');
          expect(session.phone, isEmpty);
        },
        failure: (m) => fail(m),
      );
    });

    test('a number that cannot be right is refused before anything is sent or reserved', () async {
      for (final phone in ['12345', '0712abc', '1' * 14, '+++', '07 12']) {
        final result = await service.start(
          cart: oneWidget(),
          discount: const Money.zero(),
          saleType: 'retail',
          userId: userId,
          mpesaPhone: phone,
        );
        expect(result.isFailure, isTrue, reason: '"$phone"');
        result.when(
          ok: (_) => fail('expected failure for "$phone"'),
          failure: (m) => expect(m, 'Enter the customer\'s M-Pesa number, like 0712 345 678.'),
        );
      }
      expect(server.calls, isEmpty);
      expect(await stock(), 10);
    });

    test('numbers written the usual ways are accepted', () async {
      expect(looksLikeMpesaNumber('0712 345 678'), isTrue);
      expect(looksLikeMpesaNumber('0712345678'), isTrue);
      expect(looksLikeMpesaNumber('+254 712 345 678'), isTrue);
      expect(looksLikeMpesaNumber('254712345678'), isTrue);
      expect(looksLikeMpesaNumber('712345678'), isTrue, reason: '9 digits is the shortest');
      expect(looksLikeMpesaNumber('71234567'), isFalse, reason: '8 digits is too short');
      expect(looksLikeMpesaNumber('+254-712-345-678'), isTrue);
      expect(looksLikeMpesaNumber('1234567890123'), isTrue, reason: '13 digits is the longest');
      expect(looksLikeMpesaNumber('12345678901234'), isFalse, reason: '14 digits is too long');
      expect(looksLikeMpesaNumber(''), isFalse);
    });

    test('a shop that does not take Kenyan shillings is told, and nothing is sent', () async {
      credentials.credentials = configured.copyWith(currency: 'USD');
      final result = await service.start(
        cart: oneWidget(),
        discount: const Money.zero(),
        saleType: 'retail',
        userId: userId,
        mpesaPhone: '0712 345 678',
      );
      result.when(
        ok: (_) => fail('expected failure'),
        failure: (m) => expect(m, 'M-Pesa prompts are only for payments in KES.'),
      );
      expect(server.calls, isEmpty);
      expect(await stock(), 10);
    });

    test('a prompt the server refused records nothing and reserves no stock, and says why', () async {
      server.chargeAnswer = http.Response(
        jsonEncode({'status': false, 'message': 'The M-Pesa prompt could not be sent: Invalid phone number'}),
        422,
      );
      final result = await service.start(
        cart: oneWidget(),
        discount: const Money.zero(),
        saleType: 'retail',
        userId: userId,
        mpesaPhone: '0712 345 678',
      );
      result.when(
        ok: (_) => fail('expected failure'),
        failure: (m) => expect(m, 'The M-Pesa prompt could not be sent: Invalid phone number'),
      );
      expect(await stock(), 10);
      expect(await checkoutService.pendingPaystackSales(), isEmpty);
    });

    test('no connection: nothing is recorded, and the words do not blame the device\'s internet', () async {
      server.failWith = const SocketException('unreachable');
      final result = await service.start(
        cart: oneWidget(),
        discount: const Money.zero(),
        saleType: 'retail',
        userId: userId,
        mpesaPhone: '0712 345 678',
      );
      result.when(
        ok: (_) => fail('expected failure'),
        failure: (m) => expect(m, 'Could not reach the payments server right now. Try again in a moment.'),
      );
      expect(await stock(), 10);
      expect(await checkoutService.pendingPaystackSales(), isEmpty);
    });

    test('a slow server says so', () async {
      server.failWith = TimeoutException('no answer');
      final result = await service.start(
        cart: oneWidget(),
        discount: const Money.zero(),
        saleType: 'retail',
        userId: userId,
        mpesaPhone: '0712 345 678',
      );
      result.when(
        ok: (_) => fail('expected failure'),
        failure: (m) => expect(m, 'The payments server is taking a while to respond. Try again in a moment.'),
      );
    });

    test('cash plus a prompt for the rest asks only for the rest', () async {
      final session = await startPrompt(cashReceived: const Money(4000));
      expect(server.bodies.single['amount'], 6000);
      expect(session.sale.isSplitPayment, isTrue);
      expect(session.sale.gatewayPortion, const Money(6000));
    });
  });

  group('is the prompt still waiting, paid, or over?', () {
    test('a prompt the customer approved finalizes the sale', () async {
      final session = await startPrompt();
      server.verifyStatus = 'success';
      final outcome = await service.poll(session.sale.id, session.reference, session.sale.gatewayPortion, viaPrompt: true);
      expect(outcome, isA<PaystackPollPaid>());
      expect((await saleRepository.findById(session.sale.id))!.status, 'paid');
    });

    test('still waiting for the customer is waiting, not over', () async {
      final session = await startPrompt();
      for (final status in ['pay_offline', 'ongoing', 'pending', 'queued', '']) {
        server.verifyStatus = status;
        final outcome = await service.poll(session.sale.id, session.reference, session.sale.gatewayPortion, viaPrompt: true);
        expect(outcome, isA<PaystackPollWaiting>(), reason: 'status "$status"');
      }
      expect((await saleRepository.findById(session.sale.id))!.status, 'pending');
    });

    test('a prompt the customer declined, or that ran out, or was reversed, is over - and the sale is left pending', () async {
      final session = await startPrompt();
      for (final status in ['failed', 'abandoned', 'reversed', 'cancelled']) {
        server.verifyStatus = status;
        final outcome = await service.poll(session.sale.id, session.reference, session.sale.gatewayPortion, viaPrompt: true);
        expect(outcome, isA<PaystackPollEnded>(), reason: 'status "$status"');
      }
      expect((await saleRepository.findById(session.sale.id))!.status, 'pending', reason: 'only the cashier ends the sale');
      expect(await stock(), 9, reason: 'stock stays reserved until the cashier decides');
    });

    test('on a payment page "abandoned" just means the customer is not done yet', () async {
      final result = await service.start(cart: oneWidget(), discount: const Money.zero(), saleType: 'retail', userId: userId);
      late PaystackCheckoutSession session;
      result.when(ok: (s) => session = s, failure: (m) => fail(m));
      server.verifyStatus = 'abandoned';
      final outcome = await service.poll(session.sale.id, session.reference, session.sale.gatewayPortion);
      expect(outcome, isA<PaystackPollWaiting>());
    });

    test('"success" for the wrong amount is never accepted as paid, nor as over', () async {
      final session = await startPrompt();
      server.verifyStatus = 'success';
      server.verifyAmount = 5000;
      final outcome = await service.poll(session.sale.id, session.reference, session.sale.gatewayPortion, viaPrompt: true);
      expect(outcome, isA<PaystackPollWaiting>());
      expect((await saleRepository.findById(session.sale.id))!.status, 'pending');
    });

    test('a connection problem while checking is just "still waiting"', () async {
      final session = await startPrompt();
      server.failWith = const SocketException('unreachable');
      final outcome = await service.poll(session.sale.id, session.reference, session.sale.gatewayPortion, viaPrompt: true);
      expect(outcome, isA<PaystackPollWaiting>());
    });
  });

  group('sending the prompt again', () {
    test('when it is really over: the first sale is cancelled, stock is back, and everything comes back for the cart', () async {
      final session = await startPrompt(discount: const Money(1500), saleType: 'wholesale');
      server.verifyStatus = 'failed';

      final outcome = await service.retryPrompt(session.sale, session.reference);

      expect(outcome, isA<PaystackRetryRestored>());
      final restored = outcome as PaystackRetryRestored;
      expect(restored.items, hasLength(1));
      expect(restored.items.single.productId, productId);
      expect(restored.items.single.name, 'Widget');
      expect(restored.items.single.quantity, 1);
      expect(restored.items.single.unitPrice, session.sale.subtotal, reason: 'the price it was sold at, not today\'s catalog price');
      expect(restored.items.single.costPrice, const Money(5000));
      expect(restored.discount, const Money(1500));
      expect(restored.saleType, 'wholesale');
      expect(restored.cashReceived, isNull);
      expect((await saleRepository.findById(session.sale.id))!.status, 'cancelled');
      expect(await stock(), 10, reason: 'the first sale gave its stock back');
    });

    test('the quantity of each item comes back as it was sold', () async {
      final result = await service.start(
        cart: [
          CartItem(productId: productId, name: 'Widget', unitPrice: const Money(10000), costPrice: const Money(5000), quantity: 3),
          const CartItem(name: 'Delivery', unitPrice: Money(2500), costPrice: Money.zero(), quantity: 2),
        ],
        discount: const Money.zero(),
        saleType: 'retail',
        userId: userId,
        mpesaPhone: '0712 345 678',
      );
      late PaystackCheckoutSession session;
      result.when(ok: (s) => session = s, failure: (m) => fail(m));
      expect(await stock(), 7);
      server.verifyStatus = 'failed';
      server.verifyAmount = 35000;

      final outcome = await service.retryPrompt(session.sale, session.reference) as PaystackRetryRestored;

      // The lines come back as sold; the database does not keep the order they were rung up in, so compare them as a set.
      final lines = outcome.items.map((i) => '${i.name} x${i.quantity} ${i.productId == null ? 'manual' : 'catalog'}').toList()..sort();
      expect(lines, ['Delivery x2 manual', 'Widget x3 catalog']);
      expect(await stock(), 10, reason: 'all three came back');
    });

    test('a cash-plus-prompt sale comes back with its cash, so the rest can be asked for again', () async {
      final session = await startPrompt(cashReceived: const Money(4000));
      server.verifyStatus = 'abandoned';
      server.verifyAmount = 6000;

      final outcome = await service.retryPrompt(session.sale, session.reference);

      expect(outcome, isA<PaystackRetryRestored>());
      expect((outcome as PaystackRetryRestored).cashReceived, const Money(4000));
    });

    test('if the customer approved it after all, it is a paid sale and nothing is cancelled or sent twice', () async {
      final session = await startPrompt();
      server.verifyStatus = 'success';

      final outcome = await service.retryPrompt(session.sale, session.reference);

      expect(outcome, isA<PaystackRetryPaid>());
      expect((await saleRepository.findById(session.sale.id))!.status, 'paid');
      expect(await stock(), 9);
      expect(server.calls, ['verify_transaction'], reason: 'no second prompt, no cancelling');
    });

    test('if the prompt is still waiting, nothing is cancelled', () async {
      final session = await startPrompt();
      server.verifyStatus = 'pay_offline';

      final outcome = await service.retryPrompt(session.sale, session.reference);

      expect(outcome, isA<PaystackRetryNotYet>());
      expect((await saleRepository.findById(session.sale.id))!.status, 'pending');
      expect(await stock(), 9);
    });

    test('if the last check cannot be made (no connection), nothing is cancelled', () async {
      final session = await startPrompt();
      server.failWith = const SocketException('unreachable');

      final outcome = await service.retryPrompt(session.sale, session.reference);

      expect(outcome, isA<PaystackRetryNotYet>());
      expect((await saleRepository.findById(session.sale.id))!.status, 'pending');
      expect(await stock(), 9);
    });

    test('doing it twice is harmless: the second time there is nothing left to cancel', () async {
      final session = await startPrompt();
      server.verifyStatus = 'failed';
      await service.retryPrompt(session.sale, session.reference);

      final again = await service.retryPrompt(session.sale, session.reference);

      expect(again, isA<PaystackRetryRestored>(), reason: 'cancelling an already cancelled sale is a no-op');
      expect(await stock(), 10, reason: 'stock is not given back twice');
    });
  });
}
