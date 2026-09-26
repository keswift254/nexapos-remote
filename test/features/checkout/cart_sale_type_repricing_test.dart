import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Product;
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/domain/entities/product.dart';
import 'package:nexapos_mobile/features/checkout/cart_notifier.dart';

/// Marking the sale "Wholesale" in the cart must re-price the lines that are
/// already there (it used to change only the label: lines kept the price they
/// were added at, and only products added afterwards got the wholesale price).
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer buildContainer() {
    final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    return container;
  }

  Product product(String id, {required int retail, required int wholesale, String? name}) => Product(
    id: id,
    sku: 'SKU-$id',
    name: name ?? 'Product $id',
    categoryId: 'cat',
    retailPrice: Money(retail),
    wholesalePrice: Money(wholesale),
    costPrice: const Money(50),
    stockQty: 100,
    reorderLevel: 0,
    status: 'active',
  );

  test('switching to wholesale re-prices the lines already in the cart, and back again', () {
    final container = buildContainer();
    final cart = container.read(cartProvider.notifier);
    cart.addProduct(product('a', retail: 10000, wholesale: 7000));
    cart.addProduct(product('b', retail: 2500, wholesale: 2000));
    cart.updateQuantity(0, 2);
    expect(container.read(cartProvider).subtotal, const Money(22500));

    cart.setSaleType('wholesale');

    var state = container.read(cartProvider);
    expect(state.saleType, 'wholesale');
    expect(state.items[0].unitPrice, const Money(7000));
    expect(state.items[1].unitPrice, const Money(2000));
    expect(state.items[0].quantity, 2, reason: 'quantities are untouched');
    expect(state.subtotal, const Money(16000));

    cart.setSaleType('retail');

    state = container.read(cartProvider);
    expect(state.items[0].unitPrice, const Money(10000));
    expect(state.subtotal, const Money(22500));
  });

  test('a product added while the sale is wholesale gets the wholesale price, and goes back to retail with it', () {
    final container = buildContainer();
    final cart = container.read(cartProvider.notifier);
    cart.setSaleType('wholesale');

    cart.addProduct(product('a', retail: 10000, wholesale: 7000));
    expect(container.read(cartProvider).items.single.unitPrice, const Money(7000));

    cart.setSaleType('retail');
    expect(container.read(cartProvider).items.single.unitPrice, const Money(10000));
  });

  test('a manual (non-catalog) item keeps the price it was typed with', () {
    final container = buildContainer();
    final cart = container.read(cartProvider.notifier);
    cart.addManualItem(name: 'Delivery', quantity: 1, price: const Money(30000));
    cart.addProduct(product('a', retail: 10000, wholesale: 7000));

    cart.setSaleType('wholesale');

    final state = container.read(cartProvider);
    expect(state.items[0].unitPrice, const Money(30000));
    expect(state.items[1].unitPrice, const Money(7000));
  });

  test('a product with no wholesale price set sells at retail, never for nothing', () {
    final container = buildContainer();
    final cart = container.read(cartProvider.notifier);
    cart.addProduct(product('a', retail: 10000, wholesale: 0));
    cart.addProduct(product('b', retail: 2500, wholesale: 2000));

    cart.setSaleType('wholesale');

    var state = container.read(cartProvider);
    expect(state.items[0].unitPrice, const Money(10000));
    expect(state.items[1].unitPrice, const Money(2000));

    cart.addProduct(product('c', retail: 500, wholesale: 0)); // added while wholesale
    state = container.read(cartProvider);
    expect(state.items[2].unitPrice, const Money(500));
  });

  test('adding a product that is already in the cart still just adds one, at the current type\'s price', () {
    final container = buildContainer();
    final cart = container.read(cartProvider.notifier);
    final a = product('a', retail: 10000, wholesale: 7000);
    cart.addProduct(a);
    cart.setSaleType('wholesale');

    cart.addProduct(a);

    final state = container.read(cartProvider);
    expect(state.items, hasLength(1));
    expect(state.items.single.quantity, 2);
    expect(state.items.single.unitPrice, const Money(7000));
  });

  test('the prices survive an app restart, so a restored cart can still be switched', () async {
    final first = buildContainer();
    first.read(cartProvider.notifier).addProduct(product('a', retail: 10000, wholesale: 7000));
    await pumpEventQueue();

    final second = buildContainer();
    await second.read(cartProvider.notifier).restore();
    second.read(cartProvider.notifier).setSaleType('wholesale');

    expect(second.read(cartProvider).items.single.unitPrice, const Money(7000));
  });

  test('a cart draft saved by an older version is given its catalog prices from the products', () async {
    const now = '2026-09-01T00:00:00.000000Z';
    final deviceId = await SyncMetadataService(db).deviceId();
    await db.into(db.categories).insert(CategoriesCompanion.insert(
      id: 'cat', name: 'General', createdAt: now, updatedAt: now, localRev: 1, createdByDeviceId: deviceId,
    ));
    await db.into(db.products).insert(ProductsCompanion.insert(
      id: 'a', sku: 'SKU-a', name: 'Sugar', categoryId: 'cat',
      retailPriceCents: 10000, wholesalePriceCents: 7000, costPriceCents: 50,
      createdAt: now, updatedAt: now, localRev: 2, createdByDeviceId: deviceId,
    ));
    // The draft exactly as version 1.0.50 wrote it: no catalog prices on the line.
    final oldDraft = {
      'items': [
        {'productId': 'a', 'name': 'Sugar', 'unitPriceCents': 10000, 'costPriceCents': 50, 'quantity': 3},
        {'productId': null, 'name': 'Delivery', 'unitPriceCents': 30000, 'costPriceCents': 0, 'quantity': 1},
        {'productId': 'gone', 'name': 'Discontinued', 'unitPriceCents': 900, 'costPriceCents': 0, 'quantity': 1},
      ],
      'saleType': 'retail',
      'discount': 0,
      'customerName': '',
      'customerPhone': '',
      'paymentMethod': 'cash',
      'referenceNote': '',
      'cashReceived': 0,
    };
    await db.customStatement(
      "INSERT OR REPLACE INTO local_safety_state(id,value) VALUES('cart_draft',?)",
      [jsonEncode(oldDraft)],
    );

    final container = buildContainer();
    await container.read(cartProvider.notifier).restore();
    final restored = container.read(cartProvider);
    expect(restored.items[0].unitPrice, const Money(10000), reason: 'restoring changes no price by itself');
    expect(restored.items[0].wholesalePrice, const Money(7000));

    container.read(cartProvider.notifier).setSaleType('wholesale');

    final state = container.read(cartProvider);
    expect(state.items[0].unitPrice, const Money(7000));
    expect(state.items[0].quantity, 3);
    expect(state.items[1].unitPrice, const Money(30000), reason: 'manual item untouched');
    expect(state.items[2].unitPrice, const Money(900), reason: 'a product that no longer exists keeps its price');
  });

  test('a draft that cannot be read against the database is still restored as it was', () async {
    final oldDraft = {
      'items': [
        {'productId': 'a', 'name': 'Sugar', 'unitPriceCents': 10000, 'costPriceCents': 50, 'quantity': 1},
      ],
      'saleType': 'retail',
      'discount': 0,
      'customerName': '',
      'customerPhone': '',
      'paymentMethod': 'cash',
      'referenceNote': '',
      'cashReceived': 0,
    };
    await db.customStatement(
      "INSERT OR REPLACE INTO local_safety_state(id,value) VALUES('cart_draft',?)",
      [jsonEncode(oldDraft)],
    );

    final container = buildContainer(); // no such product in this database
    await container.read(cartProvider.notifier).restore();

    expect(container.read(cartProvider).items.single.unitPrice, const Money(10000));
  });
}
