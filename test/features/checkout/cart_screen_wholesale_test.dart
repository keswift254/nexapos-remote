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

/// The report: a sale marked "Wholesale" in the cart kept showing the retail
/// prices. What the cashier sees on the cart screen has to change with the chip.
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
  Never noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} was not expected to be called in this test');
}

void main() {
  testWidgets('tapping Wholesale re-prices the lines on the cart screen, Retail puts them back', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(_Session.new),
        appDatabaseProvider.overrideWithValue(db),
        allProductsProvider.overrideWith((ref) async => []),
        productRepositoryProvider.overrideWithValue(const _NoopProductRepository()),
      ],
    );
    addTearDown(container.dispose);
    final cart = container.read(cartProvider.notifier);
    cart.addProduct(const Product(
      id: 'sugar',
      sku: 'SKU-1',
      name: 'Sugar 1kg',
      categoryId: 'cat',
      retailPrice: Money(15000),
      wholesalePrice: Money(12000),
      costPrice: Money(9000),
      stockQty: 50,
      reorderLevel: 0,
      status: 'active',
    ));
    cart.updateQuantity(0, 3);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MaterialApp(home: CartScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.text('KES 150.00 each'), findsOneWidget);

    await tester.tap(find.text('Wholesale'));
    await tester.pumpAndSettle();

    expect(find.text('KES 120.00 each'), findsOneWidget, reason: 'the line must show the wholesale price');
    expect(find.text('KES 150.00 each'), findsNothing);
    expect(container.read(cartProvider).subtotal, const Money(36000));

    await tester.tap(find.text('Retail'));
    await tester.pumpAndSettle();

    expect(find.text('KES 150.00 each'), findsOneWidget);
    expect(container.read(cartProvider).subtotal, const Money(45000));
  });
}
