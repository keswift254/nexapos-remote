import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/features/checkout/cart_notifier.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'a cart with items survives an app restart (a fresh provider tree reading the same database)',
    () async {
      final first = buildContainer();
      first.read(cartProvider.notifier).addManualItem(
            name: 'Sugar 1kg',
            quantity: 2,
            price: Money.fromMajor(150),
          );
      first.read(cartProvider.notifier).setDiscount(Money.fromMajor(10));
      // The write is fire-and-forget from listenSelf - drain the event
      // queue so both persisted writes actually finish reaching the
      // database before the "next launch" reads it back.
      await pumpEventQueue();

      final second = buildContainer();
      await second.read(cartProvider.notifier).restore();

      final restored = second.read(cartProvider);
      expect(restored.items, hasLength(1));
      expect(restored.items.single.name, 'Sugar 1kg');
      expect(restored.items.single.quantity, 2);
      expect(restored.discount, Money.fromMajor(10));
    },
  );

  test(
    'completing a sale (clear()) leaves nothing for the next launch to restore',
    () async {
      final first = buildContainer();
      first.read(cartProvider.notifier).addManualItem(
            name: 'Bread',
            quantity: 1,
            price: Money.fromMajor(60),
          );
      await pumpEventQueue();
      first.read(cartProvider.notifier).clear();
      await pumpEventQueue();

      final second = buildContainer();
      await second.read(cartProvider.notifier).restore();

      expect(second.read(cartProvider).isEmpty, isTrue);
    },
  );

  test('restoring with nothing saved leaves a normal empty cart', () async {
    final container = buildContainer();
    await container.read(cartProvider.notifier).restore();
    expect(container.read(cartProvider).isEmpty, isTrue);
  });
}
