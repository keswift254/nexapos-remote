import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/result.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Product, User;
import 'package:nexapos_mobile/data/repositories/product_repository_impl.dart';
import 'package:nexapos_mobile/domain/entities/cart_item.dart';
import 'package:nexapos_mobile/domain/entities/product.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/repositories/product_repository.dart';
import 'package:nexapos_mobile/domain/services/paystack_payment_service.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/features/checkout/cart_notifier.dart';
import 'package:nexapos_mobile/features/checkout/cart_screen.dart';
import 'package:nexapos_mobile/features/products/products_screen.dart';

/// Choosing "M-Pesa Prompt" in the cart asks for the customer's number and sends the prompt to it - no payment page.
/// The way to the payment page (for a customer paying by card) is still there, as a smaller choice.
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

/// Remembers what the cart asked it to start, and answers "the server is not reachable" so no waiting screen opens.
class _RecordingPaystack implements PaystackPaymentService {
  final starts = <({String mpesaPhone, Money? cashReceived, int items})>[];

  @override
  Future<Result<PaystackCheckoutSession>> start({
    required List<CartItem> cart,
    required Money discount,
    String customerName = '',
    String customerPhone = '',
    required String saleType,
    required String userId,
    Money? cashReceived,
    String mpesaPhone = '',
  }) async {
    starts.add((mpesaPhone: mpesaPhone, cashReceived: cashReceived, items: cart.length));
    return const Result.failure('Could not reach the payments server right now. Try again in a moment.');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late _RecordingPaystack paystack;

  Future<void> pumpCart(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    paystack = _RecordingPaystack();
    container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(_Session.new),
        appDatabaseProvider.overrideWithValue(db),
        allProductsProvider.overrideWith((ref) async => []),
        productRepositoryProvider.overrideWithValue(const _NoopProductRepository()),
        paystackPaymentServiceProvider.overrideWithValue(paystack),
      ],
    );
    addTearDown(container.dispose);
    container.read(cartProvider.notifier).addManualItem(name: 'Loose sugar', quantity: 2, price: const Money(5000));
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MaterialApp(home: CartScreen())),
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseMpesaPrompt(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ChoiceChip, 'M-Pesa Prompt'));
    await tester.pumpAndSettle();
  }

  testWidgets('cash: no number field, and the button still says Complete Sale', (tester) async {
    await pumpCart(tester);

    expect(find.byKey(const Key('mpesa-phone')), findsNothing);
    expect(find.byKey(const Key('use-payment-page')), findsNothing);
    expect(find.text('Complete Sale'), findsOneWidget);
    expect(find.text('Send M-Pesa prompt'), findsNothing);
  });

  testWidgets('M-Pesa Prompt: asks for the customer\'s number and the button says what it does', (tester) async {
    await pumpCart(tester);
    await chooseMpesaPrompt(tester);

    expect(find.byKey(const Key('mpesa-phone')), findsOneWidget);
    expect(find.text('Customer\'s M-Pesa number'), findsOneWidget);
    expect(find.text('Send M-Pesa prompt'), findsOneWidget);
    expect(find.text('Complete Sale'), findsNothing);
    expect(find.byKey(const Key('use-payment-page')), findsOneWidget, reason: 'card payers can still use the payment page');
  });

  testWidgets('no number: nothing is sent, and the cashier is told what to enter', (tester) async {
    await pumpCart(tester);
    await chooseMpesaPrompt(tester);

    await tester.tap(find.text('Send M-Pesa prompt'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the customer\'s M-Pesa number, like 0712 345 678.'), findsOneWidget);
    expect(paystack.starts, isEmpty);
    expect(container.read(cartProvider).items, hasLength(1), reason: 'the cart is untouched');
  });

  testWidgets('a number that cannot be right: nothing is sent', (tester) async {
    await pumpCart(tester);
    await chooseMpesaPrompt(tester);

    await tester.enterText(find.byKey(const Key('mpesa-phone')), '12345');
    await tester.tap(find.text('Send M-Pesa prompt'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the customer\'s M-Pesa number, like 0712 345 678.'), findsOneWidget);
    expect(paystack.starts, isEmpty);
  });

  testWidgets('a good number: the prompt is asked for with that number, as typed', (tester) async {
    await pumpCart(tester);
    await chooseMpesaPrompt(tester);

    await tester.enterText(find.byKey(const Key('mpesa-phone')), '0712 345 678');
    expect(container.read(cartProvider).customerPhone, '0712 345 678', reason: 'kept with the cart, so it survives a restart');
    await tester.tap(find.text('Send M-Pesa prompt'));
    await tester.pumpAndSettle();

    expect(paystack.starts, hasLength(1));
    expect(paystack.starts.single.mpesaPhone, '0712 345 678');
    expect(paystack.starts.single.cashReceived, isNull);
    expect(find.text('Could not reach the payments server right now. Try again in a moment.'), findsOneWidget,
        reason: 'a refused start shows the reason and keeps the cart');
    expect(container.read(cartProvider).items, hasLength(1));
  });

  testWidgets('"open the payment page" sends no number, so the payment page is used as before - and needs no number', (tester) async {
    await pumpCart(tester);
    await chooseMpesaPrompt(tester);

    await tester.tap(find.byKey(const Key('use-payment-page')));
    await tester.pumpAndSettle();

    expect(paystack.starts, hasLength(1));
    expect(paystack.starts.single.mpesaPhone, isEmpty);
  });

  testWidgets('"open the payment page" ignores a number typed earlier', (tester) async {
    await pumpCart(tester);
    await chooseMpesaPrompt(tester);
    await tester.enterText(find.byKey(const Key('mpesa-phone')), '0712 345 678');

    await tester.tap(find.byKey(const Key('use-payment-page')));
    await tester.pumpAndSettle();

    expect(paystack.starts.single.mpesaPhone, isEmpty, reason: 'a card customer is not sent a prompt');
  });

  testWidgets('cash that falls short: the prompt for the rest needs the number too', (tester) async {
    await pumpCart(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Cash received (optional)'), '40');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mpesa-phone-split')), findsOneWidget);

    await tester.tap(find.textContaining('Send M-Pesa prompt for'));
    await tester.pumpAndSettle();
    expect(paystack.starts, isEmpty, reason: 'no number yet');
    expect(find.text('Enter the customer\'s M-Pesa number, like 0712 345 678.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('mpesa-phone-split')), '0712 345 678');
    await tester.tap(find.textContaining('Send M-Pesa prompt for'));
    await tester.pumpAndSettle();

    expect(paystack.starts, hasLength(1));
    expect(paystack.starts.single.mpesaPhone, '0712 345 678');
    expect(paystack.starts.single.cashReceived, const Money(4000));
  });

  testWidgets('a number kept with the cart is there when the cart screen opens again', (tester) async {
    await pumpCart(tester);
    await chooseMpesaPrompt(tester);
    await tester.enterText(find.byKey(const Key('mpesa-phone')), '0799 111 222');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MaterialApp(home: CartScreen())),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byKey(const Key('mpesa-phone'))).controller!.text, '0799 111 222');
  });

  testWidgets('when the cart is replaced (a restored sale), the number field follows', (tester) async {
    await pumpCart(tester);
    await chooseMpesaPrompt(tester);

    container.read(cartProvider.notifier).setCustomerPhone('0733 000 111');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byKey(const Key('mpesa-phone'))).controller!.text, '0733 000 111');
  });
}
