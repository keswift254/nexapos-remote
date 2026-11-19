import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nexapos_mobile/core/cart_shortcuts.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Product, Sale, User;
import 'package:nexapos_mobile/data/payments/payment_inbox_gateway.dart';
import 'package:nexapos_mobile/data/payments/platform_http_client.dart';
import 'package:nexapos_mobile/data/repositories/product_repository_impl.dart';
import 'package:nexapos_mobile/domain/entities/cart_item.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/entities/product.dart';
import 'package:nexapos_mobile/domain/entities/sale.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/repositories/product_repository.dart';
import 'package:nexapos_mobile/domain/services/paystack_credentials_service.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/domain/services/till_sale_service.dart';
import 'package:nexapos_mobile/features/checkout/cart_notifier.dart';
import 'package:nexapos_mobile/features/checkout/cart_screen.dart';
import 'package:nexapos_mobile/features/products/products_screen.dart';

/// "M-Pesa Till/Paybill" in the cart: the customer paid the shop's own till or paybill. The cart lists the payments the shop
/// phone passed on (unused ones, the one equal to the total marked), a tap puts the code in the box, and Complete Sale hands
/// it to TillSaleService - which says done (receipt), "ask first" (a bigger payment, an unread amount) or no (said plainly).
class _Session extends SessionNotifier {
  @override
  User? build() => const User(
        id: 'cashier-1',
        role: UserRole.cashier,
        name: 'Cashier',
        username: 'cashier',
        passwordHash: 'irrelevant-for-this-test',
        status: 'active',
      );
}

class _NoopProductRepository implements ProductRepository {
  const _NoopProductRepository();
  @override
  Future<Product?> findByBarcode(String barcode) async => null;
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName} was not expected');
}

