import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/data/import/legacy_pos_mapper.dart';
import 'package:nexapos_mobile/data/import/legacy_pos_reader.dart';
import 'package:nexapos_mobile/data/local/database.dart';

// Opt-in smoke test: the source is read-only and the destination is in memory.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // This explicitly opted-in integration test needs the real local HTTP server.
  HttpOverrides.global = null;
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  test('local PHP history previews and merges without losing transactions', () async {
    final env = Platform.environment;
    final raw = await LegacyPosReader().readDatabase(
      url:
          env['NEXAPOS_LEGACY_URL'] ??
          'http://localhost/pos/public/index.php?page=login',
      phpPath: env['NEXAPOS_LEGACY_PHP'] ?? r'C:\xampp\php\php.exe',
      database: env['NEXAPOS_LEGACY_DATABASE'] ?? 'nexapos',
      username: env['NEXAPOS_LEGACY_USER'] ?? 'root',
      password: env['NEXAPOS_LEGACY_PASSWORD'] ?? '',
      port: int.parse(env['NEXAPOS_LEGACY_PORT'] ?? '3306'),
    );
    final input = raw['tables'] as Map;
    final archive = LegacyPosMapper(raw['source'] as String).convert(raw);
    final db = AppDatabase(NativeDatabase.memory());
    try {
      final counts = await archive.mergeInto(db);
      for (final table in [
        'products',
        'sales',
        'sale_items',
        'expenses',
        'users',
      ]) {
        expect(counts[table], (input[table] as List).length, reason: table);
      }
      final expectedTotal = (input['sales'] as List).fold<int>(
        0,
        (sum, row) => sum + LegacyPosMapper.money(row['total']),
      );
      final sales = await db.select(db.sales).get();
      expect(
        sales.fold<int>(0, (sum, sale) => sum + sale.totalCents),
        expectedTotal,
      );
      expect(
        counts['payment_records'],
        (input['mpesa_payments'] as List? ?? []).length +
            (input['paystack_payments'] as List? ?? []).length,
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        (await archive.mergeInto(db)).values.every((count) => count == 0),
        isTrue,
      );
      // Print counts only, never customer records, credentials or payment data.
      // ignore: avoid_print
      print('Read-only source check passed: $counts');
    } finally {
      await db.close();
    }
  }, skip: Platform.environment['NEXAPOS_LEGACY_CHECK'] != '1');
}
