// The "contract" between the real app and anything else that writes sales into a shop's
// sync (the old-iPad Lite till, and the platform's sync guard that checks its records).
//
// Real checkouts are run through the real CheckoutService, and the exact sync records the app
// would send are captured. They are compared (with ids, times and sale numbers masked) against
// test/fixtures/sync/sale_scenarios.json, which is also copied into the platform repo as the
// fixtures its guard must accept. If the app's record format ever changes this test fails, which
// is the signal to update the guard and the Lite till BEFORE shipping the change.
//
// To refresh the file after an intended change:
//   UPDATE_SYNC_FIXTURES=1 flutter test test/tool/sync_contract_fixtures_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/core/utils/id_generator.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Category, Product, User;
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/data/repositories/category_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/payment_record_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/product_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/sale_item_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/sale_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/user_repository_impl.dart';
import 'package:nexapos_mobile/data/sync/sync_table_registry.dart';
import 'package:nexapos_mobile/domain/entities/cart_item.dart';
import 'package:nexapos_mobile/domain/entities/category.dart';
import 'package:nexapos_mobile/domain/entities/product.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/checkout_service.dart';
import 'package:nexapos_mobile/domain/services/stock_service.dart';

const _fixturePath = 'test/fixtures/sync/sale_scenarios.json';
const _saleTables = ['sales', 'sale_items', 'payment_records', 'stock_movements'];

