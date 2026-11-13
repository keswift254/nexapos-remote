import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/domain/entities/cart_item.dart';
import 'package:nexapos_mobile/domain/entities/sale.dart';
import 'package:nexapos_mobile/domain/services/paystack_payment_service.dart';
import 'package:nexapos_mobile/domain/services/pending_sales_notifier.dart';
import 'package:nexapos_mobile/features/checkout/cart_notifier.dart';
import 'package:nexapos_mobile/features/checkout/cart_state.dart';
import 'package:nexapos_mobile/features/checkout/paystack_waiting_screen.dart';

/// The waiting screen for an M-Pesa prompt: nothing is opened, it says the prompt is on the customer's phone, it
/// notices a declined prompt, and "Send the prompt again" puts the sale back in the cart.
class _ScriptedPaystack implements PaystackPaymentService {
  final answers = <Future<PaystackPollOutcome> Function()>[];
  final viaPromptFlags = <bool>[];
  int polls = 0;
  PaystackRetryOutcome retryAnswer = const PaystackRetryNotYet();
  int retries = 0;
  int cancels = 0;

  @override
  Future<PaystackPollOutcome> poll(String saleId, String reference, Money expectedAmount, {bool viaPrompt = false}) {
    viaPromptFlags.add(viaPrompt);
    final index = polls++;
    return index < answers.length ? answers[index]() : Future.value(const PaystackPollWaiting());
  }

