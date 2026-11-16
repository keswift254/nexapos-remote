import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/cart_shortcuts.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/result.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Product, Sale, User;
import 'package:nexapos_mobile/data/repositories/product_repository_impl.dart';
import 'package:nexapos_mobile/domain/entities/cart_item.dart';
import 'package:nexapos_mobile/domain/entities/product.dart';
import 'package:nexapos_mobile/domain/entities/sale.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/repositories/product_repository.dart';
import 'package:nexapos_mobile/domain/services/checkout_service.dart';
import 'package:nexapos_mobile/domain/services/paystack_payment_service.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/features/checkout/cart_notifier.dart';
import 'package:nexapos_mobile/features/checkout/cart_screen.dart';
import 'package:nexapos_mobile/features/products/products_screen.dart';

/// The cashier's keyboard in the cart: F8 switches Cash <-> M-Pesa Prompt, F9 (or Ctrl+Enter) does what the big button does,
/// choosing M-Pesa Prompt puts the cursor in the customer's number, and the hover hints name the keys.
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

class _RecordingPaystack implements PaystackPaymentService {
  final starts = <String>[];

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
    starts.add(mpesaPhone);
    return const Result.failure('Could not reach the payments server right now. Try again in a moment.');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A prompt that is still being sent: the answer comes only when the test lets it.
class _SlowPaystack extends _RecordingPaystack {
  final release = Completer<void>();

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
    starts.add(mpesaPhone);
    await release.future;
    return const Result.failure('Could not reach the payments server right now. Try again in a moment.');
  }
}

/// Remembers the cash sales the cart asked for and refuses them, so the screen stays where it is.
class _RecordingCheckout implements CheckoutService {
  final sales = <({String paymentMethod, Money? cashReceived})>[];

