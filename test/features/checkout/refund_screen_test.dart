import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/domain/entities/sale.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/services/refund_service.dart';
import 'package:nexapos_mobile/domain/services/sensitive_action_service.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/features/checkout/refund_screen.dart';

import '../../support/shop_harness.dart';

class _Session extends SessionNotifier {
  static User? who;
  @override
  User? build() => who;
}

/// The refund screen with the real services behind it: choose what comes back, give a reason, confirm with
/// your own password, and land on the refund's receipt.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ShopHarness shop;
  late Sale sale;
  String? openedReceipt;

  Future<void> open(WidgetTester tester, {Sale? target}) async {
    // tall enough for the whole list: a ListView only builds what is on screen
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    openedReceipt = null;
    _Session.who = shop.manager;
    final router = GoRouter(
      initialLocation: '/refund/${(target ?? sale).id}',
      routes: [
        GoRoute(
          path: '/refund/:saleId',
          builder: (context, state) => RefundScreen(saleId: state.pathParameters['saleId']!),
        ),
        GoRoute(
          path: '/receipt/:saleId',
          builder: (context, state) {
            openedReceipt = state.pathParameters['saleId'];
            return const Scaffold(body: Text('RECEIPT PAGE'));
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(shop.db),
          refundServiceProvider.overrideWithValue(shop.refunds),
          sensitiveActionProvider.overrideWithValue(shop.security),
          sessionProvider.overrideWith(_Session.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester) async {
    // the password check hashes for real: give it real time, then let the screen catch up
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pumpAndSettle();
  }

  Future<void> confirmWithPassword(WidgetTester tester, String password) async {
    expect(find.text('Refund a sale'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await settle(tester);
  }

  setUp(() async {
    shop = (await ShopHarness.create());
    sale = await shop.sell([
      shop.line(shop.widgetId, 'Widget', 10000, 6000, 2),
      shop.line(shop.gadgetId, 'Gadget', 25050, 15000, 1),
    ]);
  });
  tearDown(() async => shop.close());

  testWidgets('a whole refund: whole sale, a reason, the password, and the refund receipt opens', (tester) async {
    await tester.runAsync(() async {});
    await open(tester);

    expect(find.text('Sale ${sale.saleNumber}'), findsOneWidget);
    expect(find.text('Widget'), findsOneWidget);
    expect(find.text('Gadget'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('refund-submit'))).onPressed, isNull, reason: 'nothing chosen yet');

    await tester.tap(find.byKey(const Key('refund-whole')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('refund-total')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('refund-total'))).data, 'KES 450.50');
    expect(find.byKey(const Key('refund-pay-back')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('refund-pay-back'))).data, 'Hand KES 450.50 back to the customer in cash.');
    expect(tester.widget<FilledButton>(find.byKey(const Key('refund-submit'))).onPressed, isNull, reason: 'a reason is needed');

    await tester.enterText(find.byKey(const Key('refund-reason')), 'Wrong goods');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('refund-submit'))).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('refund-submit')));
    await tester.pumpAndSettle();
    await confirmWithPassword(tester, 'long-password');

    expect(find.text('RECEIPT PAGE'), findsOneWidget);
    final refunds = await tester.runAsync(() => shop.db.salesDao.refundsOf(sale.id));
    expect(refunds, hasLength(1));
    expect(openedReceipt, refunds!.single.id);
    expect(refunds.single.totalCents, -45050);
    expect(refunds.single.refundReason, 'Wrong goods');
    expect(refunds.single.userId, shop.manager.id);
    expect(await tester.runAsync(() => shop.stockOf(shop.widgetId)), 20);
  });

  testWidgets('some of an item, not put back in stock; the quantity cannot go past what is left', (tester) async {
    await open(tester);
    final widgetLine = (await tester.runAsync(() => shop.saleItems.forSale(sale.id)))!.firstWhere((l) => l.productId == shop.widgetId);
    final plus = find.byKey(Key('refund-plus-${widgetLine.id}'));
    final minus = find.byKey(Key('refund-minus-${widgetLine.id}'));
    expect(tester.widget<IconButton>(minus).onPressed, isNull);

    await tester.tap(plus);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(Key('refund-qty-${widgetLine.id}'))).data, '1');
    await tester.tap(plus);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(Key('refund-qty-${widgetLine.id}'))).data, '2');
    expect(tester.widget<IconButton>(plus).onPressed, isNull, reason: 'only 2 were sold');
    await tester.tap(minus);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(Key('refund-total'))).data, 'KES 100.00');

    await tester.tap(find.byKey(Key('refund-restock-${widgetLine.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('refund-reason')), 'Damaged');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('refund-submit')));
    await tester.pumpAndSettle();
    await confirmWithPassword(tester, 'long-password');

    expect(find.text('RECEIPT PAGE'), findsOneWidget);
    expect(await tester.runAsync(() => shop.stockOf(shop.widgetId)), 18, reason: 'damaged: not put back');
    final source = await tester.runAsync(() => shop.refunds.refundableSale(sale.id));
    expect(source!.refundedTotal.cents, 10000);
    expect(source.hasAnythingLeft, isTrue);
  });

  testWidgets('a wrong password refunds nothing and says so', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('refund-whole')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('refund-reason')), 'x');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('refund-submit')));
    await tester.pumpAndSettle();
    await confirmWithPassword(tester, 'not-my-password');
    expect(find.textContaining('not accepted'), findsOneWidget);
    expect(find.text('RECEIPT PAGE'), findsNothing);
    expect(await tester.runAsync(() => shop.db.salesDao.refundsOf(sale.id)), isEmpty);
  });

  testWidgets('cancelling the password box refunds nothing', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('refund-whole')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('refund-reason')), 'x');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('refund-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('refund-submit')), findsOneWidget);
    expect(await tester.runAsync(() => shop.db.salesDao.refundsOf(sale.id)), isEmpty);
  });

  testWidgets('a sale refunded in full says so and offers nothing to refund', (tester) async {
    await tester.runAsync(() async => shop.mustRefund(sale, await shop.everything(sale.id)));
    await open(tester);
    expect(find.byKey(const Key('refund-blocked')), findsOneWidget);
    expect(find.text('This sale has already been refunded in full.'), findsOneWidget);
    expect(find.byKey(const Key('refund-submit')), findsNothing);
    expect(find.byKey(const Key('refund-already')), findsOneWidget);
  });

  testWidgets('a line that is already refunded is shown as such while the others can still be chosen', (tester) async {
    final gadget = (await tester.runAsync(() => shop.saleItems.forSale(sale.id)))!.firstWhere((l) => l.productId == shop.gadgetId);
    await tester.runAsync(() async => shop.mustRefund(sale, [RefundChoice(itemId: gadget.id, quantity: 1)]));
    await open(tester);
    expect(find.text('Already refunded (1 sold)'), findsOneWidget);
    expect(find.byKey(Key('refund-plus-${gadget.id}')), findsNothing);
    await tester.tap(find.byKey(const Key('refund-whole')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('refund-total'))).data, 'KES 200.00', reason: 'only the two widgets are left');
  });

  testWidgets('an M-Pesa sale says the money is paid back by hand', (tester) async {
    final mpesa = await shop.sell([shop.line(shop.widgetId, 'Widget', 10000, 6000, 1)], method: 'mpesa_manual');
    await open(tester, target: mpesa);
    await tester.tap(find.byKey(const Key('refund-whole')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('refund-pay-back'))).data,
      'Send KES 100.00 back to the customer by M-Pesa yourself. NexaPOS does not send money.',
    );
  });

  testWidgets('a discount is shown as part of the refund figure', (tester) async {
    final discounted = await shop.sell([shop.line(shop.widgetId, 'Widget', 10000, 6000, 2)], discount: 5000);
    await open(tester, target: discounted);
    await tester.tap(find.byKey(const Key('refund-whole')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('refund-total'))).data, 'KES 150.00');
    expect(find.byKey(const Key('refund-discount-note')), findsOneWidget);
  });

  testWidgets('a sale that does not exist', (tester) async {
    await open(tester, target: Sale(
      id: 'nope', saleNumber: 'x', userId: 'x', customerName: 'x', saleType: 'retail', paymentMethod: 'cash',
      subtotal: sale.subtotal, discount: sale.discount, total: sale.total, status: 'paid', createdAt: DateTime(2026),
    ));
    expect(find.byKey(const Key('refund-load-error')), findsOneWidget);
    expect(find.text('Sale not found.'), findsOneWidget);
  });
}