class _Credentials implements PaystackCredentialsService {
  _Credentials(this.connected);
  final bool connected;
  @override
  Future<PaystackCredentials> load() async => PaystackCredentials(
        baseUrl: connected ? 'https://sync.test/index.php' : '',
        apiKey: connected ? 'device-key' : '',
        currency: 'KES',
        defaultEmail: 'x@y.z',
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The shop's list of payments: [lists] counts how often it was asked.
class _Inbox extends PaymentInboxGateway {
  _Inbox(this.payments, {this.phoneCount = 1, this.offline = false});
  List<TillPayment> payments;
  int phoneCount;
  bool offline;
  int lists = 0;
  final archived = <String>[];
  Object? archiveFails;

  @override
  Future<({List<TillPayment> payments, int phones})> list({required String baseUrl, required String apiKey, int hours = 24}) async {
    lists++;
    if (offline) throw const PaystackOfflineException();
    return (payments: payments, phones: phoneCount);
  }

  @override
  Future<TillPayment> archive({required String baseUrl, required String apiKey, required String code, bool archived = true}) async {
    if (archiveFails != null) throw archiveFails!;
    this.archived.add(code);
    final payment = payments.firstWhere((p) => p.code == code);
    payments = [for (final p in payments) if (p.code != code) p];
    return TillPayment(code: payment.code, messageReceived: true, amount: payment.amount, archivedAt: DateTime.utc(2026, 11, 18));
  }
}

class _Till implements TillSaleService {
  final calls = <({String code, bool acceptAmount, int items})>[];
  List<TillSaleOutcome> answers = [];

  @override
  Future<TillSaleOutcome> complete({
    required List<CartItem> cart,
    required Money discount,
    required String saleType,
    required String userId,
    required String typedCode,
    bool acceptAmount = false,
  }) async {
    calls.add((code: typedCode, acceptAmount: acceptAmount, items: cart.length));
    return answers.removeAt(0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TillPayment received(String code, int cents, String payer, {bool used = false, Duration? ago}) => TillPayment(
      code: code,
      messageReceived: true,
      amount: Money(cents),
      payerName: payer,
      paidAtText: '18/11/26 1:05 PM',
      receivedAt: ago == null ? null : DateTime.now().toUtc().subtract(ago),
      usedOnSaleNumber: used ? 'N-1' : null,
    );

Sale soldFor(int cents) => Sale(
      id: 'sale-1',
      saleNumber: 'ABC-1',
      userId: 'cashier-1',
      customerName: 'Walk-in customer',
      saleType: 'retail',
      paymentMethod: 'mpesa_manual',
      subtotal: Money(cents),
      discount: const Money.zero(),
      total: Money(cents),
      status: 'paid',
      createdAt: DateTime(2026, 11, 18, 13, 5),
    );

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late _Inbox inbox;
  late _Till till;

  /// The cart with 2 x 50.00 (total 100.00) and M-Pesa Till/Paybill chosen.
  Future<void> pumpCart(
    WidgetTester tester, {
    List<TillPayment>? payments,
    int phones = 1,
    bool offline = false,
    bool connected = true,
    List<TillSaleOutcome> answers = const [],
  }) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    inbox = _Inbox(payments ??
        [
          received('NEW1PAYM3N', 61000, 'JACINTA OMWENGA'),
          received('USED1PAYM3', 10000, 'ALREADY USED', used: true),
          const TillPayment(code: 'TYP3DCODE1', messageReceived: false, usedOnSaleNumber: 'N-2'),
          received('EX4CT10000', 10000, 'EXACT PAYER'),
        ], phoneCount: phones, offline: offline);
    till = _Till()..answers = [...answers];
    container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(_Session.new),
        appDatabaseProvider.overrideWithValue(db),
        allProductsProvider.overrideWith((ref) async => []),
        productRepositoryProvider.overrideWithValue(const _NoopProductRepository()),
        paystackCredentialsServiceProvider.overrideWithValue(_Credentials(connected)),
        paymentInboxGatewayProvider.overrideWithValue(inbox),
        tillSaleServiceProvider.overrideWithValue(till),
      ],
    );
    addTearDown(container.dispose);
    container.read(cartProvider.notifier).addManualItem(name: 'Loose sugar', quantity: 2, price: const Money(5000));
    container.read(cartProvider.notifier).setPaymentMethod('mpesa_manual');
    final router = GoRouter(
      initialLocation: '/cart',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Dashboard home'))),
        GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
        GoRoute(path: '/receipt/:id', builder: (_, state) => Scaffold(body: Text('Receipt ${state.pathParameters['id']}'))),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => CallbackShortcuts(bindings: CartShortcuts.bindings, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String codeTyped(WidgetTester tester) => tester.widget<TextField>(find.byKey(const Key('till-code'))).controller!.text;

  testWidgets('the cart offers M-Pesa Till/Paybill next to Cash and M-Pesa Prompt', (tester) async {
    await pumpCart(tester);
    expect(find.widgetWithText(ChoiceChip, 'M-Pesa Till/Paybill'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Cash'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'M-Pesa Prompt'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Complete Sale'), findsOneWidget);
  });

  testWidgets('only the payment of the sale total is shown; other amounts only when asked for; used or unarrived never', (tester) async {
    await pumpCart(tester);
    expect(find.byKey(const Key('till-payment-EX4CT10000')), findsOneWidget);
    final exact = find.byKey(const Key('till-payment-EX4CT10000'));
    expect(find.descendant(of: exact, matching: find.textContaining('the sale total', findRichText: true)), findsOneWidget);
    expect(find.byKey(const Key('till-payment-NEW1PAYM3N')), findsNothing, reason: 'another amount is not suggested');
    expect(find.text('Customer paid a different amount? Show the other payments (1)'), findsOneWidget);
    expect(till.calls, isEmpty, reason: 'a payment with no arrival time never completes a sale by itself');
    await tester.tap(find.byKey(const Key('till-others')));
    await tester.pump();
    expect(find.byKey(const Key('till-payment-NEW1PAYM3N')), findsOneWidget);
    expect(find.text('Payments of other amounts:'), findsOneWidget);
    expect(find.text('JACINTA OMWENGA'), findsOneWidget);
    expect(find.text('KES 610.00'), findsOneWidget);
    final other = find.byKey(const Key('till-payment-NEW1PAYM3N'));
    expect(find.descendant(of: other, matching: find.textContaining('the sale total', findRichText: true)), findsNothing);
    expect(find.byKey(const Key('till-payment-USED1PAYM3')), findsNothing, reason: 'used on another sale');
    expect(find.byKey(const Key('till-payment-TYP3DCODE1')), findsNothing, reason: 'no message arrived for it');
    await tester.tap(find.byKey(const Key('till-others')));
    await tester.pump();
    expect(find.byKey(const Key('till-payment-NEW1PAYM3N')), findsNothing, reason: 'hidden again');
  });

  testWidgets('the ONLY new payment of the sale total completes the sale by itself and shows the receipt', (tester) async {
    till.answers = [];
    await pumpCart(tester, payments: [
      received('AUT0PAYM3N', 10000, 'NEW PAYER', ago: const Duration(minutes: 1)),
      received('NEW1PAYM3N', 61000, 'JACINTA OMWENGA', ago: Duration.zero),
    ], answers: [TillSaleDone(soldFor(10000), received('AUT0PAYM3N', 10000, 'NEW PAYER'))]);
    expect(till.calls.single, (code: 'AUT0PAYM3N', acceptAmount: false, items: 1));
    expect(find.text('Receipt sale-1'), findsOneWidget);
    expect(container.read(cartProvider).isEmpty, isTrue);
  });

  testWidgets('two payments of the sale total: the cashier chooses; nothing is completed by itself', (tester) async {
    await pumpCart(tester, payments: [
      received('TW0PAYM3NA', 10000, 'FIRST PAYER', ago: Duration.zero),
      received('TW0PAYM3NB', 10000, 'SECOND PAYER', ago: const Duration(minutes: 2)),
    ], answers: [TillSaleDone(soldFor(10000), received('TW0PAYM3NB', 10000, 'SECOND PAYER'))]);
    await tester.pump(const Duration(seconds: 9));
    await tester.pump();
    expect(till.calls, isEmpty);
    expect(find.byKey(const Key('till-choose')), findsOneWidget);
    expect(find.textContaining('2 payments of KES 100.00 have arrived'), findsOneWidget);
    expect(find.byKey(const Key('till-payment-TW0PAYM3NA')), findsOneWidget);
    expect(find.byKey(const Key('till-payment-TW0PAYM3NB')), findsOneWidget);
    await tester.tap(find.byKey(const Key('till-payment-TW0PAYM3NB')));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Complete Sale'));
    await tester.pumpAndSettle();
    expect(till.calls.single.code, 'TW0PAYM3NB');
    expect(find.text('Receipt sale-1'), findsOneWidget);
  });

  testWidgets("a lone payment over 10 minutes old is only suggested: it may be an earlier customer's", (tester) async {
    await pumpCart(tester, payments: [received('0LDPAYM3NT', 10000, 'EARLIER PAYER', ago: const Duration(minutes: 20))]);
    await tester.pump(const Duration(seconds: 9));
    await tester.pump();
    expect(till.calls, isEmpty);
    expect(find.byKey(const Key('till-older')), findsOneWidget);
    expect(find.textContaining('arrived more than 10 minutes ago'), findsOneWidget);
    expect(find.byKey(const Key('till-payment-0LDPAYM3NT')), findsOneWidget);
  });

  testWidgets('a payment that arrives while the cart waits completes the sale on the next refresh', (tester) async {
    await pumpCart(tester, payments: const [], answers: [TillSaleDone(soldFor(10000), received('LAT3ARR1VE', 10000, 'LATE PAYER'))]);
    expect(find.byKey(const Key('till-waiting')), findsOneWidget);
    expect(find.textContaining('Waiting for a payment of KES 100.00'), findsOneWidget);
    inbox.payments = [received('LAT3ARR1VE', 10000, 'LATE PAYER', ago: Duration.zero)];
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(till.calls.single.code, 'LAT3ARR1VE');
    expect(find.text('Receipt sale-1'), findsOneWidget);
  });

  testWidgets('a change to the total that makes a new payment fit completes the sale', (tester) async {
    await pumpCart(tester, payments: [received('D1SCOUNT90', 9000, 'DISCOUNT PAYER', ago: Duration.zero)],
        answers: [TillSaleDone(soldFor(9000), received('D1SCOUNT90', 9000, 'DISCOUNT PAYER'))]);
    expect(till.calls, isEmpty, reason: '90.00 does not fit a sale of 100.00');
    await tester.enterText(find.widgetWithText(TextField, 'Discount'), '10');
    await tester.pumpAndSettle();
    expect(till.calls.single.code, 'D1SCOUNT90');
    expect(find.text('Receipt sale-1'), findsOneWidget);
  });

  testWidgets('a refused automatic try is said once and not repeated every refresh', (tester) async {
    await pumpCart(tester, payments: [received('R3FUS3DPAY', 10000, 'TAKEN PAYER', ago: Duration.zero)],
        answers: [const TillSaleRefused('This M-Pesa code was already used on sale ABC-1.', refreshList: true)]);
    expect(till.calls, hasLength(1));
    expect(find.text('This M-Pesa code was already used on sale ABC-1.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(till.calls, hasLength(1), reason: 'the same payment is not tried again by itself');
    // even once the cashier empties the code box, that payment is not tried again by itself
    await tester.enterText(find.byKey(const Key('till-code')), '');
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(till.calls, hasLength(1), reason: 'an emptied box does not start the refused payment again');
    expect(container.read(cartProvider).isEmpty, isFalse, reason: 'nothing was sold');
  });

  testWidgets('a code the cashier typed is left alone: nothing is completed by itself', (tester) async {
    await pumpCart(tester, payments: const []);
    await tester.enterText(find.byKey(const Key('till-code')), 'MYC0DE1234');
    inbox.payments = [received('N3WFITT1NG', 10000, 'NEW PAYER', ago: Duration.zero)];
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(till.calls, isEmpty);
    expect(codeTyped(tester), 'MYC0DE1234');
  });

  testWidgets('tapping a payment puts its code in the box', (tester) async {
    await pumpCart(tester);
    expect(codeTyped(tester), '');
    await tester.tap(find.byKey(const Key('till-payment-EX4CT10000')));
    await tester.pump();
    expect(codeTyped(tester), 'EX4CT10000');
  });

  testWidgets('Complete Sale hands the code and the cart over, then shows the receipt', (tester) async {
    await pumpCart(tester);
    till.answers = [TillSaleDone(soldFor(10000), received('EX4CT10000', 10000, 'EXACT PAYER'))];
    await tester.tap(find.byKey(const Key('till-payment-EX4CT10000')));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Complete Sale'));
    await tester.pumpAndSettle();
    expect(till.calls.single, (code: 'EX4CT10000', acceptAmount: false, items: 1));
    expect(find.text('Receipt sale-1'), findsOneWidget);
    expect(container.read(cartProvider).isEmpty, isTrue, reason: 'the sale is done, the cart is empty');
    expect(find.textContaining('Give back'), findsNothing);
  });

  testWidgets('a typed code goes as typed (the service cleans it up)', (tester) async {
    await pumpCart(tester);
    till.answers = [const TillSaleRefused('No M-Pesa payment with this code has reached the shop yet.', refreshList: true)];
    await tester.enterText(find.byKey(const Key('till-code')), 'ukh3 r3nltu');
    await tester.tap(find.widgetWithText(FilledButton, 'Complete Sale'));
    await tester.pumpAndSettle();
    expect(till.calls.single.code, 'ukh3 r3nltu');
  });

  testWidgets('a bigger payment is asked about; Complete the sale tries again accepting it, and says what to give back', (tester) async {
    await pumpCart(tester);
    till.answers = [
      const TillSaleNeedsConfirmation(paid: Money(61000), total: Money(10000)),
      TillSaleDone(soldFor(10000), received('NEW1PAYM3N', 61000, 'JACINTA OMWENGA')),
    ];
    await tester.tap(find.byKey(const Key('till-others')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('till-payment-NEW1PAYM3N')));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Complete Sale'));
    await tester.pumpAndSettle();
    expect(find.text('The customer paid more'), findsOneWidget);
    expect(find.textContaining('paid KES 610.00 for a sale of KES 100.00'), findsOneWidget);
    expect(find.textContaining('Give back KES 510.00 in cash'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Complete the sale'));
    await tester.pumpAndSettle();
    expect(till.calls.map((c) => c.acceptAmount), [false, true]);
    expect(find.text('Receipt sale-1'), findsOneWidget);
    expect(find.text('The customer paid KES 610.00. Give back KES 510.00 in cash.'), findsOneWidget, reason: 'said again on the receipt');
  });

  testWidgets('Cancel on that question sells nothing', (tester) async {
    await pumpCart(tester);
    till.answers = [const TillSaleNeedsConfirmation(paid: null, total: Money(10000))];
    await tester.enterText(find.byKey(const Key('till-code')), 'UNR3ADABL1');
    await tester.tap(find.widgetWithText(FilledButton, 'Complete Sale'));
    await tester.pumpAndSettle();
    expect(find.text('Amount not read'), findsOneWidget);
    expect(find.textContaining('Did the customer pay at least KES 100.00?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(till.calls, hasLength(1));
    expect(container.read(cartProvider).isEmpty, isFalse, reason: 'the sale is still in the cart');
    expect(find.text('Receipt sale-1'), findsNothing);
  });

  testWidgets('a refusal is said, nothing is sold, and when the payments changed the list is loaded again', (tester) async {
    await pumpCart(tester);
    final before = inbox.lists;
    till.answers = [const TillSaleRefused('This M-Pesa code was already used on sale ABC-1.', refreshList: true)];
    await tester.tap(find.byKey(const Key('till-payment-EX4CT10000')));
    await tester.tap(find.widgetWithText(FilledButton, 'Complete Sale'));
    await tester.pumpAndSettle();
    expect(find.text('This M-Pesa code was already used on sale ABC-1.'), findsOneWidget);
    expect(container.read(cartProvider).isEmpty, isFalse);
    expect(inbox.lists, greaterThan(before));
  });

  testWidgets('F9 completes a till sale too', (tester) async {
    await pumpCart(tester);
    till.answers = [TillSaleDone(soldFor(10000), received('EX4CT10000', 10000, 'EXACT PAYER'))];
    await tester.tap(find.byKey(const Key('till-payment-EX4CT10000')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f9);
    await tester.pumpAndSettle();
    expect(till.calls.single.code, 'EX4CT10000');
    expect(find.text('Receipt sale-1'), findsOneWidget);
  });

  testWidgets('the list refreshes by itself, and with Refresh', (tester) async {
    await pumpCart(tester);
    final first = inbox.lists;
    inbox.payments = [received('LAT3PAYM3N', 10000, 'LATE PAYER')];
    await tester.pump(const Duration(seconds: 9));
    await tester.pump();
    expect(inbox.lists, greaterThan(first));
    expect(find.text('LATE PAYER'), findsOneWidget);
    final second = inbox.lists;
    await tester.tap(find.byKey(const Key('till-refresh')));
    await tester.pump();
    expect(inbox.lists, greaterThan(second));
  });

  testWidgets('an archived payment is not suggested', (tester) async {
    await pumpCart(tester, payments: [
      received('NEW1PAYM3N', 61000, 'JACINTA OMWENGA'),
      TillPayment(code: 'ARCH1VED11', messageReceived: true, amount: const Money(10000), payerName: 'OLD PAYER', archivedAt: DateTime.utc(2026, 11, 18)),
    ]);
    expect(find.byKey(const Key('till-payment-ARCH1VED11')), findsNothing, reason: 'not even as the sale total');
    expect(find.byKey(const Key('till-waiting')), findsOneWidget, reason: 'nothing of 100.00 left to suggest');
    await tester.tap(find.byKey(const Key('till-others')));
    await tester.pump();
    expect(find.byKey(const Key('till-payment-NEW1PAYM3N')), findsOneWidget);
    expect(find.byKey(const Key('till-payment-ARCH1VED11')), findsNothing);
  });

  testWidgets('swiping a payment from right to left asks first; Archive archives it and it is no longer suggested', (tester) async {
    await pumpCart(tester);
    await tester.tap(find.byKey(const Key('till-payment-EX4CT10000')));
    await tester.pump();
    expect(codeTyped(tester), 'EX4CT10000');
    await tester.drag(find.byKey(const Key('till-payment-EX4CT10000')), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Archive this payment?'), findsOneWidget);
    expect(find.textContaining('Are you sure you want to archive this payment?'), findsOneWidget);
    expect(find.textContaining('EXACT PAYER, KES 100.00, EX4CT10000'), findsOneWidget);
    expect(inbox.archived, isEmpty, reason: 'nothing happens before the answer');
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();
    expect(inbox.archived, ['EX4CT10000']);
    expect(find.byKey(const Key('till-payment-EX4CT10000')), findsNothing);
    expect(find.text('Customer paid a different amount? Show the other payments (1)'), findsOneWidget, reason: 'the others stay');
    expect(find.textContaining('Archived: EXACT PAYER'), findsOneWidget);
    expect(codeTyped(tester), '', reason: 'the code of the archived payment is taken out of the box');
  });

  testWidgets('Cancel keeps the payment where it was', (tester) async {
    await pumpCart(tester);
    await tester.drag(find.byKey(const Key('till-payment-EX4CT10000')), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(inbox.archived, isEmpty);
    expect(find.byKey(const Key('till-payment-EX4CT10000')), findsOneWidget);
  });

  testWidgets('a swipe the other way (left to right) does nothing', (tester) async {
    await pumpCart(tester);
    await tester.drag(find.byKey(const Key('till-payment-EX4CT10000')), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Archive this payment?'), findsNothing);
    expect(find.byKey(const Key('till-payment-EX4CT10000')), findsOneWidget);
  });

  testWidgets('when the shop cannot be reached the payment stays, and it is said', (tester) async {
    await pumpCart(tester);
    inbox.archiveFails = const PaystackOfflineException();
    await tester.drag(find.byKey(const Key('till-payment-EX4CT10000')), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('till-payment-EX4CT10000')), findsOneWidget);
    expect(find.textContaining('could not be archived'), findsOneWidget);
  });

  testWidgets('no shop phone, no internet, or a device not connected: said plainly, and the code can still be typed', (tester) async {
    await pumpCart(tester, payments: const [], phones: 0);
    expect(find.byKey(const Key('till-no-phone')), findsOneWidget);
    expect(find.byKey(const Key('till-code')), findsOneWidget);
  });

  testWidgets('no internet is said plainly', (tester) async {
    await pumpCart(tester, offline: true);
    expect(find.textContaining('No internet'), findsOneWidget);
  });

  testWidgets('a device not connected to the shop is said plainly', (tester) async {
    await pumpCart(tester, connected: false);
    expect(find.textContaining('not connected to the shop sync service'), findsOneWidget);
    expect(inbox.lists, 0, reason: 'nothing is asked without the shop\'s address and key');
  });
}
