import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Product, User;
import 'package:nexapos_mobile/data/repositories/product_repository_impl.dart';
import 'package:nexapos_mobile/domain/entities/product.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/repositories/product_repository.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/features/checkout/cart_notifier.dart';
import 'package:nexapos_mobile/features/checkout/cart_screen.dart';
import 'package:nexapos_mobile/features/checkout/held_sales_notifier.dart';
import 'package:nexapos_mobile/features/products/products_screen.dart';

/// Holding a sale: set the cart aside to serve someone else, and come back to it (or throw
/// it away) later - without ever losing either sale.
class _Session extends SessionNotifier {
  @override
  User? build() => const User(
    id: 'cashier-1',
    role: UserRole.cashier,
    name: 'Wanjiru',
    username: 'wanjiru',
    passwordHash: 'irrelevant-for-this-test',
    status: 'active',
  );
}

class _NoopProductRepository implements ProductRepository {
  const _NoopProductRepository();
  @override
  Future<Product?> findByBarcode(String barcode) async => null;
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} was not expected to be called in this test',
  );
}

class _FixedClock implements Clock {
  DateTime current;
  _FixedClock(this.current);
  @override
  DateTime now() => current;
}

void main() {
  late AppDatabase db;
  late _FixedClock clock;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = _FixedClock(DateTime.utc(2026, 11, 8, 10, 0));
  });
  tearDown(() => db.close());

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        sessionProvider.overrideWith(_Session.new),
        allProductsProvider.overrideWith((ref) async => []),
        productRepositoryProvider.overrideWithValue(const _NoopProductRepository()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  void fill(ProviderContainer container, {String name = 'Sugar 1kg', int quantity = 2, int price = 150}) {
    container.read(cartProvider.notifier).addManualItem(name: name, quantity: quantity, price: Money.fromMajor(price));
  }

  group('the held-sales store', () {
    test('holding saves the cart as it is and empties it for the next customer', () async {
      final container = buildContainer();
      fill(container);
      container.read(cartProvider.notifier).setDiscount(Money.fromMajor(20));
      container.read(cartProvider.notifier).setSaleType('wholesale');

      final held = await container.read(heldSalesProvider.notifier).holdCurrent(label: 'Mama Njeri', heldBy: 'Wanjiru');

      expect(held, isNotNull);
      expect(container.read(cartProvider).isEmpty, isTrue, reason: 'the cart is free for the next customer');
      final list = container.read(heldSalesProvider);
      expect(list, hasLength(1));
      expect(list.single.label, 'Mama Njeri');
      expect(list.single.heldBy, 'Wanjiru');
      expect(list.single.cart.items.single.name, 'Sugar 1kg');
      expect(list.single.cart.items.single.quantity, 2);
      expect(list.single.cart.discount, Money.fromMajor(20));
      expect(list.single.cart.saleType, 'wholesale');
      expect(list.single.total, Money.fromMajor(280));
    });

    test('an empty cart cannot be held', () async {
      final container = buildContainer();
      expect(await container.read(heldSalesProvider.notifier).holdCurrent(heldBy: 'Wanjiru'), isNull);
      expect(container.read(heldSalesProvider), isEmpty);
    });

    test('with no name given, the customer name is used, else Held sale 1, 2, 3...', () async {
      final container = buildContainer();
      final notifier = container.read(heldSalesProvider.notifier);
      fill(container);
      await notifier.holdCurrent(heldBy: 'W');
      fill(container);
      await notifier.holdCurrent(label: '   ', heldBy: 'W');
      fill(container);
      await notifier.holdCurrent(heldBy: 'W');
      final labels = container.read(heldSalesProvider).map((h) => h.label).toList();
      expect(labels, ['Held sale 3', 'Held sale 2', 'Held sale 1'], reason: 'newest first, numbers never repeat');
    });

    test('the held sales survive an app restart, with everything the cashier had typed', () async {
      final first = buildContainer();
      fill(first);
      first.read(cartProvider.notifier).setDiscount(Money.fromMajor(10));
      first.read(cartProvider.notifier).setPaymentMethod('paystack');
      await first.read(heldSalesProvider.notifier).holdCurrent(label: 'Mama Njeri', heldBy: 'Wanjiru');
      await pumpEventQueue();

      final second = buildContainer();
      await second.read(heldSalesProvider.notifier).restore();
      final list = second.read(heldSalesProvider);
      expect(list, hasLength(1));
      expect(list.single.label, 'Mama Njeri');
      expect(list.single.heldAt, DateTime.utc(2026, 11, 8, 10, 0));
      expect(list.single.heldBy, 'Wanjiru', reason: 'who set it aside survives a restart');
      expect(list.single.cart.items.single.quantity, 2);
      expect(list.single.cart.discount, Money.fromMajor(10));
      expect(list.single.cart.paymentMethod, 'paystack');
    });

    test('opening a held sale puts it back in the cart and removes it from the list, for good', () async {
      final first = buildContainer();
      fill(first);
      first.read(cartProvider.notifier).setDiscount(Money.fromMajor(10));
      final held = (await first.read(heldSalesProvider.notifier).holdCurrent(label: 'A', heldBy: 'W'))!;

      expect(await first.read(heldSalesProvider.notifier).resume(held.id), isTrue);
      expect(first.read(heldSalesProvider), isEmpty);
      expect(first.read(cartProvider).items.single.name, 'Sugar 1kg');
      expect(first.read(cartProvider).discount, Money.fromMajor(10));
      await pumpEventQueue();

      final second = buildContainer();
      await second.read(heldSalesProvider.notifier).restore();
      await second.read(cartProvider.notifier).restore();
      expect(second.read(heldSalesProvider), isEmpty, reason: 'it is not held a second time after a restart');
      expect(second.read(cartProvider).items, hasLength(1), reason: 'and the cart draft kept it');
    });

    test('opening one while the cart has something is refused unless the current sale is held too', () async {
      final container = buildContainer();
      final notifier = container.read(heldSalesProvider.notifier);
      fill(container, name: 'Held item');
      final held = (await notifier.holdCurrent(label: 'First', heldBy: 'W'))!;
      fill(container, name: 'Current item');

      expect(await notifier.resume(held.id), isFalse, reason: 'refused: nothing may be thrown away');
      expect(container.read(cartProvider).items.single.name, 'Current item');
      expect(container.read(heldSalesProvider), hasLength(1));

      expect(await notifier.resume(held.id, holdCurrentFirst: true), isTrue);
      expect(container.read(cartProvider).items.single.name, 'Held item');
      final list = container.read(heldSalesProvider);
      expect(list, hasLength(1), reason: 'the one that was being worked on is now the held one');
      expect(list.single.cart.items.single.name, 'Current item');
    });

    test('an unknown id opens nothing', () async {
      final container = buildContainer();
      expect(await container.read(heldSalesProvider.notifier).resume('nope'), isFalse);
    });

    test('throwing one away removes only that one, for good', () async {
      final first = buildContainer();
      final notifier = first.read(heldSalesProvider.notifier);
      fill(first, name: 'One');
      final one = (await notifier.holdCurrent(label: 'One', heldBy: 'W'))!;
      fill(first, name: 'Two');
      await notifier.holdCurrent(label: 'Two', heldBy: 'W');

      await notifier.discard(one.id);
      expect(first.read(heldSalesProvider).map((h) => h.label), ['Two']);
      await pumpEventQueue();

      final second = buildContainer();
      await second.read(heldSalesProvider.notifier).restore();
      expect(second.read(heldSalesProvider).map((h) => h.label), ['Two']);
    });

    test('a shop change throws every held sale away (they name the old shop\'s products)', () async {
      final first = buildContainer();
      fill(first);
      await first.read(heldSalesProvider.notifier).holdCurrent(label: 'x', heldBy: 'W');
      await first.read(heldSalesProvider.notifier).clearAll();
      expect(first.read(heldSalesProvider), isEmpty);

      final second = buildContainer();
      await second.read(heldSalesProvider.notifier).restore();
      expect(second.read(heldSalesProvider), isEmpty);
    });

    test('a corrupt or incompatible saved list is ignored, not a crash', () async {
      await db.customStatement("INSERT OR REPLACE INTO local_safety_state(id,value) VALUES('held_sales','{not json')");
      final container = buildContainer();
      await container.read(heldSalesProvider.notifier).restore();
      expect(container.read(heldSalesProvider), isEmpty);
    });

    test('a discount larger than the items still gives a total of zero, never negative', () async {
      final container = buildContainer();
      fill(container, quantity: 1, price: 50);
      container.read(cartProvider.notifier).setDiscount(Money.fromMajor(500));
      final held = (await container.read(heldSalesProvider.notifier).holdCurrent(heldBy: 'W'))!;
      expect(held.total, const Money.zero());
    });

    test('the held copy is saved before the cart is emptied', () async {
      final container = buildContainer();
      fill(container);
      await container.read(heldSalesProvider.notifier).holdCurrent(label: 'x', heldBy: 'W');
      final row = await db.customSelect("SELECT value FROM local_safety_state WHERE id='held_sales'").getSingleOrNull();
      expect(row, isNotNull);
      expect(row!.data['value'] as String, contains('Sugar 1kg'));
    });
  });

  group('on the cart screen', () {
    Future<ProviderContainer> pumpCart(WidgetTester tester, {bool withItem = true}) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = buildContainer();
      if (withItem) fill(container, name: 'Loose sugar');
      final router = GoRouter(
        initialLocation: '/checkout/cart',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Dashboard home'))),
          GoRoute(path: '/checkout/cart', builder: (_, _) => const CartScreen()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('Hold is not offered for an empty cart', (tester) async {
      await pumpCart(tester, withItem: false);
      final hold = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Hold'));
      expect(hold.onPressed, isNull);
    });

    testWidgets('Hold asks for an optional name, sets the sale aside and goes back for the next customer', (tester) async {
      final container = await pumpCart(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Hold'));
      await tester.pumpAndSettle();
      expect(find.text('Hold this sale'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Name or note (optional)'), 'Mama Njeri');
      await tester.tap(find.text('Hold sale'));
      await tester.pumpAndSettle();

      expect(container.read(cartProvider).isEmpty, isTrue);
      expect(container.read(heldSalesProvider).single.label, 'Mama Njeri');
      expect(container.read(heldSalesProvider).single.heldBy, 'Wanjiru');
      expect(find.text('Dashboard home'), findsOneWidget, reason: 'back out of the cart, ready for the next customer');
    });

    testWidgets('cancelling the hold dialog changes nothing', (tester) async {
      final container = await pumpCart(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Hold'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(cartProvider).items, hasLength(1));
      expect(container.read(heldSalesProvider), isEmpty);
    });

    testWidgets('the Held sales button counts them and opens the list; Open brings one back and Discard throws it away', (tester) async {
      final container = await pumpCart(tester, withItem: false);
      // Two sales already held.
      fill(container, name: 'Bread', quantity: 1, price: 60);
      await container.read(heldSalesProvider.notifier).holdCurrent(label: 'First', heldBy: 'Wanjiru');
      fill(container, name: 'Milk', quantity: 3, price: 50);
      container.read(cartProvider.notifier).setDiscount(Money.fromMajor(10));
      await container.read(heldSalesProvider.notifier).holdCurrent(label: 'Second', heldBy: 'Wanjiru');
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget, reason: 'the badge counts held sales');
      expect(find.text('2 held sales are waiting'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.pause_circle_outline).first);
      await tester.pumpAndSettle();
      expect(find.text('Held sales'), findsWidgets);
      expect(find.text('Second'), findsOneWidget);
      expect(find.textContaining('3 items'), findsOneWidget);
      expect(find.textContaining('just now'), findsWidgets);

      // Throw the first one away (asks first).
      final firstTile = find.byKey(ValueKey('held-${container.read(heldSalesProvider).last.id}'));
      await tester.tap(find.descendant(of: firstTile, matching: find.byIcon(Icons.delete_outline)));
      await tester.pumpAndSettle();
      expect(find.text('Throw away this held sale?'), findsOneWidget, reason: 'it asks first');
      expect(container.read(heldSalesProvider), hasLength(2), reason: 'nothing is removed until confirmed');
      await tester.tap(find.widgetWithText(FilledButton, 'Throw away'));
      await tester.pumpAndSettle();
      expect(container.read(heldSalesProvider).map((h) => h.label), ['Second']);

      // Open the other: it lands in the cart, and the discount field shows its discount.
      await tester.tap(find.widgetWithText(FilledButton, 'Open'));
      await tester.pumpAndSettle();
      expect(container.read(heldSalesProvider), isEmpty);
      expect(container.read(cartProvider).items.single.name, 'Milk');
      expect(find.text('Milk'), findsOneWidget);
      final discountField = tester.widget<TextField>(find.widgetWithText(TextField, 'Discount'));
      expect(discountField.controller!.text, '10.00', reason: 'the screen\'s fields follow the opened sale');
    });

    testWidgets('opening a held sale while the cart has items offers to hold the current one first', (tester) async {
      final container = await pumpCart(tester);
      // 'Loose sugar' is in the cart; hold another one first.
      container.read(cartProvider.notifier).clear();
      fill(container, name: 'Bread', quantity: 1, price: 60);
      await container.read(heldSalesProvider.notifier).holdCurrent(label: 'Waiting', heldBy: 'Wanjiru');
      fill(container, name: 'Loose sugar');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.pause_circle_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Open'));
      await tester.pumpAndSettle();
      expect(find.text('Open this held sale?'), findsOneWidget);

      // Cancelling leaves everything as it was.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(cartProvider).items.single.name, 'Loose sugar');
      expect(container.read(heldSalesProvider).single.label, 'Waiting');

      await tester.tap(find.widgetWithText(FilledButton, 'Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Hold it and open'));
      await tester.pumpAndSettle();
      expect(container.read(cartProvider).items.single.name, 'Bread');
      expect(container.read(heldSalesProvider).single.cart.items.single.name, 'Loose sugar', reason: 'the interrupted sale is held, not lost');
    });
  });
}
