// The "contract" between the real app and anything else that reads or writes REFUNDS in a shop's sync (the platform's
// reports for the old-iPad Lite till, the sync guard that vets what the till pushes, and the Lite till itself) - the same
// idea as expense_contract_fixtures_test.dart.
//
// Real sales are rung up and refunded through the real CheckoutService and RefundService, and the exact sync records the
// app would send are captured. They are compared (ids and times masked) against test/fixtures/sync/refund_scenarios.json,
// which is also copied into the platform and site repos as the records their code must understand. If the app's refund
// record format ever changes this test fails: the signal to update them BEFORE shipping the change.
//
// To refresh the file after an intended change:
//   UPDATE_SYNC_FIXTURES=1 flutter test test/tool/refund_contract_fixtures_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/data/sync/sync_table_registry.dart';
import 'package:nexapos_mobile/domain/entities/sale.dart';
import 'package:nexapos_mobile/domain/services/refund_service.dart';

import '../support/shop_harness.dart';

const _fixturePath = 'test/fixtures/sync/refund_scenarios.json';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ShopHarness shop;
  late String deviceId;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    shop = await ShopHarness.create();
    deviceId = await _deviceId(shop);
  });
  tearDown(() => shop.close());

  /// Every record written since [sinceRev], in the order the app wrote them, as it would push them.
  Future<List<Map<String, dynamic>>> changesSince(int sinceRev) async {
    final out = <Map<String, dynamic>>[];
    for (final adapter in syncTableAdapters.values) {
      if (!const {'sales', 'sale_items', 'stock_movements', 'payment_records'}.contains(adapter.tableName)) continue;
      for (final payload in await adapter.pendingRowsJson(shop.db, deviceId, sinceRev)) {
        out.add({
          'table_name': adapter.tableName,
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
        'cashierId': shop.cashier.id,
        'managerId': shop.manager.id,
        'products': await syncTableAdapters['products']!.pendingRowsJson(shop.db, deviceId, 0),
        'users': await syncTableAdapters['users']!.pendingRowsJson(shop.db, deviceId, 0),
      };

  /// Runs each stage and captures the records it wrote.
  Future<Map<String, dynamic>> scenario(String name, String what, List<Future<void> Function()> stages) async {
    final outStages = <Map<String, dynamic>>[];
    var since = await _maxRev(shop, deviceId);
    var index = 0;
    for (final run in stages) {
      await run();
      final changes = await changesSince(since);
      since = changes.map((c) => c['local_rev'] as int).fold(since, (a, b) => a > b ? a : b);
      outStages.add({'stage': ++index, 'changes': changes});
    }
    return {'name': name, 'what': what, 'context': await context(), 'stages': outStages};
  }

  test('the sync records the app produces for a refund match the committed contract', () async {
    String mask(Object? value) => jsonEncode(value)
        .replaceAll(RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'), '<id>')
        .replaceAll(RegExp(r'\d{4}-\d\d-\d\dT[\d:.]+Z?'), '<time>')
        .replaceAll(RegExp(r'[0-9A-F]{6}-\d{14}-[0-9A-Z]{4}'), '<number>')
        .replaceAll(RegExp(r'"(local_rev|localRev)":\d+'), r'"rev":0')
        .replaceAll(RegExp(r'"(stage|createdAt|updatedAt|deletedAt)":"?[^,}"]*"?'), '"x":0');

    final fresh = <Map<String, dynamic>>[];

    late Sale cashSale;
    fresh.add(await scenario('refund_whole_cash_sale', 'A cash sale of two products, then the whole sale refunded and put back in stock.', [
      () async => cashSale = await shop.sell([
            shop.line(shop.widgetId, 'Widget', 10000, 6000, 2),
            shop.line(shop.gadgetId, 'Gadget', 25050, 15000, 1),
          ]),
      () async => await shop.mustRefund(cashSale, await shop.everything(cashSale.id), reason: 'Wrong goods'),
    ]));

    late Sale mpesaSale;
    fresh.add(await scenario('refund_partial_mpesa_sale_in_two_parts', 'An M-Pesa sale of three widgets: one refunded and put back, then the other two refunded as damaged (not put back).', [
      () async => mpesaSale = await shop.sell([shop.line(shop.widgetId, 'Widget', 10000, 6000, 3)], method: 'mpesa_manual'),
      () async => await shop.mustRefund(mpesaSale, [await shop.choose(mpesaSale.id, shop.widgetId, 1)], reason: 'Bent'),
      () async => await shop.mustRefund(mpesaSale, [await shop.choose(mpesaSale.id, shop.widgetId, 2, restock: false)], reason: 'Damaged'),
    ]));

    late Sale discounted;
    fresh.add(await scenario('refund_discounted_sale_in_three_parts', 'A discounted cash sale refunded one widget at a time: the discount comes back in proportion, the last part takes the rounding.', [
      () async => discounted = await shop.sell([shop.line(shop.widgetId, 'Widget', 10000, 6000, 3)], discount: 10000),
      () async => await shop.mustRefund(discounted, [await shop.choose(discounted.id, shop.widgetId, 1)], reason: 'one'),
      () async => await shop.mustRefund(discounted, [await shop.choose(discounted.id, shop.widgetId, 1)], reason: 'two'),
      () async => await shop.mustRefund(discounted, [await shop.choose(discounted.id, shop.widgetId, 1)], reason: 'three'),
    ]));

    late Sale split;
    fresh.add(await scenario('refund_split_cash_and_mpesa_sale_with_discount', 'A discounted sale paid partly in cash and the rest by an M-Pesa prompt: refunded one widget, then the other three; the discount and the cash share come back in proportion, to the cent.', [
      () async => split = await shop.sellSplit([shop.line(shop.widgetId, 'Widget', 10000, 6000, 4)], 10000, discount: 4000),
      () async => await shop.mustRefund(split, [await shop.choose(split.id, shop.widgetId, 1)], reason: 'one'),
      () async => await shop.mustRefund(split, [await shop.choose(split.id, shop.widgetId, 3)], reason: 'three'),
    ]));

    late Sale splitTill;
    fresh.add(await scenario('refund_split_cash_and_till_sale_with_discount', 'A discounted sale paid partly in cash and the rest to the shop\'s own till (M-Pesa Till/Paybill): refunded one widget, then the other three; the discount and the cash share come back in proportion, to the cent.', [
      () async => splitTill = await shop.sellSplitTill([shop.line(shop.widgetId, 'Widget', 10000, 6000, 4)], 10000, discount: 4000),
      () async => await shop.mustRefund(splitTill, [await shop.choose(splitTill.id, shop.widgetId, 1)], reason: 'one'),
      () async => await shop.mustRefund(splitTill, [await shop.choose(splitTill.id, shop.widgetId, 3)], reason: 'three'),
    ]));

    late Sale manual;
    fresh.add(await scenario('refund_manual_item', 'A sale with a manual item (no product): refunding it moves no stock.', [
      () async => manual = await shop.sell([
            shop.line(null, 'Delivery', 5000, 0, 1),
            shop.line(shop.widgetId, 'Widget', 10000, 6000, 1),
          ]),
      () async {
        final delivery = (await shop.saleItems.forSale(manual.id)).firstWhere((i) => i.productId == null);
        await shop.mustRefund(manual, [RefundChoice(itemId: delivery.id, quantity: 1)], reason: 'Not delivered');
      },
    ]));

    final ordered = [...fresh]..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    final file = File(_fixturePath);
    if (Platform.environment['UPDATE_SYNC_FIXTURES'] == '1') {
      file.createSync(recursive: true);
      file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert({'generated_by': 'test/tool/refund_contract_fixtures_test.dart', 'scenarios': ordered})}\n');
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
        reason: 'The sync records for "${ordered[i]['name']}" changed. The platform and the Lite till must be updated '
            'to match BEFORE this ships; then refresh the fixtures with UPDATE_SYNC_FIXTURES=1.',
      );
    }
  });
}

Future<String> _deviceId(ShopHarness shop) async {
  final rows = await shop.db.customSelect('SELECT device_id FROM device_meta LIMIT 1').get();
  return rows.single.read<String>('device_id');
}

Future<int> _maxRev(ShopHarness shop, String deviceId) async {
  var max = 0;
  for (final adapter in syncTableAdapters.values) {
    for (final row in await adapter.pendingRowsJson(shop.db, deviceId, 0)) {
      final rev = row['localRev'] as int;
      if (rev > max) max = rev;
    }
  }
  return max;
}
