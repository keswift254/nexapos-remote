import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/domain/entities/product.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/features/products/products_screen.dart';

class _Session extends SessionNotifier {
  @override
  User? build() => null;
}

void main() {
  testWidgets('next page stays tappable above Add Product on small Android screens', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.padding = const FakeViewPadding(bottom: 32);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionProvider.overrideWith(_Session.new),
      productFormCategoriesProvider.overrideWith((ref) async => []),
      allProductsProvider.overrideWith((ref) async => List.generate(11, (i) => Product(
        id: '$i', sku: '$i', name: 'Product $i', categoryId: '',
        retailPrice: const Money(100), wholesalePrice: const Money(100), costPrice: const Money(50),
        stockQty: 5, reorderLevel: 1, status: 'active'))),
    ], child: const MaterialApp(home: ProductsScreen())));
    await tester.pumpAndSettle();
    final next = find.byTooltip('Next page');
    final add = find.widgetWithText(FilledButton, 'Add Product');
    expect(tester.getRect(next).overlaps(tester.getRect(add)), isFalse);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Page 2 of 2'), findsOneWidget);
    expect(find.text('Product 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