  @override
  Future<PaystackRetryOutcome> retryPrompt(Sale sale, String reference) async {
    retries++;
    return retryAnswer;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SpyPendingSales extends PendingPaystackSalesNotifier {
  int reconciles = 0;

  @override
  Future<void> reconcile() async => reconciles++;
}

/// A cart that just remembers what it was given (the real one saves a draft to the database).
class _SpyCart extends CartNotifier {
  CartState? replacedWith;

  @override
  CartState build() => const CartState();

  @override
  Future<void> replaceWith(CartState next) async {
    replacedWith = next;
    state = next;
  }
}

Sale _sale(String status) => Sale(
  id: 'sale-1',
  saleNumber: 'S-0001',
  userId: 'cashier-1',
  customerName: 'Walk-in',
  customerPhone: '0712 345 678',
  saleType: 'retail',
  paymentMethod: 'paystack',
  subtotal: const Money(10000),
  discount: const Money.zero(),
  total: const Money(10000),
  status: status,
  createdAt: DateTime(2026, 11, 13, 12),
);

final _session = PaystackCheckoutSession(
  sale: _sale('pending'),
  authorizationUrl: '',
  reference: 'S-0001',
  viaPrompt: true,
  phone: '0712 345 678',
);

void main() {
  late _ScriptedPaystack paystack;
  late _SpyPendingSales pendingSales;
  late _SpyCart cart;
  late List<Uri> opened;
  late GoRouter router;

  setUp(() {
    paystack = _ScriptedPaystack();
    pendingSales = _SpyPendingSales();
    cart = _SpyCart();
    opened = [];
  });

  /// The cart screen is "behind" the waiting screen, as in the app, so going back has somewhere to land.
  Future<void> open(WidgetTester tester, {bool forWeb = false}) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    router = GoRouter(
      initialLocation: '/cart',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
        GoRoute(path: '/cart', builder: (_, _) => const Scaffold(body: Text('cart screen'))),
        GoRoute(
          path: '/receipt/:id',
          builder: (_, state) => Scaffold(body: Text('receipt ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/wait',
          builder: (_, _) => PaystackWaitingScreen(
            session: _session,
            forWeb: forWeb,
            openCheckoutPage: (uri) async => opened.add(uri),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paystackPaymentServiceProvider.overrideWithValue(paystack),
          pendingPaystackSalesProvider.overrideWith(() => pendingSales),
          cartProvider.overrideWith(() => cart),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.push('/wait');
    await tester.pump();
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
  }

  group('waiting for the customer to approve the prompt', () {
    for (final web in [false, true]) {
      testWidgets('${web ? 'on the web' : 'in the apps'} no page is opened, and none is offered', (tester) async {
        await open(tester, forWeb: web);

        expect(opened, isEmpty, reason: 'the prompt is already on the customer\'s phone');
        expect(find.byKey(const Key('open-checkout-page')), findsNothing);
        expect(find.byKey(const Key('web-payment-hint')), findsNothing);
        expect(find.text('Open payment page'), findsNothing);
        expect(find.text('Open checkout page again'), findsNothing);

        await close(tester);
      });
    }

    testWidgets('it says where the prompt went and what to do', (tester) async {
      await open(tester);

      expect(find.byKey(const Key('prompt-sent')), findsOneWidget);
      expect(find.textContaining('0712 345 678'), findsWidgets);
      expect(find.textContaining('M-Pesa PIN'), findsOneWidget);
      expect(find.byKey(const Key('retry-prompt')), findsNothing, reason: 'not while the customer can still approve');
      expect(find.text('Check now'), findsOneWidget);
      expect(find.text('Cancel sale'), findsOneWidget);

      await close(tester);
    });

    testWidgets('every check asks as an M-Pesa prompt', (tester) async {
      await open(tester);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(paystack.viaPromptFlags, isNotEmpty);
      expect(paystack.viaPromptFlags.every((flag) => flag), isTrue);

      await close(tester);
    });

    testWidgets('approved: straight to the receipt', (tester) async {
      paystack.answers.add(() async => PaystackPollPaid(_sale('paid')));
      await open(tester);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(find.text('receipt sale-1'), findsOneWidget);
      expect(pendingSales.reconciles, 0);

      await close(tester);
    });
  });

  group('the customer did not approve it', () {
    Future<void> endIt(WidgetTester tester) async {
      paystack.answers.add(() async => const PaystackPollEnded());
      await open(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
    }

    testWidgets('the screen says so and offers to send it again; checking stops by itself', (tester) async {
      await endIt(tester);

      expect(find.byKey(const Key('prompt-ended')), findsOneWidget);
      expect(find.byKey(const Key('prompt-sent')), findsNothing);
      expect(find.byKey(const Key('retry-prompt')), findsOneWidget);
      expect(find.text('Send the prompt again'), findsOneWidget);
      expect(find.text('Cancel sale'), findsOneWidget, reason: 'cancelling is still possible');

      final pollsWhenEnded = paystack.polls;
      await tester.pump(const Duration(seconds: 9));
      expect(paystack.polls, pollsWhenEnded, reason: 'no point asking again once it is over');

      await close(tester);
    });

    testWidgets('"Check now" still works, and a prompt that is waiting after all takes the retry button away', (tester) async {
      await endIt(tester);
      paystack.answers.add(() async => const PaystackPollWaiting());

      await tester.tap(find.widgetWithText(FilledButton, 'Check now'));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('retry-prompt')), findsNothing);
      expect(find.byKey(const Key('prompt-sent')), findsOneWidget);

      await close(tester);
    });

    testWidgets('sending it again when the customer had approved it after all: the receipt, nothing cancelled', (tester) async {
      await endIt(tester);
      paystack.retryAnswer = PaystackRetryPaid(_sale('paid'));

      await tester.tap(find.byKey(const Key('retry-prompt')));
      await tester.pump();
      await tester.pump();

      expect(paystack.retries, 1);
      expect(find.text('receipt sale-1'), findsOneWidget);
      expect(cart.replacedWith, isNull, reason: 'the sale stands, so the cart is left alone');

      await close(tester);
    });

    testWidgets('sending it again when the prompt is not over yet: nothing changes but a message, and waiting resumes', (tester) async {
      await endIt(tester);
      paystack.retryAnswer = const PaystackRetryNotYet();

      await tester.tap(find.byKey(const Key('retry-prompt')));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('can still approve'), findsOneWidget);
      expect(find.byKey(const Key('retry-prompt')), findsNothing);
      expect(find.byKey(const Key('prompt-sent')), findsOneWidget);
      expect(cart.replacedWith, isNull);

      final polls = paystack.polls;
      await tester.pump(const Duration(seconds: 3));
      expect(paystack.polls, greaterThan(polls), reason: 'checking starts again');

      await close(tester);
    });

    testWidgets('a problem cancelling is shown, and the sale is left as it was', (tester) async {
      await endIt(tester);
      paystack.retryAnswer = const PaystackRetryFailed('Could not cancel the sale.');

      await tester.tap(find.byKey(const Key('retry-prompt')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Could not cancel the sale.'), findsOneWidget);
      expect(find.byKey(const Key('retry-prompt')), findsOneWidget, reason: 'it can be tried again');
      expect(cart.replacedWith, isNull);

      await close(tester);
    });

    testWidgets('sending it again for real: the items go back in the cart with the number, and the cart screen is back', (tester) async {
      await endIt(tester);
      paystack.retryAnswer = PaystackRetryRestored(
        items: [
          const CartItem(productId: 'p1', name: 'Widget', unitPrice: Money(10000), costPrice: Money(5000), quantity: 1),
        ],
        discount: const Money(1500),
        saleType: 'wholesale',
      );

      await tester.tap(find.byKey(const Key('retry-prompt')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final restored = cart.replacedWith!;
      expect(restored.items.single.name, 'Widget');
      expect(restored.discount, const Money(1500));
      expect(restored.saleType, 'wholesale');
      expect(restored.paymentMethod, 'paystack');
      expect(restored.customerPhone, '0712 345 678', reason: 'the number is kept, ready to be corrected');
      expect(restored.cashReceived, const Money.zero());
      expect(find.text('cart screen'), findsOneWidget, reason: 'back on the cart');
      expect(find.textContaining('items are back in the cart'), findsOneWidget);
      expect(pendingSales.reconciles, 0, reason: 'the sale was cancelled on purpose, nothing left to watch');

      await close(tester);
    });

    testWidgets('a cash-plus-prompt sale goes back as cash, so the "prompt for the rest" button is there again', (tester) async {
      await endIt(tester);
      paystack.retryAnswer = PaystackRetryRestored(
        items: [
          const CartItem(productId: 'p1', name: 'Widget', unitPrice: Money(10000), costPrice: Money(5000), quantity: 1),
        ],
        discount: const Money.zero(),
        saleType: 'retail',
        cashReceived: const Money(4000),
      );

      await tester.tap(find.byKey(const Key('retry-prompt')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final restored = cart.replacedWith!;
      expect(restored.paymentMethod, 'cash');
      expect(restored.cashReceived, const Money(4000));
      expect(restored.customerPhone, '0712 345 678');

      await close(tester);
    });
  });
}
