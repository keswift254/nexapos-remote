import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/data/import/shop_archive.dart';
import 'package:nexapos_mobile/data/import/legacy_pos_mapper.dart';
import 'package:nexapos_mobile/data/import/legacy_pos_reader.dart';
import 'package:nexapos_mobile/data/local/database.dart';

Map<String, dynamic> legacyFixture() => {
  'tables': {
    'roles': [
      {'id': 1, 'name': 'admin'},
    ],
    'users': [
      {
        'id': 1,
        'role_id': 1,
        'name': 'Old cashier',
        'email': 'old@example.com',
      },
    ],
    'products': [
      {
        'id': 1,
        'sku': 'TEA',
        'name': 'Tea',
        'category': 'Food',
        'retail_price': '12.50',
        'wholesale_price': '11.00',
        'cost_price': '5.20',
        'stock_qty': 8,
        'created_at': '2026-09-01 12:00:00',
      },
    ],
    'sales': [
      {
        'id': 1,
        'sale_number': 'S001',
        'user_id': 1,
        'sale_type': 'retail',
        'payment_method': 'cash',
        'subtotal': '25.00',
        'discount': '0.00',
        'total': '25.00',
        'status': 'paid',
        'created_at': '2026-09-02 12:00:00',
      },
    ],
    'sale_items': [
      {
        'id': 1,
        'sale_id': 1,
        'product_id': 1,
        'item_name': 'Tea',
        'quantity': 2,
        'unit_price': '12.50',
        'cost_price': '5.20',
        'line_total': '25.00',
      },
    ],
    'stock_movements': [
      {
        'id': 1,
        'product_id': 1,
        'user_id': 1,
        'movement_type': 'sale',
        'quantity': -2,
        'created_at': '2026-09-02 12:00:00',
      },
    ],
    'expenses': [
      {
        'id': 1,
        'user_id': 1,
        'title': 'Delivery',
        'amount': '3.00',
        'expense_date': '2026-09-02',
        'created_at': '2026-09-02 14:00:00',
      },
    ],
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('legacy history preserves totals, links, timezone and opening stock; repeated import is idempotent', () async {
    final archive = LegacyPosMapper('fixture').convert(legacyFixture());
    await archive.validate();
    final first = await archive.mergeInto(db);
    expect(first['sales'], 1);
    final product = await db.select(db.products).getSingle();
    expect(product.stockQty, 8);
    final movements = await db.select(db.stockMovements).get();
    expect(movements.map((m) => m.quantity).reduce((a, b) => a + b), 8);
    final sale = await db.select(db.sales).getSingle();
    expect(sale.totalCents, 2500);
    expect(sale.createdAt, '2026-09-02T09:00:00.000Z');
    expect((await db.select(db.users).getSingle()).status, 'disabled');
    final second = await archive.mergeInto(db);
    expect(second.values.reduce((a, b) => a + b), 0);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test('unknown tables and fractional units fail instead of silently dropping data', () {
    final extra = legacyFixture();
    (extra['tables'] as Map)['supplier_invoices'] = [
      {'id': 1},
    ];
    expect(
      () => LegacyPosMapper('fixture').convert(extra),
      throwsFormatException,
    );
    final fractional = legacyFixture();
    ((fractional['tables'] as Map)['products'] as List)[0]['stock_qty'] = '2.5';
    expect(
      () => LegacyPosMapper('fixture').convert(fractional),
      throwsFormatException,
    );
    expect(() => LegacyPosMapper.money('1.001'), throwsFormatException);
    expect(LegacyPosMapper.money('123.45'), 12345);
  });

  test(
    'conflict rolls back rows inserted earlier in the same restore',
    () async {
      final archive = LegacyPosMapper('fixture').convert(legacyFixture());
      await archive.mergeInto(db);
      final changed = LegacyPosMapper('fixture').convert(legacyFixture());
      final category =
          Map<String, dynamic>.from(changed.tables['categories']!.first)
            ..['id'] = 'new-category'
            ..['name'] = 'New';
      changed.tables['categories']!.add(category);
      changed.tables['sales']!.first['total_cents'] = 2600;
      await expectLater(changed.mergeInto(db), throwsStateError);
      expect(
        await (db.select(
          db.categories,
        )..where((t) => t.id.equals('new-category'))).get(),
        isEmpty,
      );
      expect((await db.select(db.sales).getSingle()).totalCents, 2500);
    },
  );

  test('backup includes unsynced data, decrypts only with correct password, rejects tampering', () async {
    await LegacyPosMapper('fixture').convert(legacyFixture()).mergeInto(db);
    final archive = await ShopArchive.capture(db);
    final bytes = await ArchiveEncryption.encode(
      archive,
      'test-password-12345',
    );
    final restored = await ArchiveEncryption.decode(
      bytes,
      'test-password-12345',
    );
    expect(restored.tables['sales']!.length, 1);
    expect(utf8.decode(bytes), isNot(contains('Old cashier')));
    await expectLater(
      ArchiveEncryption.decode(bytes, 'wrong-password'),
      throwsA(anything),
    );
    final envelope = jsonDecode(utf8.decode(bytes)) as Map;
    envelope['mac'] = base64Encode(List.filled(16, 0));
    await expectLater(
      ArchiveEncryption.decode(
        Uint8List.fromList(utf8.encode(jsonEncode(envelope))),
        'test-password-12345',
      ),
      throwsA(anything),
    );
  });

  test(
    'invalid foreign keys and stock mismatch are refused before restore',
    () async {
      final archive = LegacyPosMapper('fixture').convert(legacyFixture());
      archive.tables['sales']!.first['user_id'] = 'missing';
      await expectLater(archive.mergeInto(db), throwsA(anything));
      expect(await db.select(db.products).get(), isEmpty);
      final badStock = LegacyPosMapper('fixture').convert(legacyFixture());
      badStock.tables['products']!.first['stock_qty'] = 90;
      await expectLater(badStock.validate(), throwsFormatException);
    },
  );

  test('URL inspection is limited to explicit localhost targets', () {
    expect(
      LegacyPosReader.localUri(
        'http://localhost/pos/public/index.php?page=login',
      ).host,
      'localhost',
    );
    for (final url in [
      'https://example.com',
      'file:///etc/passwd',
      'http://user:pass@localhost',
      'http://localhost.example.com',
    ]) {
      expect(() => LegacyPosReader.localUri(url), throwsFormatException);
    }
  });

  test('business settings restore into default empty shop but conflict with configured settings', () async {
    await db.customStatement(
      "UPDATE business_settings SET business_name='Source shop', phone='123'",
    );
    final archive = await ShopArchive.capture(db);
    final target = AppDatabase(NativeDatabase.memory());
    try {
      await archive.mergeInto(target);
      expect(
        (await target.select(target.businessSettings).getSingle()).businessName,
        'Source shop',
      );
      expect(
        (await archive.mergeInto(target)).values.reduce((a, b) => a + b),
        0,
      );
      await target.customStatement(
        "UPDATE business_settings SET business_name='Other shop'",
      );
      await expectLater(archive.mergeInto(target), throwsStateError);
      expect(
        (await target.select(target.businessSettings).getSingle()).businessName,
        'Other shop',
      );
    } finally {
      await target.close();
    }
  });
}
