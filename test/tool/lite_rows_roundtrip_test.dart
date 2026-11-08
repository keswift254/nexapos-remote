// The third safety layer for the old-iPad Lite till: sales built by the Lite page's JavaScript are applied through the
// app's REAL sync code, the way another device applies them when it pulls them from the server, and the app's database
// must end up exactly right - the sale, its lines, its payment, and the stock the app works out from the movements.
//
// test/fixtures/sync/lite_built_sales.json is written by tests/lite/export-built-sales.js in the website repo, with the
// expected results worked out independently of the Lite code.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/data/sync/sync_table_registry.dart';

const _fixturePath = 'test/fixtures/sync/lite_built_sales.json';

void main() {
  late Map<String, dynamic> fixture;

  setUpAll(() {
    final file = File(_fixturePath);
    expect(file.existsSync(), isTrue, reason: 'Missing $_fixturePath - generate it with tests/lite/export-built-sales.js in the website repo.');
    fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  });

  Future<AppDatabase> freshShop() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    final context = fixture['context'] as Map<String, dynamic>;
    // What another device already holds before the sale reaches it: the category, products, cashier and an opening
    // stock purchase - applied through the same adapters a pull uses.
    await syncTableAdapters['categories']!.applyPayload(db, Map<String, dynamic>.from(context['category'] as Map));
    for (final product in context['products'] as List) {
      await syncTableAdapters['products']!.applyPayload(db, Map<String, dynamic>.from(product as Map));
    }
    for (final user in context['users'] as List) {
      await syncTableAdapters['users']!.applyPayload(db, Map<String, dynamic>.from(user as Map));
    }
    var n = 0;
    for (final product in context['products'] as List) {
      n += 1;
      await syncTableAdapters['stock_movements']!.applyPayload(db, {
        'id': '00000000-0000-4000-8000-0000000000e$n',
        'createdAt': '2026-11-01T08:00:00.000000Z',
        'updatedAt': '2026-11-01T08:00:00.000000Z',
        'deletedAt': null,
        'localRev': 1000 + n,
        'createdByDeviceId': 'main-device',
        'syncState': 'local_only',
        'productId': (product as Map)['id'],
        'userId': null,
        'movementType': 'purchase',
        'quantity': context['openingStock'],
        'note': null,
      });
    }
    return db;
  }

  Future<void> recomputeStock(AppDatabase db) async {
    // The same statement SyncService runs after applying pulled stock movements.
    final products = await db.customSelect('SELECT id FROM products').get();
    for (final row in products) {
      await db.customStatement(
        'UPDATE products SET stock_qty = (SELECT COALESCE(SUM(quantity), 0) FROM stock_movements WHERE product_id = ? AND deleted_at IS NULL) WHERE id = ?',
        [row.read<String>('id'), row.read<String>('id')],
      );
    }
  }

  test('the Lite page builds sales the real app accepts and records correctly', () async {
    final scenarios = (fixture['scenarios'] as List).cast<Map<String, dynamic>>();
    expect(scenarios, isNotEmpty);
    final opening = (fixture['context'] as Map)['openingStock'] as int;

    for (final scenario in scenarios) {
      final db = await freshShop();
      addTearDown(db.close);
      final expected = scenario['expect'] as Map<String, dynamic>;

      // Applied in the order pushed, table by table, as a pulling device does (sales and payments merge by
      // last-write-wins; lines and stock movements are append-only).
      for (final change in (scenario['changes'] as List).cast<Map<String, dynamic>>()) {
        await syncTableAdapters[change['table_name']]!.applyPayload(db, Map<String, dynamic>.from(change['payload'] as Map));
      }
      await recomputeStock(db);

      final sale = (await db.customSelect('SELECT id, subtotal_cents, discount_cents, total_cents, status, payment_method FROM sales').get()).single;
      expect(sale.read<int>('subtotal_cents'), expected['subtotalCents'], reason: '${scenario['name']}: subtotal');
      expect(sale.read<int>('discount_cents'), expected['discountCents'], reason: '${scenario['name']}: discount');
      expect(sale.read<int>('total_cents'), expected['totalCents'], reason: '${scenario['name']}: total');
      expect(sale.read<String>('status'), expected['status']);
      expect(sale.read<String>('payment_method'), expected['paymentMethod']);

      final items = await db.customSelect('SELECT quantity, unit_price_cents, line_total_cents FROM sale_items WHERE sale_id = ?', variables: [Variable<String>(sale.read<String>('id'))]).get();
      expect(items.length, expected['itemCount'], reason: '${scenario['name']}: lines');
      expect(items.fold<int>(0, (sum, row) => sum + row.read<int>('line_total_cents')), expected['subtotalCents'], reason: '${scenario['name']}: lines add up to the subtotal');

      final payments = await db.customSelect('SELECT method, amount_cents, status, reference_note FROM payment_records WHERE sale_id = ?', variables: [Variable<String>(sale.read<String>('id'))]).get();
      final expectedPayment = expected['payment'] as Map<String, dynamic>?;
      if (expectedPayment == null) {
        expect(payments, isEmpty, reason: '${scenario['name']}: a cash sale has no payment record');
      } else {
        expect(payments.length, 1);
        expect(payments.single.read<String>('method'), expectedPayment['method']);
        expect(payments.single.read<int>('amount_cents'), expectedPayment['amountCents']);
        expect(payments.single.read<String>('status'), expectedPayment['status']);
        expect(payments.single.read<String?>('reference_note'), expectedPayment['referenceNote']);
      }

      // Stock: what the app works out from the movements is opening stock minus what was sold.
      final sold = <String, int>{for (final pair in (expected['stockSold'] as List)) (pair as List)[0] as String: pair[1] as int};
      for (final product in ((fixture['context'] as Map)['products'] as List)) {
        final id = (product as Map)['id'] as String;
        final row = (await db.customSelect('SELECT stock_qty FROM products WHERE id = ?', variables: [Variable<String>(id)]).get()).single;
        expect(row.read<int>('stock_qty'), opening - (sold[id] ?? 0), reason: '${scenario['name']}: stock of ${product['name']}');
      }
    }
  });
}
