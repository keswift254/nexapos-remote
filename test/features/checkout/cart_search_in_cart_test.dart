import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/providers.dart';
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
import 'package:nexapos_mobile/features/products/products_screen.dart';

/// The cart's search: it stays at the top while a long cart scrolls under it; each result says whether the product is
/// already in the cart or only in the inventory; and picking one that is in the cart takes the cashier to its line instead
/// of adding it a second time.
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

Product product(int n, {int stock = 20}) => Product(
      id: 'p$n',
      sku: 'SKU-$n',
      name: 'Item ${n.toString().padLeft(2, '0')}',
      categoryId: 'c1',
      retailPrice: Money(1000 + n),
      wholesalePrice: Money(1000 + n),
      costPrice: const Money(500),
      stockQty: stock,
      reorderLevel: 2,
      status: 'active',
    );

void main() {
  late ProviderContainer container;
  final products = [for (var n = 1; n <= 30; n++) product(n), product(31, stock: 0)];

  Future<void> pumpCart(WidgetTester tester, {required Size size, int inCart = 0}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    container = ProviderContainer(overrides: [
      sessionProvider.overrideWith(_Session.new),
      appDatabaseProvider.overrideWithValue(db),
      allProductsProvider.overrideWith((ref) async => products),
      productRepositoryProvider.overrideWithValue(const _NoopProductRepository()),
    ]);
    addTearDown(container.dispose);
    for (var n = 0; n < inCart; n++) {
      container.read(cartProvider.notifier).addProduct(products[n]);
    }
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const MaterialApp(home: CartScreen())));
    await tester.pumpAndSettle();
  }

  Finder search() => find.byKey(const Key('cart-search'));
  int quantityOf(String productId) =>
      container.read(cartProvider).items.where((i) => i.productId == productId).fold(0, (sum, i) => sum + i.quantity);

  testWidgets('a result not in the cart says it is in the inventory, with its stock; a tap adds it', (tester) async {
    await pumpCart(tester, size: const Size(1200, 1600));
    await tester.enterText(search(), 'item 05');
    await tester.pump();

    final label = find.byKey(const Key('cart-search-in-inventory-p5'));
    expect(label, findsOneWidget);
    expect(find.descendant(of: label, matching: find.text('In inventory · 20 in stock')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cart-search-result-p5')));
    await tester.pumpAndSettle();
    expect(quantityOf('p5'), 1);
  });

  testWidgets('a product with no stock left says so', (tester) async {
    await pumpCart(tester, size: const Size(1200, 1600));
    await tester.enterText(search(), 'item 31');
    await tester.pump();
    expect(find.text('In inventory · none in stock'), findsOneWidget);
  });

  testWidgets('a result already in the cart says so, with how many', (tester) async {
    await pumpCart(tester, size: const Size(1200, 1600), inCart: 3);
    container.read(cartProvider.notifier).addProduct(products[1]);
    await tester.pump();
    await tester.enterText(search(), 'item 02');
    await tester.pump();

    final label = find.byKey(const Key('cart-search-in-cart-p2'));
    expect(label, findsOneWidget);
    expect(find.descendant(of: label, matching: find.text('In cart × 2')), findsOneWidget);
    expect(find.byKey(const Key('cart-search-in-inventory-p2')), findsNothing);
  });

  testWidgets('picking one that is in the cart takes the cashier to its line - it is not added a second time',
      (tester) async {
    // a phone: thirty items, so the first one is far out of sight once the cart is scrolled to the end
    await pumpCart(tester, size: const Size(400, 800), inCart: 30);
    await tester.drag(find.byType(ListView).last, const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cart-line-plus-p1')).hitTestable(), findsNothing, reason: 'Item 01 is out of sight');

    await tester.enterText(search(), 'item 01');
    await tester.pump();
    await tester.tap(find.byKey(const Key('cart-search-result-p1')));
    await tester.pumpAndSettle();

    expect(quantityOf('p1'), 1, reason: 'not added again');
    expect(container.read(cartProvider).items, hasLength(30));
    expect(find.byKey(const Key('cart-line-plus-p1')).hitTestable(), findsOneWidget, reason: 'its line is in sight');
    final plus = tester.widget<IconButton>(find.byKey(const Key('cart-line-plus-p1')));
    expect(plus.focusNode!.hasFocus, isTrue, reason: 'the cursor is on its +: Enter adds one more');
    final line = tester.widget<Card>(find.ancestor(of: find.byKey(const Key('cart-line-plus-p1')), matching: find.byType(Card)));
    expect(line.color, Theme.of(tester.element(search())).colorScheme.primaryContainer, reason: 'its line is marked');
    expect(tester.widget<TextField>(search()).controller!.text, isEmpty, reason: 'the search is cleared');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(quantityOf('p1'), 2, reason: 'Enter on its + adds one more');

    await tester.pump(const Duration(seconds: 4));
    final later = tester.widget<Card>(find.ancestor(of: find.byKey(const Key('cart-line-plus-p1')), matching: find.byType(Card)));
    expect(later.color, isNull, reason: 'the mark goes after a moment');
  });

  testWidgets('the search stays at the top, in sight, however far down a long cart is scrolled', (tester) async {
    await pumpCart(tester, size: const Size(400, 800), inCart: 30);
    final top = tester.getRect(search());

    await tester.drag(find.byType(ListView).last, const Offset(0, -6000));
    await tester.pumpAndSettle();

    expect(search().hitTestable(), findsOneWidget);
    expect(tester.getRect(search()), top, reason: 'it did not move with the cart');
    await tester.enterText(search(), 'item 29');
    await tester.pump();
    expect(find.byKey(const Key('cart-search-result-p29')).hitTestable(), findsOneWidget,
        reason: 'what it finds shows right under it, also in sight');
  });
}
