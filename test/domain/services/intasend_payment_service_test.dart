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
import 'package:nexapos_mobile/data/payments/intasend_gateway.dart';
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
import 'package:nexapos_mobile/domain/services/intasend_payment_service.dart';
import 'package:nexapos_mobile/domain/services/paystack_credentials_service.dart';
import 'package:nexapos_mobile/domain/services/stock_service.dart';

/// Same plain-Dart stand-in as paystack_payment_service_test.dart uses -
/// IntaSendPaymentService deliberately reuses PaystackCredentialsService
/// (same operator backend, same device Bearer token), so this fake is
/// shared conceptually even though each test file defines its own copy.
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

  test('fails immediately when not configured, without touching the network', () async {
    var called = false;
    final gateway = IntaSendGateway(MockClient((request) async {
      called = true;
      throw StateError('should never be called');
    }));
    final service = IntaSendPaymentService(
      gateway,
      _FakeCredentialsService(const PaystackCredentials(baseUrl: '', apiKey: '', currency: 'KES', defaultEmail: 'x@y.com')),
      checkoutService,
    );

    final result = await service.start(cart: oneWidget(), discount: const Money.zero(), customerPhone: '0712345678', saleType: 'retail', userId: userId);

    expect(result.isFailure, isTrue);
    expect(called, isFalse);
  });

  test('an empty cart is rejected before contacting IntaSend', () async {
    var called = false;
    final gateway = IntaSendGateway(MockClient((request) async {
      called = true;
      throw StateError('should never be called');
    }));
    final service = IntaSendPaymentService(gateway, _FakeCredentialsService(configured), checkoutService);

    final result = await service.start(cart: const [], discount: const Money.zero(), customerPhone: '0712345678', saleType: 'retail', userId: userId);

    expect(result.isFailure, isTrue);
    expect(called, isFalse);
  });

  test('a missing or unrecognizable phone number is rejected before contacting IntaSend', () async {
    var called = false;
    final gateway = IntaSendGateway(MockClient((request) async {
      called = true;
      throw StateError('should never be called');
    }));
    final service = IntaSendPaymentService(gateway, _FakeCredentialsService(configured), checkoutService);

    final result = await service.start(cart: oneWidget(), discount: const Money.zero(), customerPhone: '', saleType: 'retail', userId: userId);

    expect(result.isFailure, isTrue);
    expect(called, isFalse);
  });

  test('a successful start() normalizes a local 07xx number, reserves stock, and returns the session', () async {
    final gateway = IntaSendGateway(MockClient((request) async {
      expect(request.url.queryParameters['action'], 'intasend_collect');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['amount'], 10000);
      expect(body['phone_number'], '254712345678');
      return http.Response(
        jsonEncode({
          'status': true,
          'data': {'reference': body['reference'], 'invoice_id': 'INV-1'},
        }),
        200,
      );
    }));
    final service = IntaSendPaymentService(gateway, _FakeCredentialsService(configured), checkoutService);

    final result = await service.start(
      cart: oneWidget(),
      discount: const Money.zero(),
      customerPhone: '0712345678',
      saleType: 'retail',
      userId: userId,
    );

    expect(result.isOk, isTrue);
    result.when(
      ok: (session) {
        expect(session.sale.status, 'pending');
        expect(session.phoneNumber, '254712345678');
      },
      failure: (m) => fail(m),
    );

    final product = await productRepository.findById(productId);
    expect(product!.stockQty, 9, reason: 'stock must be reserved as soon as IntaSend accepts the STK push');
  });

  test('a network failure during collect does not blame the device\'s own connection, and nothing is written', () async {
    final gateway = IntaSendGateway(MockClient((request) async {
      throw const SocketException('unreachable');
    }));
    final service = IntaSendPaymentService(gateway, _FakeCredentialsService(configured), checkoutService);

    final result = await service.start(cart: oneWidget(), discount: const Money.zero(), customerPhone: '0712345678', saleType: 'retail', userId: userId);

    expect(result.isFailure, isTrue);
    result.when(
      ok: (_) => fail('expected failure'),
      // Not "check your internet connection" - this is thrown just as
      // easily when the payments SERVER is unreachable with the device's
      // own connection working fine (confirmed for real), so it must not
      // assert that as the diagnosis.
      failure: (m) {
        expect(m, isNot(contains('your internet')));
        expect(m, 'Could not reach the payments server right now. Try again in a moment.');
      },
    );

    final product = await productRepository.findById(productId);
    expect(product!.stockQty, 10, reason: 'a failed collect must never reserve stock');
  });

  test('a slow-to-respond payments server says so, distinctly from a plain connection failure', () async {
    final gateway = IntaSendGateway(MockClient((request) async {
      throw TimeoutException('no answer');
    }));
    final service = IntaSendPaymentService(gateway, _FakeCredentialsService(configured), checkoutService);

    final result = await service.start(cart: oneWidget(), discount: const Money.zero(), customerPhone: '0712345678', saleType: 'retail', userId: userId);

    result.when(
      ok: (_) => fail('expected failure'),
      failure: (m) => expect(m, 'The payments server is taking a while to respond. Try again in a moment.'),
    );
  });

  test('poll() finalizes the sale once IntaSend confirms success', () async {
    final initGateway = IntaSendGateway(MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'status': true,
          'data': {'reference': body['reference'], 'invoice_id': 'INV-1'},
        }),
        200,
      );
    }));
    final startService = IntaSendPaymentService(initGateway, _FakeCredentialsService(configured), checkoutService);
    final started = await startService.start(cart: oneWidget(), discount: const Money.zero(), customerPhone: '0712345678', saleType: 'retail', userId: userId);
    late String saleId;
    late String reference;
    started.when(
      ok: (session) {
        saleId = session.sale.id;
        reference = session.reference;
      },
      failure: (m) => fail(m),
    );

    final verifyGateway = IntaSendGateway(MockClient((request) async {
      return http.Response(
        jsonEncode({
          'status': true,
          'data': {'status': 'success', 'amount': 10000, 'currency': 'KES', 'reference': reference},
        }),
        200,
      );
    }));
    final pollService = IntaSendPaymentService(verifyGateway, _FakeCredentialsService(configured), checkoutService);

    final outcome = await pollService.poll(saleId, reference, const Money(10000));
    expect(outcome, isA<IntaSendPollPaid>());
    expect((outcome as IntaSendPollPaid).sale.status, 'paid');
  });

  test('reconcilePendingSales only picks up intasend sales, not paystack ones', () async {
    final saleNumber = await checkoutService.generateSaleNumber();
    final paystackBegin = await checkoutService.beginPaystackSale(
      cart: oneWidget(),
      discount: const Money.zero(),
      saleType: 'retail',
      userId: userId,
      saleNumber: saleNumber,
      paystackReference: saleNumber,
    );
    expect(paystackBegin.isOk, isTrue);

    final gateway = IntaSendGateway(MockClient((request) async {
      throw StateError('a paystack-only pending sale must never be sent to IntaSend');
    }));
    final service = IntaSendPaymentService(gateway, _FakeCredentialsService(configured), checkoutService);

    final stillPending = await service.reconcilePendingSales();
    expect(stillPending, isEmpty);
  });
}
