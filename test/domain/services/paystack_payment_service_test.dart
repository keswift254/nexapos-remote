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

/// A plain-Dart stand-in for the real secure-storage-backed service, so
/// these tests never touch a platform channel.
class _FakeCredentialsService implements PaystackCredentialsService {
  PaystackCredentials credentials;
  String deviceLabel = '';
  _FakeCredentialsService(this.credentials);

  @override
  Future<PaystackCredentials> load() async => credentials;

  @override
  Future<void> save(PaystackCredentials value) async => credentials = value;

  @override
  Future<String> loadDeviceLabel() async => deviceLabel;

  @override
  Future<void> saveDeviceLabel(String label) async => deviceLabel = label;

  @override
  Future<void> clearRegistration() async => credentials = credentials.copyWith(baseUrl: '', apiKey: '');
}

void main() {
  late AppDatabase db;
  late CheckoutService checkoutService;
  late ProductRepositoryImpl productRepository;
  late String productId;
  late String userId;
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
    final saleRepository = SaleRepositoryImpl(db, db.salesDao, syncMeta, clock, idGen);
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
  });

  tearDown(() async {
    await db.close();
  });

  List<CartItem> oneWidget() => [
        CartItem(productId: productId, name: 'Widget', unitPrice: const Money(10000), costPrice: const Money(5000), quantity: 1),
      ];

  test('fails immediately when Paystack is not configured, without touching the network', () async {
    var called = false;
    final gateway = PaystackGateway(MockClient((request) async {
      called = true;
      throw StateError('should never be called');
    }));
    final service = PaystackPaymentService(
      gateway,
      _FakeCredentialsService(const PaystackCredentials(baseUrl: '', apiKey: '', currency: 'KES', defaultEmail: 'x@y.com')),
      checkoutService,
    );

    final result = await service.start(cart: oneWidget(), discount: const Money.zero(), saleType: 'retail', userId: userId);

    expect(result.isFailure, isTrue);
    expect(called, isFalse);
  });

  test('an empty cart is rejected before contacting Paystack', () async {
    var called = false;
    final gateway = PaystackGateway(MockClient((request) async {
      called = true;
      throw StateError('should never be called');
    }));
    final service = PaystackPaymentService(gateway, _FakeCredentialsService(configured), checkoutService);

    final result = await service.start(cart: const [], discount: const Money.zero(), saleType: 'retail', userId: userId);

    expect(result.isFailure, isTrue);
    expect(called, isFalse);
  });

  test('a successful start() reserves stock and returns the checkout session', () async {
    final gateway = PaystackGateway(MockClient((request) async {
      if (request.url.queryParameters['action'] == 'initialize_transaction') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['amount'], 10000);
        return http.Response(
          jsonEncode({
            'status': true,
            'data': {'authorization_url': 'https://paystack.test/pay/abc', 'reference': body['reference']},
          }),
          200,
        );
      }
      throw StateError('unexpected request: ${request.url}');
    }));
    final service = PaystackPaymentService(gateway, _FakeCredentialsService(configured), checkoutService);

    final result = await service.start(cart: oneWidget(), discount: const Money.zero(), saleType: 'retail', userId: userId);

    expect(result.isOk, isTrue);
    result.when(
      ok: (session) {
        expect(session.sale.status, 'pending');
        expect(session.authorizationUrl, 'https://paystack.test/pay/abc');
      },
      failure: (m) => fail(m),
    );

    final product = await productRepository.findById(productId);
    expect(product!.stockQty, 9, reason: 'stock must be reserved as soon as Paystack accepts the checkout');
  });

  test('a network failure during initialize is reported as needing internet, and nothing is written', () async {
    final gateway = PaystackGateway(MockClient((request) async {
      throw const SocketException('unreachable');
    }));
    final service = PaystackPaymentService(gateway, _FakeCredentialsService(configured), checkoutService);

    final result = await service.start(cart: oneWidget(), discount: const Money.zero(), saleType: 'retail', userId: userId);

    expect(result.isFailure, isTrue);
    result.when(
      ok: (_) => fail('expected failure'),
      failure: (m) => expect(m, 'Could not reach the payments server. Check your internet connection and try again.'),
    );

    final product = await productRepository.findById(productId);
    expect(product!.stockQty, 10, reason: 'a failed initialize must never reserve stock');
  });

  test('poll() finalizes the sale once Paystack confirms success', () async {
    final initGateway = PaystackGateway(MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'status': true,
          'data': {'authorization_url': 'https://paystack.test/pay/abc', 'reference': body['reference']},
        }),
        200,
      );
    }));
    final startService = PaystackPaymentService(initGateway, _FakeCredentialsService(configured), checkoutService);
    final started = await startService.start(cart: oneWidget(), discount: const Money.zero(), saleType: 'retail', userId: userId);
    late String saleId;
    late String reference;
    started.when(
      ok: (session) {
        saleId = session.sale.id;
        reference = session.reference;
      },
      failure: (m) => fail(m),
    );

    final verifyGateway = PaystackGateway(MockClient((request) async {
      return http.Response(
        jsonEncode({
          'status': true,
          'data': {'status': 'success', 'amount': 10000, 'currency': 'KES', 'reference': reference},
        }),
        200,
      );
    }));
    final pollService = PaystackPaymentService(verifyGateway, _FakeCredentialsService(configured), checkoutService);

    final outcome = await pollService.poll(saleId, reference, const Money(10000));
    expect(outcome, isA<PaystackPollPaid>());
    expect((outcome as PaystackPollPaid).sale.status, 'paid');
  });

  test('poll() reports waiting (never failure) on a still-pending or transient-error response', () async {
    final pendingGateway = PaystackGateway(MockClient((request) async {
      return http.Response(
        jsonEncode({
          'status': true,
          'data': {'status': 'abandoned', 'amount': 10000, 'currency': 'KES', 'reference': 'REF-X'},
        }),
        200,
      );
    }));
    final pendingService = PaystackPaymentService(pendingGateway, _FakeCredentialsService(configured), checkoutService);
    expect(await pendingService.poll('sale-x', 'REF-X', const Money(10000)), isA<PaystackPollWaiting>());

    final offlineGateway = PaystackGateway(MockClient((request) async {
      throw const SocketException('unreachable');
    }));
    final offlineService = PaystackPaymentService(offlineGateway, _FakeCredentialsService(configured), checkoutService);
    expect(await offlineService.poll('sale-x', 'REF-X', const Money(10000)), isA<PaystackPollWaiting>());
  });

  test('reconcilePendingSales silently finalizes a sale that was actually paid while the app was closed', () async {
    final initGateway = PaystackGateway(MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'status': true,
          'data': {'authorization_url': 'https://paystack.test/pay/abc', 'reference': body['reference']},
        }),
        200,
      );
    }));
    final startService = PaystackPaymentService(initGateway, _FakeCredentialsService(configured), checkoutService);
    final started = await startService.start(cart: oneWidget(), discount: const Money.zero(), saleType: 'retail', userId: userId);
    started.when(ok: (_) {}, failure: (m) => fail(m));

    // Simulates the app being killed outright while PaystackWaitingScreen
    // was still polling: a brand new PaystackPaymentService (as app.dart's
    // startup reconciliation would construct) finds the stranded sale and
    // discovers Paystack actually confirmed it in the meantime.
    final verifyGateway = PaystackGateway(MockClient((request) async {
      return http.Response(
        jsonEncode({
          'status': true,
          'data': {'status': 'success', 'amount': 10000, 'currency': 'KES', 'reference': 'irrelevant'},
        }),
        200,
      );
    }));
    final reconcileService = PaystackPaymentService(verifyGateway, _FakeCredentialsService(configured), checkoutService);

    final stillPending = await reconcileService.reconcilePendingSales();

    expect(stillPending, isEmpty, reason: 'a sale Paystack now confirms should be silently finalized, not surfaced');
    final sale = await checkoutService.pendingPaystackSales();
    expect(sale, isEmpty, reason: 'the finalized sale must no longer show up as pending');
  });

  test('reconcilePendingSales leaves a sale Paystack still does not confirm in the returned list', () async {
    final initGateway = PaystackGateway(MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'status': true,
          'data': {'authorization_url': 'https://paystack.test/pay/abc', 'reference': body['reference']},
        }),
        200,
      );
    }));
    final startService = PaystackPaymentService(initGateway, _FakeCredentialsService(configured), checkoutService);
    final started = await startService.start(cart: oneWidget(), discount: const Money.zero(), saleType: 'retail', userId: userId);
    late String saleId;
    started.when(ok: (session) => saleId = session.sale.id, failure: (m) => fail(m));

    final verifyGateway = PaystackGateway(MockClient((request) async {
      return http.Response(
        jsonEncode({
          'status': true,
          'data': {'status': 'abandoned', 'amount': 10000, 'currency': 'KES', 'reference': 'irrelevant'},
        }),
        200,
      );
    }));
    final reconcileService = PaystackPaymentService(verifyGateway, _FakeCredentialsService(configured), checkoutService);

    final stillPending = await reconcileService.reconcilePendingSales();

    expect(stillPending, hasLength(1));
    expect(stillPending.single.id, saleId);
    expect(stillPending.single.status, 'pending', reason: 'must not be touched until a human decides or Paystack confirms');
  });
}
