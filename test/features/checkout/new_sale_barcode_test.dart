import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Product, User;
import 'package:nexapos_mobile/data/repositories/product_repository_impl.dart';
import 'package:nexapos_mobile/domain/entities/product.dart';
import 'package:nexapos_mobile/domain/repositories/product_repository.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/features/checkout/cart_notifier.dart';
import 'package:nexapos_mobile/features/checkout/new_sale_screen.dart';
import 'package:nexapos_mobile/features/products/products_screen.dart';

class _Session extends SessionNotifier {
  @override
  User? build() => null;
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

/// A minimal stand-in - only findByBarcode is ever called by the screen
/// under test, everything else throws if the test starts relying on it
/// so that stays an intentional, visible decision rather than a silent
/// gap.
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
    // CartNotifier persists every change (see cart_notifier.dart) - an
    // in-memory database keeps the barcode-scan-adds-to-cart flow below
    // from ever touching the real default database mid-test.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith(_Session.new),
      appDatabaseProvider.overrideWithValue(db),
      allProductsProvider.overrideWith((ref) async => [_soda]),
      productRepositoryProvider.overrideWithValue(
        const _FakeProductRepository({'6009123456789': _soda}),
      ),
    ]);
    return container;
  }

  testWidgets('scanning a recognized barcode adds that product to the cart and clears the field', (tester) async {
    final container = buildContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: NewSaleScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '6009123456789');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(container.read(cartProvider).items, hasLength(1));
    expect(container.read(cartProvider).items.single.name, 'Soda 500ml');
    expect(find.text('Added "Soda 500ml" from barcode scan.'), findsOneWidget);
    expect(find.widgetWithText(TextField, ''), findsWidgets);
    expect(tester.widget<TextField>(find.byType(TextField).first).controller?.text, isEmpty);
  });

  testWidgets('a value that matches no barcode is left as an ordinary search filter, nothing added to cart', (tester) async {
    final container = buildContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: NewSaleScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'not-a-real-barcode');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(container.read(cartProvider).items, isEmpty);
    // The typed text is preserved as a search query, not cleared.
    expect(find.text('not-a-real-barcode'), findsOneWidget);
  });
}
