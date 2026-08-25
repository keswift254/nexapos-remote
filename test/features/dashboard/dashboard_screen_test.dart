import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Category, Product, User;
import 'package:nexapos_mobile/data/repositories/category_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/product_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/user_repository_impl.dart';
import 'package:nexapos_mobile/domain/entities/cart_item.dart';
import 'package:nexapos_mobile/domain/entities/category.dart';
import 'package:nexapos_mobile/domain/entities/product.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/checkout_service.dart';
import 'package:nexapos_mobile/domain/services/stock_service.dart';
import 'package:nexapos_mobile/features/dashboard/dashboard_screen.dart';

void main() {
  test(
    'a sale completed through the real checkout provider graph is reflected in dashboardData automatically, '
    'via dashboardChangeTicker, with no manual invalidate call anywhere in this test',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWith((ref) => db)]);
      addTearDown(container.dispose);

      final categoryRepo = container.read(categoryRepositoryProvider);
      final productRepo = container.read(productRepositoryProvider);
      final userRepo = container.read(userRepositoryProvider);

      final category = Category(id: 'cat-1', name: 'General', status: 'active');
      await categoryRepo.create(category);
      final productId = await productRepo.create(Product(
        id: '',
        sku: 'SKU-1',
        name: 'Widget',
        categoryId: category.id,
        retailPrice: const Money(10000),
        wholesalePrice: const Money(8000),
        costPrice: const Money(5000),
        stockQty: 10,
        reorderLevel: 2,
        status: 'active',
      ));
      // ProductRepository.create() always starts stock_qty at 0
      // regardless of the entity field - a real movement is required.
      await container.read(stockServiceProvider).applyMovement(
            productId: productId,
            movementType: 'purchase',
            delta: 10,
          );
      final user = User(
        id: 'user-1',
        role: UserRole.cashier,
        name: 'Cashier',
        username: 'cashier',
        passwordHash: 'irrelevant',
        status: 'active',
      );
      await userRepo.create(user);

      // Baseline read before any sale exists.
      final before = await container.read(dashboardDataProvider.future);
      expect(before.today.salesCount, 0);

      // NOTE on what this test does and doesn't prove: container.listen
      // below itself keeps dashboardDataProvider alive for the rest of
      // this test regardless of whether the provider is annotated
      // keepAlive or not - confirmed by temporarily reverting keepAlive
      // and re-running, which still passed. So this test verifies the
      // reactive plumbing genuinely works end-to-end through the real
      // checkout provider graph (a real, valuable guarantee), but it
      // does NOT distinguish keepAlive from autodispose - it can't
      // reproduce "nothing was watching at all," which is what
      // keepAlive is actually defending against. See dashboard_screen.
      // dart's doc comment on dashboardChangeTicker for the honest
      // account of what's proven vs. defensive.
      final sawUpdatedCount = Completer<void>();
      final sub = container.listen(dashboardDataProvider, (previous, next) {
        if (next.value?.today.salesCount == 1 && !sawUpdatedCount.isCompleted) {
          sawUpdatedCount.complete();
        }
      });
      addTearDown(sub.close);

      // The write happens through the exact same provider graph the
      // real app uses (container.read(checkoutServiceProvider), not a
      // hand-built CheckoutService) - nothing here re-reads or
      // invalidates dashboardDataProvider explicitly. If the ticker
      // isn't genuinely always-on, this write is the one a disposed
      // subscription would have silently missed.
      final checkout = container.read(checkoutServiceProvider);
      final result = await checkout.checkout(
        cart: [CartItem(productId: productId, name: 'Widget', unitPrice: const Money(10000), costPrice: const Money(5000), quantity: 1)],
        discount: const Money(0),
        saleType: 'retail',
        paymentMethod: 'cash',
        userId: user.id,
      );
      expect(result.isOk, isTrue, reason: result.when(ok: (_) => '', failure: (m) => m));

      await sawUpdatedCount.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail('dashboardDataProvider never reflected the sale - the ticker did not react to the write'),
      );

      final after = container.read(dashboardDataProvider).value!;
      expect(after.today.salesCount, 1);
      expect(after.today.salesTotal, const Money(10000));
    },
  );
}
