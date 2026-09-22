import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Product, User;
import 'package:nexapos_mobile/domain/entities/product.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/data/repositories/product_repository_impl.dart';
import 'package:nexapos_mobile/domain/repositories/product_repository.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/features/checkout/cart_notifier.dart';
import 'package:nexapos_mobile/features/checkout/cart_screen.dart';
import 'package:nexapos_mobile/features/products/products_screen.dart';

/// The trash icon on a cart line used to remove it immediately - a single
/// stray tap mid-sale dropped the line with no way back. These pin the
/// confirmation now guarding it.
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
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} was not expected to be called in this test',
  );
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  Future<void> pumpCart(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(_Session.new),
        appDatabaseProvider.overrideWithValue(db),
        allProductsProvider.overrideWith((ref) async => []),
        productRepositoryProvider.overrideWithValue(const _NoopProductRepository()),
      ],
    );
    addTearDown(container.dispose);
    container.read(cartProvider.notifier).addManualItem(
      name: 'Loose sugar',
      quantity: 2,
      price: const Money(5000),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CartScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tapping delete asks for confirmation and does not remove the item yet', (tester) async {
    await pumpCart(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Remove this item?'), findsOneWidget);
    expect(container.read(cartProvider).items, hasLength(1), reason: 'nothing removed until confirmed');
  });

  testWidgets('confirming removes the item', (tester) async {
    await pumpCart(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(container.read(cartProvider).items, isEmpty);
  });

  testWidgets('cancelling keeps the item', (tester) async {
    await pumpCart(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(container.read(cartProvider).items, hasLength(1));
  });
}
