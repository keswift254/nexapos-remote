import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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

const _soda = Product(
  id: 'p1',
  sku: 'SKU-1',
  name: 'Soda 500ml',
  categoryId: 'c1',
  barcode: '6009123456789',
  retailPrice: Money(15000),
  wholesalePrice: Money(12000),
  costPrice: Money(8000),
  stockQty: 20,
  reorderLevel: 2,
  status: 'active',
);

const _bread = Product(
  id: 'p2',
  sku: 'SKU-2',
  name: 'Brown Bread',
  categoryId: 'c1',
  retailPrice: Money(6000),
  wholesalePrice: Money(5000),
  costPrice: Money(4000),
  stockQty: 10,
  reorderLevel: 2,
  status: 'active',
);

class _NoopProductRepository implements ProductRepository {
  const _NoopProductRepository();
  @override
  Future<Product?> findByBarcode(String barcode) async => null;
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError(
        '${invocation.memberName} was not expected to be called in this test',
      );
}

void main() {
  testWidgets('typing a product name in the cart search shows matches, tapping one adds it', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith(_Session.new),
      appDatabaseProvider.overrideWithValue(db),
      allProductsProvider.overrideWith((ref) async => [_soda, _bread]),
      productRepositoryProvider.overrideWithValue(const _NoopProductRepository()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CartScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Soda 500ml'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'sod');
    await tester.pump();

    expect(find.text('Soda 500ml'), findsOneWidget);
    expect(find.text('Brown Bread'), findsNothing);
    expect(find.text('No products found.'), findsNothing);

    await tester.tap(find.text('Soda 500ml'));
    await tester.pumpAndSettle();

    expect(container.read(cartProvider).items, hasLength(1));
    expect(container.read(cartProvider).items.single.name, 'Soda 500ml');
    // The search box clears once an item is added from the results.
    expect(tester.widget<TextField>(find.byType(TextField).first).controller?.text, isEmpty);
  });

  testWidgets('a name that matches nothing shows "No products found."', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith(_Session.new),
      appDatabaseProvider.overrideWithValue(db),
      allProductsProvider.overrideWith((ref) async => [_soda, _bread]),
      productRepositoryProvider.overrideWithValue(const _NoopProductRepository()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CartScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'xyz-nope');
    await tester.pump();

    expect(find.text('No products found.'), findsOneWidget);
    expect(container.read(cartProvider).items, isEmpty);
  });
}
