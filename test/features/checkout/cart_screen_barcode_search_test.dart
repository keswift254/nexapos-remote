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

/// A minimal stand-in, same shape as new_sale_barcode_test.dart's -
/// only findByBarcode is ever expected to be called from CartScreen's
/// own search shortcut.
class _FakeProductRepository implements ProductRepository {
  final Map<String, Product> byBarcode;
  const _FakeProductRepository(this.byBarcode);

  @override
  Future<Product?> findByBarcode(String barcode) async => byBarcode[barcode];

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError(
        '${invocation.memberName} was not expected to be called in this test',
      );
}

void main() {
  ProviderContainer buildContainer() {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith(_Session.new),
      appDatabaseProvider.overrideWithValue(db),
      productRepositoryProvider.overrideWithValue(
        const _FakeProductRepository({'6009123456789': _soda}),
      ),
    ]);
    return container;
  }

  testWidgets('scanning a recognized barcode from the cart screen adds it and clears the field', (tester) async {
    final container = buildContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CartScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '6009123456789');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(container.read(cartProvider).items, hasLength(1));
    expect(find.text('Added "Soda 500ml" from barcode scan.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).first).controller?.text, isEmpty);
  });

  // The cart screen (unlike NewSaleScreen) has no product grid to fall
  // back to filtering, so a non-matching scan needs its own explicit
  // message - silently doing nothing here is indistinguishable from the
  // search box simply not working at all, which is exactly what got
  // reported for real.
  testWidgets('scanning an unrecognized barcode from the cart screen shows a clear "not found" message', (tester) async {
    final container = buildContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CartScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '000000000000');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(container.read(cartProvider).items, isEmpty);
    expect(find.text('No product found for barcode "000000000000".'), findsOneWidget);
  });
}