void main() {
  late AppDatabase db;
  late CheckoutService checkout;
  late String deviceId;
  late String cashierId;
  late String widgetId;
  late String gadgetId;
  late int setupRev;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    final syncMeta = SyncMetadataService(db);
    const clock = SystemClock();
    final ids = UuidIdGenerator();
    final categories = CategoryRepositoryImpl(db, db.categoriesDao, syncMeta, clock, ids);
    final products = ProductRepositoryImpl(db, db.productsDao, syncMeta, clock, ids);
    final saleRepository = SaleRepositoryImpl(db, db.salesDao, syncMeta, clock, ids);
    final saleItems = SaleItemRepositoryImpl(db, db.saleItemsDao, syncMeta, clock, ids);
    final paymentRecords = PaymentRecordRepositoryImpl(db, db.paymentRecordsDao, syncMeta, clock, ids);
    final stock = StockService(db, db.productsDao, db.stockMovementsDao, syncMeta, clock, ids);
    checkout = CheckoutService(db, saleRepository, saleItems, paymentRecords, products, stock, syncMeta, clock, ids);
    deviceId = await syncMeta.deviceId();

    final category = Category(id: ids.newId(), name: 'General', status: 'active');
    await categories.create(category);
    Future<String> product(String sku, String name, int retail, int wholesale, int cost) => products.create(Product(
          id: '',
          sku: sku,
          name: name,
          categoryId: category.id,
          retailPrice: Money(retail),
          wholesalePrice: Money(wholesale),
          costPrice: Money(cost),
          stockQty: 0,
          reorderLevel: 2,
          status: 'active',
        ));
    widgetId = await product('SKU-1', 'Widget', 10000, 8000, 5000);
    gadgetId = await product('SKU-2', 'Gadget', 25050, 21000, 12000);
    await stock.applyMovement(productId: widgetId, movementType: 'purchase', delta: 50);
    await stock.applyMovement(productId: gadgetId, movementType: 'purchase', delta: 50);

    final user = User(
      id: ids.newId(),
      role: UserRole.cashier,
      name: 'Cashier',
      username: 'cashier',
      passwordHash: r'$2a$10$irrelevantirrelevantirrelevantirrelevantirrelevan',
      status: 'active',
    );
    await UserRepositoryImpl(db, db.usersDao, syncMeta, clock, ids).create(user);
    cashierId = user.id;
    setupRev = await _maxRev(db, deviceId);
  });

  tearDown(() async => db.close());

  CartItem widget(int qty, {int price = 10000}) =>
      CartItem(productId: widgetId, name: 'Widget', unitPrice: Money(price), costPrice: const Money(5000), quantity: qty);
  CartItem gadget(int qty, {int price = 25050}) =>
      CartItem(productId: gadgetId, name: 'Gadget', unitPrice: Money(price), costPrice: const Money(12000), quantity: qty);

  /// Every sale-related record written since [sinceRev], in the order the app would push them.
  Future<List<Map<String, dynamic>>> changesSince(int sinceRev) async {
    final out = <Map<String, dynamic>>[];
    for (final table in _saleTables) {
      final rows = await syncTableAdapters[table]!.pendingRowsJson(db, deviceId, sinceRev);
      for (final payload in rows) {
        out.add({
          'table_name': table,
          'row_id': payload['id'],
          'local_rev': payload['localRev'],
          'updated_at': payload['updatedAt'],
          'payload': payload,
        });
      }
    }
    out.sort((a, b) => (a['local_rev'] as int).compareTo(b['local_rev'] as int));
    return out;
  }

  Future<Map<String, dynamic>> context() async => {
        'deviceId': deviceId,
        'cashierId': cashierId,
        'products': await syncTableAdapters['products']!.pendingRowsJson(db, deviceId, 0),
        'users': await syncTableAdapters['users']!.pendingRowsJson(db, deviceId, 0),
      };

  Future<Map<String, dynamic>> scenario(String name, String what, List<Future<void> Function()> stages) async {
    final outStages = <Map<String, dynamic>>[];
    var since = setupRev;
    var index = 0;
    for (final run in stages) {
      await run();
      final changes = await changesSince(since);
      since = changes.map((c) => c['local_rev'] as int).fold(since, (a, b) => a > b ? a : b);
      outStages.add({'stage': ++index, 'changes': changes});
    }
    return {'name': name, 'what': what, 'context': await context(), 'stages': outStages};
  }

  // One test per scenario so each starts from a clean shop; results are collected and compared
  // (or written) in the final test.
  final collected = <Map<String, dynamic>>[];

  test('cash sale of two products', () async {
    collected.add(await scenario('cash_sale_two_lines', 'Cash, retail, two product lines', [
      () async => (await checkout.checkout(
            cart: [widget(2), gadget(1)],
            discount: const Money.zero(),
            saleType: 'retail',
            paymentMethod: 'cash',
            userId: cashierId,
            cashReceived: const Money(50000),
          ))
              .when(ok: (_) {}, failure: (m) => fail(m)),
    ]));
  });

  test('cash sale with a discount and a customer name', () async {
    collected.add(await scenario('cash_sale_discount', 'Cash, retail, with a discount and a named customer', [
      () async => (await checkout.checkout(
            cart: [widget(3)],
            discount: const Money(1500),
            customerName: 'Wanjiru',
            saleType: 'retail',
            paymentMethod: 'cash',
            userId: cashierId,
            cashReceived: const Money(30000),
          ))
              .when(ok: (_) {}, failure: (m) => fail(m)),
    ]));
  });

  test('M-Pesa already received (manual)', () async {
    collected.add(await scenario('mpesa_manual_sale', 'M-Pesa received outside the app, with its reference', [
      () async => (await checkout.checkout(
            cart: [gadget(2)],
            discount: const Money.zero(),
            customerPhone: '0712345678',
            saleType: 'retail',
            paymentMethod: 'mpesa_manual',
            referenceNote: 'QWE123XYZ9',
            userId: cashierId,
          ))
              .when(ok: (_) {}, failure: (m) => fail(m)),
    ]));
  });

  test('wholesale sale', () async {
    collected.add(await scenario('wholesale_sale', 'Cash, wholesale prices', [
      () async => (await checkout.checkout(
            cart: [widget(10, price: 8000)],
            discount: const Money.zero(),
            saleType: 'wholesale',
            paymentMethod: 'cash',
            userId: cashierId,
            cashReceived: const Money(80000),
          ))
              .when(ok: (_) {}, failure: (m) => fail(m)),
    ]));
  });

  test('a manual (non-catalogue) line', () async {
    collected.add(await scenario('manual_line_sale', 'A product line plus a manual line that has no product and no stock', [
      () async => (await checkout.checkout(
            cart: [
              widget(1),
              const CartItem(name: 'Delivery', unitPrice: Money(20000), costPrice: Money(0), quantity: 1),
            ],
            discount: const Money.zero(),
            saleType: 'retail',
            paymentMethod: 'cash',
            userId: cashierId,
            cashReceived: const Money(30000),
          ))
              .when(ok: (_) {}, failure: (m) => fail(m)),
    ]));
  });

  test('Paystack sale: pending, then confirmed paid', () async {
    late String saleId;
    collected.add(await scenario('paystack_pending_then_paid', 'Online payment: reserved and pending, then finalised as paid', [
      () async => (await checkout.beginPaystackSale(
            cart: [widget(1), gadget(1)],
            discount: const Money.zero(),
            saleType: 'retail',
            userId: cashierId,
            saleNumber: 'AAAAAA-20261105120000-ZZZZ',
            paystackReference: 'AAAAAA-20261105120000-ZZZZ',
          ))
              .when(ok: (sale) => saleId = sale.id, failure: (m) => fail(m)),
      () async => (await checkout.finalizePaystackSale(saleId)).when(ok: (_) {}, failure: (m) => fail(m)),
    ]));
  });

  test('Paystack sale: pending, then cancelled (stock returned)', () async {
    late String saleId;
    collected.add(await scenario('paystack_pending_then_cancelled', 'Online payment abandoned: stock restored, sale cancelled', [
      () async => (await checkout.beginPaystackSale(
            cart: [widget(2)],
            discount: const Money.zero(),
            saleType: 'retail',
            userId: cashierId,
            saleNumber: 'BBBBBB-20261105130000-YYYY',
            paystackReference: 'BBBBBB-20261105130000-YYYY',
          ))
              .when(ok: (sale) => saleId = sale.id, failure: (m) => fail(m)),
      () async => (await checkout.cancelPaystackSale(saleId)).when(ok: (_) {}, failure: (m) => fail(m)),
    ]));
  });

  test('Paystack split sale: cash part plus online part', () async {
    late String saleId;
    collected.add(await scenario('paystack_split_paid', 'Part cash, remainder online, then paid', [
      () async => (await checkout.beginPaystackSale(
            cart: [gadget(2)],
            discount: const Money.zero(),
            saleType: 'retail',
            userId: cashierId,
            saleNumber: 'CCCCCC-20261105140000-XXXX',
            paystackReference: 'CCCCCC-20261105140000-XXXX',
            cashReceived: const Money(20000),
          ))
              .when(ok: (sale) => saleId = sale.id, failure: (m) => fail(m)),
      () async => (await checkout.finalizePaystackSale(saleId)).when(ok: (_) {}, failure: (m) => fail(m)),
    ]));
  });

  test('the sync records the app produces match the committed contract', () {
    // Masks everything that legitimately differs between runs.
    String mask(Object? value) => jsonEncode(value)
        .replaceAll(RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'), '<id>')
        .replaceAll(RegExp(r'[0-9A-F]{6}-\d{14}-[0-9A-Z]{4}'), '<saleNumber>')
        .replaceAll(RegExp(r'\d{4}-\d\d-\d\dT[\d:.]+Z?'), '<time>')
        .replaceAll(RegExp(r'"(local_rev|localRev)":\d+'), r'"rev":0')
        .replaceAll(RegExp(r'"(stage|createdAt|updatedAt)":"?[^,}"]*"?'), '"x":0');

    final ordered = [...collected]..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    final file = File(_fixturePath);
    if (Platform.environment['UPDATE_SYNC_FIXTURES'] == '1') {
      file.createSync(recursive: true);
      file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert({'generated_by': 'test/tool/sync_contract_fixtures_test.dart', 'scenarios': ordered})}\n');
      // ignore: avoid_print
      print('Wrote $_fixturePath (${ordered.length} scenarios).');
      return;
    }
    expect(file.existsSync(), isTrue, reason: 'Missing $_fixturePath - run with UPDATE_SYNC_FIXTURES=1 once.');
    final committed = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final committedScenarios = (committed['scenarios'] as List).cast<Map<String, dynamic>>();
    expect(ordered.map((s) => s['name']), committedScenarios.map((s) => s['name']));
    for (var i = 0; i < ordered.length; i++) {
      expect(
        mask(ordered[i]['stages']),
        mask(committedScenarios[i]['stages']),
        reason: 'The sync records for "${ordered[i]['name']}" changed. The platform sync guard and the Lite till '
            'must be updated to match BEFORE this ships; then refresh the fixtures with UPDATE_SYNC_FIXTURES=1.',
      );
    }
  });
}

Future<int> _maxRev(AppDatabase db, String deviceId) async {
  var max = 0;
  for (final adapter in syncTableAdapters.values) {
    for (final row in await adapter.pendingRowsJson(db, deviceId, 0)) {
      final rev = row['localRev'] as int;
      if (rev > max) max = rev;
    }
  }
  return max;
}