  @override
  Future<Result<Sale>> checkout({
    required List<CartItem> cart,
    required Money discount,
    String customerName = '',
    String customerPhone = '',
    required String saleType,
    required String paymentMethod,
    String? referenceNote,
    required String userId,
    Money? cashReceived,
  }) async {
    sales.add((paymentMethod: paymentMethod, cashReceived: cashReceived));
    return const Result.failure('Pretend the sale was refused.');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late _RecordingPaystack paystack;
  late _RecordingCheckout checkout;

  Future<void> pumpCart(WidgetTester tester, {bool emptyCart = false, _RecordingPaystack? slow}) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    paystack = slow ?? _RecordingPaystack();
    checkout = _RecordingCheckout();
    container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(_Session.new),
        appDatabaseProvider.overrideWithValue(db),
        allProductsProvider.overrideWith((ref) async => []),
        productRepositoryProvider.overrideWithValue(const _NoopProductRepository()),
        paystackPaymentServiceProvider.overrideWithValue(paystack),
        checkoutServiceProvider.overrideWithValue(checkout),
      ],
    );
    addTearDown(container.dispose);
    if (!emptyCart) {
      container.read(cartProvider.notifier).addManualItem(name: 'Loose sugar', quantity: 2, price: const Money(5000));
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          // The same table the app puts around every page (app.dart).
          builder: (context, child) => CallbackShortcuts(bindings: CartShortcuts.bindings, child: child!),
          home: const CartScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String methodOf() => container.read(cartProvider).paymentMethod;

  FocusNode? focusedNode() => FocusManager.instance.primaryFocus;

  bool phoneFieldHasFocus(WidgetTester tester) {
    final field = tester.widget<TextField>(find.byKey(const Key('mpesa-phone')));
    return field.focusNode!.hasPrimaryFocus;
  }

  Future<void> pressKey(WidgetTester tester, LogicalKeyboardKey key, {bool control = false}) async {
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  testWidgets('F8 switches Cash -> M-Pesa Prompt -> Cash, and back again each time', (tester) async {
    await pumpCart(tester);
    expect(methodOf(), 'cash');

    await pressKey(tester, LogicalKeyboardKey.f8);
    expect(methodOf(), 'paystack');
    expect(find.text('Send M-Pesa prompt'), findsOneWidget);

    await pressKey(tester, LogicalKeyboardKey.f8);
    expect(methodOf(), 'cash');
    expect(find.text('Complete Sale'), findsOneWidget);

    await pressKey(tester, LogicalKeyboardKey.f8);
    expect(methodOf(), 'paystack');
  });

  testWidgets('choosing M-Pesa Prompt (by F8) puts the cursor in the customer\'s number field, ready to type', (tester) async {
    await pumpCart(tester);
    await pressKey(tester, LogicalKeyboardKey.f8);

    expect(phoneFieldHasFocus(tester), isTrue);
    await tester.enterText(find.byKey(const Key('mpesa-phone')), '0712 345 678');
    expect(container.read(cartProvider).customerPhone, '0712 345 678');
  });

  testWidgets('choosing M-Pesa Prompt with the mouse puts the cursor there too', (tester) async {
    await pumpCart(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'M-Pesa Prompt'));
    await tester.pumpAndSettle();

    expect(methodOf(), 'paystack');
    expect(phoneFieldHasFocus(tester), isTrue);
  });

  testWidgets('going back to Cash puts the cursor in the cash received field', (tester) async {
    await pumpCart(tester);
    await pressKey(tester, LogicalKeyboardKey.f8);
    await pressKey(tester, LogicalKeyboardKey.f8);

    final cash = tester.widget<TextField>(find.widgetWithText(TextField, 'Cash received (optional)'));
    expect(cash.focusNode!.hasPrimaryFocus, isTrue);
  });

  testWidgets('clicking the method that is already chosen moves nothing', (tester) async {
    await pumpCart(tester);
    await tester.tap(find.byType(TextField).first); // the search box has the cursor
    await tester.pump();
    final before = focusedNode();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Cash'));
    await tester.pumpAndSettle();
    expect(methodOf(), 'cash');
    expect(focusedNode(), before);
  });

  testWidgets('F9 completes a cash sale: the same sale the big button would make', (tester) async {
    await pumpCart(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Cash received (optional)'), '150');

    await pressKey(tester, LogicalKeyboardKey.f9);

    expect(checkout.sales, hasLength(1));
    expect(checkout.sales.single.paymentMethod, 'cash');
    expect(checkout.sales.single.cashReceived, const Money(15000));
    expect(paystack.starts, isEmpty);
  });

  testWidgets('Ctrl+Enter does the same as F9, even while typing in the search box', (tester) async {
    await pumpCart(tester);
    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'sug');
    await tester.pump();

    await pressKey(tester, LogicalKeyboardKey.enter, control: true);

    expect(checkout.sales, hasLength(1));
  });

  testWidgets('F9 with M-Pesa Prompt chosen sends the prompt to the number typed', (tester) async {
    await pumpCart(tester);
    await pressKey(tester, LogicalKeyboardKey.f8);
    await tester.enterText(find.byKey(const Key('mpesa-phone')), '0712 345 678');

    await pressKey(tester, LogicalKeyboardKey.f9);

    expect(paystack.starts, ['0712 345 678']);
    expect(checkout.sales, isEmpty, reason: 'no cash sale was made');
  });

  testWidgets('F9 with M-Pesa Prompt chosen and no number: nothing is sent, and the cashier is told', (tester) async {
    await pumpCart(tester);
    await pressKey(tester, LogicalKeyboardKey.f8);

    await pressKey(tester, LogicalKeyboardKey.f9);

    expect(paystack.starts, isEmpty);
    expect(find.text('Enter the customer\'s M-Pesa number, like 0712 345 678.'), findsOneWidget);
  });

  testWidgets('F9 pressed again while the prompt is still being sent does not send it twice', (tester) async {
    final slow = _SlowPaystack();
    await pumpCart(tester, slow: slow);
    await pressKey(tester, LogicalKeyboardKey.f8);
    await tester.enterText(find.byKey(const Key('mpesa-phone')), '0712 345 678');

    await tester.sendKeyEvent(LogicalKeyboardKey.f9);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f9);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(slow.starts, hasLength(1), reason: 'one prompt, however many times the key is pressed');
    slow.release.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('F8 while a sale is being sent does not change the payment method under it', (tester) async {
    final slow = _SlowPaystack();
    await pumpCart(tester, slow: slow);
    await pressKey(tester, LogicalKeyboardKey.f8);
    await tester.enterText(find.byKey(const Key('mpesa-phone')), '0712 345 678');
    await tester.sendKeyEvent(LogicalKeyboardKey.f9);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.f8);
    await tester.pump();

    expect(methodOf(), 'paystack');
    slow.release.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('F9 with an empty cart does nothing', (tester) async {
    await pumpCart(tester, emptyCart: true);
    await pressKey(tester, LogicalKeyboardKey.f9);
    expect(checkout.sales, isEmpty);
    expect(paystack.starts, isEmpty);
  });

  testWidgets('F9 when the cash received is less than the total does not complete the sale, and says why', (tester) async {
    await pumpCart(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Cash received (optional)'), '5'); // total is 100.00
    await tester.pump();

    await pressKey(tester, LogicalKeyboardKey.f9);

    expect(checkout.sales, isEmpty);
    expect(find.textContaining('The cash received is less than the total'), findsOneWidget);
  });

  testWidgets('while a dialog is open over the cart the keys do nothing to the sale behind it', (tester) async {
    await pumpCart(tester);
    showDialog<void>(
      context: tester.element(find.byType(CartScreen)),
      builder: (_) => const AlertDialog(content: Text('A question')),
    );
    await tester.pumpAndSettle();

    await pressKey(tester, LogicalKeyboardKey.f9);
    await pressKey(tester, LogicalKeyboardKey.f8);

    expect(checkout.sales, isEmpty);
    expect(methodOf(), 'cash');
  });

  testWidgets('after the cart is closed the keys do nothing at all (no stale screen answers them)', (tester) async {
    await pumpCart(tester);
    expect(CartShortcuts.isActive, isTrue, reason: 'the open cart holds the keys');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(CartShortcuts.isActive, isFalse, reason: 'a closed cart lets go of them');

    CartShortcuts.complete();
    CartShortcuts.switchPayment();

    expect(checkout.sales, isEmpty);
    expect(methodOf(), 'cash');
  });

  testWidgets('the hover hints name the keys', (tester) async {
    await pumpCart(tester);

    final chipTips = tester.widgetList<Tooltip>(find.ancestor(of: find.byType(ChoiceChip), matching: find.byType(Tooltip)));
    expect(chipTips.map((t) => t.message), contains('Switch between Cash and M-Pesa Prompt (F8)'));

    final bottom = tester.widget<Tooltip>(find.ancestor(of: find.widgetWithText(FilledButton, 'Complete Sale'), matching: find.byType(Tooltip)).first);
    expect(bottom.message, 'Complete the sale (F9 or Ctrl+Enter)');

    await pressKey(tester, LogicalKeyboardKey.f8);
    final prompt = tester.widget<Tooltip>(find.ancestor(of: find.widgetWithText(FilledButton, 'Send M-Pesa prompt'), matching: find.byType(Tooltip)).first);
    expect(prompt.message, 'Send the M-Pesa prompt (F9 or Ctrl+Enter)');
  });
}
