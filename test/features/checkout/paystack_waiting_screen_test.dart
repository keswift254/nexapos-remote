import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:nexapos_mobile/core/checkout_return_bridge.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/domain/entities/sale.dart';
import 'package:nexapos_mobile/domain/services/paystack_payment_service.dart';
import 'package:nexapos_mobile/domain/services/pending_sales_notifier.dart';
import 'package:nexapos_mobile/features/checkout/paystack_waiting_screen.dart';

/// Answers each status check from a script, so a test decides when (and
/// whether) the server "replies".
class _ScriptedPaystack implements PaystackPaymentService {
  final answers = <Future<PaystackPollOutcome> Function()>[];
  int polls = 0;

  @override
  Future<PaystackPollOutcome> poll(
    String saleId,
    String reference,
    Money expectedAmount, {
    bool viaPrompt = false,
  }) {
    final index = polls++;
    return index < answers.length
        ? answers[index]()
        : Future.value(const PaystackPollWaiting());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SpyPendingSales extends PendingPaystackSalesNotifier {
  int reconciles = 0;

  @override
  Future<void> reconcile() async => reconciles++;
}

Sale _sale(String status) => Sale(
  id: 'sale-1',
  saleNumber: 'S-0001',
  userId: 'cashier-1',
  customerName: 'Walk-in',
  saleType: 'retail',
  paymentMethod: 'paystack',
  subtotal: const Money(10000),
  discount: const Money.zero(),
  total: const Money(10000),
  status: status,
  createdAt: DateTime(2026, 11, 3, 12),
);

final _session = PaystackCheckoutSession(
  sale: _sale('pending'),
  authorizationUrl: 'https://checkout.paystack.test/pay/abc',
  reference: 'S-0001',
);

void main() {
  late _ScriptedPaystack paystack;
  late _SpyPendingSales pendingSales;
  late List<Uri> opened;
  late GoRouter router;

  setUp(() {
    paystack = _ScriptedPaystack();
    pendingSales = _SpyPendingSales();
    opened = [];
    CheckoutReturnBridge.signal.value = 0;
  });

  Future<void> open(WidgetTester tester, {required bool forWeb}) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    router = GoRouter(
      initialLocation: '/wait',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/receipt/:id',
          builder: (_, state) =>
              Scaffold(body: Text('receipt ${state.pathParameters['id']}')),
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
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
  }

  group('opening the payment page', () {
    testWidgets('on the web it opens by itself, once, and the button opens it again', (tester) async {
      await open(tester, forWeb: true);

      expect(opened, [Uri.parse('https://checkout.paystack.test/pay/abc')]);
      expect(find.byKey(const Key('web-payment-hint')), findsOneWidget);
      expect(find.text('Open payment page'), findsOneWidget);

      await tester.tap(find.byKey(const Key('open-checkout-page')));
      await tester.pump();
      expect(opened, hasLength(2));

      await close(tester);
    });

    testWidgets('on the apps nothing about the web page is shown', (tester) async {
      await open(tester, forWeb: false);

      expect(find.byKey(const Key('web-payment-hint')), findsNothing);
      expect(find.text('Open checkout page again'), findsOneWidget);

      await close(tester);
    });
  });

  group('asking whether the customer has paid', () {
    testWidgets('a return cue checks at once, even while an earlier check is stuck', (tester) async {
      final stuck = Completer<PaystackPollOutcome>();
      paystack.answers
        ..add(() => stuck.future) // sent just before the page went to the background
        ..add(() async => PaystackPollPaid(_sale('paid')));
      await open(tester, forWeb: true);

      await tester.pump(const Duration(seconds: 3));
      expect(paystack.polls, 1);
      await tester.pump(const Duration(seconds: 3));
      expect(
        paystack.polls,
        1,
        reason: 'an ordinary tick does not pile on top of a check in flight',
      );

      CheckoutReturnBridge.signal.value++; // the customer is back
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(paystack.polls, 2, reason: 'the cue must not wait for the stuck check');
      expect(find.text('receipt sale-1'), findsOneWidget);

      // The stuck check finally answers; it has been superseded and changes nothing.
      stuck.complete(const PaystackPollWaiting());
      await tester.pump();
      expect(find.text('receipt sale-1'), findsOneWidget);
      expect(paystack.polls, 2);

      await close(tester);
    });

    testWidgets('a stuck check that answers late does not disturb the check that replaced it', (tester) async {
      final stuck = Completer<PaystackPollOutcome>();
      final replacement = Completer<PaystackPollOutcome>();
      paystack.answers
        ..add(() => stuck.future)
        ..add(() => replacement.future);
      await open(tester, forWeb: true);

      await tester.pump(const Duration(seconds: 3)); // check 1, which gets stuck
      CheckoutReturnBridge.signal.value++;
      await tester.pump(const Duration(milliseconds: 200)); // check 2 replaces it
      expect(paystack.polls, 2);
      bool checkNowEnabled() => tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Check now'))
          .enabled;
      expect(checkNowEnabled(), isFalse, reason: 'check 2 is running');

      stuck.complete(const PaystackPollWaiting()); // check 1 finally answers
      await tester.pump();
      expect(
        checkNowEnabled(),
        isFalse,
        reason: 'the old answer must not make it look as if nothing is running',
      );

      replacement.complete(const PaystackPollWaiting());
      await tester.pump();
      expect(checkNowEnabled(), isTrue);

      await close(tester);
    });
    testWidgets('a burst of cues is one check', (tester) async {
      await open(tester, forWeb: true);

      CheckoutReturnBridge.signal.value++;
      CheckoutReturnBridge.signal.value++;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      CheckoutReturnBridge.signal.value++;
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(paystack.polls, 1);

      await close(tester);
    });

    testWidgets('while nothing has been confirmed it keeps asking on its own', (tester) async {
      await open(tester, forWeb: true);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(paystack.polls, 3);
      expect(find.text('home'), findsNothing);

      await close(tester);
    });
  });

  group('when the screen goes away', () {
    testWidgets('unpaid, the sale is handed to the pending-payment watcher', (tester) async {
      await open(tester, forWeb: true);
      expect(pendingSales.reconciles, 0);

      router.go('/'); // e.g. the app locked itself while the customer paid
      await tester.pump();
      await tester.pump();

      expect(pendingSales.reconciles, 1);
      expect(find.text('home'), findsOneWidget);

      await close(tester);
    });

    testWidgets('once paid there is nothing left to hand over', (tester) async {
      paystack.answers.add(() async => PaystackPollPaid(_sale('paid')));
      await open(tester, forWeb: true);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(find.text('receipt sale-1'), findsOneWidget);
      expect(pendingSales.reconciles, 0);

      await close(tester);
    });
  });
}
