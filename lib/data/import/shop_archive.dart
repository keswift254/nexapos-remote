import 'dart:convert';
import 'dart:isolate';
import 'dart:io';

import 'package:crypto/crypto.dart' as hashes;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../local/database.dart';
import '../local/sync_metadata.dart';

const archiveTables = [
  'roles',
  'users',
  'categories',
  'products',
  'sales',
  'sale_items',
  'expenses',
  'stock_movements',
  'payment_records',
  'business_settings',
];
const maxArchiveBytes = 256 * 1024 * 1024;

class ShopArchive {
  final Map<String, List<Map<String, dynamic>>> tables;
  final String source;
  final List<String> notes;
  final Map<String, String> images;
  ShopArchive(
    this.tables, {
    required this.source,
    this.notes = const [],
    this.images = const {},
  });

  Map<String, dynamic> toJson() => {
    'format': 'nexapos.shop',
    'version': 1,
    'source': source,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'tables': tables,
    'notes': notes,
    'images': images,
  };

  factory ShopArchive.fromJson(Map<String, dynamic> json) {
    if (json['format'] != 'nexapos.shop' ||
        json['version'] != 1 ||
        json['tables'] is! Map) {
      throw const FormatException('Unsupported backup format or version.');
    }
    final raw = Map<String, dynamic>.from(json['tables'] as Map);
    if (raw.keys.any((t) => !archiveTables.contains(t)) ||
        archiveTables.any((t) => raw[t] is! List)) {
      throw const FormatException('Backup has missing or unsupported tables.');
    }
    return ShopArchive(
      {
        for (final t in archiveTables)
          t: (raw[t] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList(),
      },
      source: json['source'] as String,
      notes: (json['notes'] as List? ?? []).cast<String>(),
      images: Map<String, String>.from(json['images'] as Map? ?? {}),
    );
  }

  static Future<ShopArchive> capture(AppDatabase db) => db.transaction(
    () async {
      final tables = <String, List<Map<String, dynamic>>>{};
      final images = <String, String>{};
      for (final table in archiveTables) {
        tables[table] = (await db.customSelect('SELECT * FROM "$table"').get())
            .map((r) => Map<String, dynamic>.from(r.data))
            .toList();
      }
      var imageBytes = 0;
      for (final row in tables['products']!) {
        final path = row['image_path'] as String?;
        if (path == null || path.isEmpty) continue;
        final file = File(path);
        if (!await file.exists()) continue;
        imageBytes += await file.length();
        if (imageBytes > 32 * 1024 * 1024) {
          throw StateError('Product images exceed the 32 MiB backup limit.');
        }
        images[row['id'] as String] = base64Encode(await file.readAsBytes());
      }
      return ShopArchive(
        tables,
        source: 'device:${await SyncMetadataService(db).deviceId()}',
        images: images,
      );
    },
  );

  Future<ShopArchive> validate() async {
    var imageBytes = 0;
    final products = tables['products']!.map((r) => r['id']).toSet();
    for (final entry in images.entries) {
      imageBytes += base64Decode(entry.value).length;
      if (!products.contains(entry.key) || imageBytes > 32 * 1024 * 1024) {
        throw const FormatException('Invalid backup images.');
      }
    }
    final scratch = AppDatabase(NativeDatabase.memory());
    try {
      await scratch.customSelect('SELECT 1').get();
      await scratch.transaction(() async {
        await scratch.customStatement('PRAGMA defer_foreign_keys=ON');
        for (final t in archiveTables.reversed) {
          await scratch.customStatement('DELETE FROM "$t"');
        }
        for (final t in archiveTables) {
          final columns =
              (await scratch.customSelect('PRAGMA table_info("$t")').get())
                  .map((r) => r.data['name'] as String)
                  .toSet();
          final ids = <String>{};
          for (final row in tables[t]!) {
            if (row.keys.any((k) => !columns.contains(k)) ||
                row['id'] is! String ||
                !ids.add(row['id'] as String)) {
              throw FormatException('Invalid columns or duplicate IDs in $t.');
            }
            for (final entry in row.entries) {
              if ((entry.key.endsWith('_cents') ||
                      [
                        'quantity',
                        'stock_qty',
                        'reorder_level',
                        'local_rev',
                      ].contains(entry.key)) &&
                  entry.value is! int) {
                throw FormatException('Invalid integer in $t.${entry.key}.');
              }
            }
            if (DateTime.tryParse(row['created_at'] as String? ?? '') == null ||
                DateTime.tryParse(row['updated_at'] as String? ?? '') == null) {
              throw FormatException('Invalid timestamp in $t.');
            }
            await insertRow(scratch, t, row);
          }
        }
        final broken = await scratch
            .customSelect('PRAGMA foreign_key_check')
            .get();
        if (broken.isNotEmpty) {
          throw const FormatException(
            'Backup contains missing related records.',
          );
        }
        final stock = await scratch.customSelect('''SELECT p.id FROM products p
          WHERE p.stock_qty != (SELECT COALESCE(SUM(m.quantity),0) FROM stock_movements m
          WHERE m.product_id=p.id AND m.deleted_at IS NULL)''').get();
        if (stock.isNotEmpty) {
          throw const FormatException(
            'Inventory totals do not match stock history.',
          );
        }
      });
      final normalized = <String, List<Map<String, dynamic>>>{};
      for (final table in archiveTables) {
        normalized[table] =
            (await scratch.customSelect('SELECT * FROM "$table"').get())
                .map((row) => Map<String, dynamic>.from(row.data))
                .toList();
      }
      return ShopArchive(
        normalized,
        source: source,
        notes: notes,
        images: images,
      );
    } finally {
      await scratch.close();
    }
  }

  /// Restores missing records only. Existing business rows are never overwritten.
  Future<Map<String, int>> mergeInto(
    AppDatabase db, {
    Directory? imageDirectory,
  }) async {
    final normalized = await validate();
    final meta = SyncMetadataService(db);
    final device = await meta.deviceId();
    final counts = <String, int>{};
    final restoredImages = <String, String>{};
    if (images.isNotEmpty) {
      final dir =
          imageDirectory ??
          Directory(
            p.join(
              (await getApplicationSupportDirectory()).path,
              'restored-images',
            ),
          );
      await dir.create(recursive: true);
      for (final entry in images.entries) {
        final bytes = base64Decode(entry.value);
        final file = File(
          p.join(dir.path, '${hashes.sha256.convert(bytes)}.image'),
        );
        if (!await file.exists()) await file.writeAsBytes(bytes, flush: true);
        restoredImages[entry.key] = file.path;
      }
    }
    await db.transaction(() async {
      await db.customStatement('PRAGMA defer_foreign_keys=ON');
      final emptyShop =
          (await db
                  .customSelect(
                    'SELECT '
                    '(SELECT COUNT(*) FROM products) + (SELECT COUNT(*) FROM sales) + '
                    '(SELECT COUNT(*) FROM expenses) + (SELECT COUNT(*) FROM categories) AS n',
                  )
                  .getSingle())
              .read<int>('n') ==
          0;
      for (final t in archiveTables) {
        counts[t] = 0;
        for (final original in normalized.tables[t]!) {
          var found = await db
              .customSelect(
                'SELECT * FROM "$t" WHERE id = ?',
                variables: [Variable<String>(original['id'] as String)],
              )
              .getSingleOrNull();
          if (found != null &&
              t == 'business_settings' &&
              emptyShop &&
              found.data['business_name'] == 'My Business' &&
              found.data['address'] == null &&
              found.data['phone'] == null &&
              found.data['receipt_footer'] == null &&
              found.data['currency'] == 'KES' &&
              found.data['paper_width_mm'] == 58) {
            await db.customStatement(
              'DELETE FROM business_settings WHERE id=?',
              [original['id']],
            );
            found = null;
          }
          if (found != null) {
            if (t == 'roles') continue;
            final comparable = Map<String, dynamic>.from(found.data);
            final incoming = Map<String, dynamic>.from(original);
            for (final key in [
              'local_rev',
              'created_by_device_id',
              'updated_at',
              'image_path',
            ]) {
              comparable.remove(key);
              incoming.remove(key);
            }
            if (t == 'business_settings') {
              comparable.remove('created_at');
              incoming.remove('created_at');
            }
            if (jsonEncode(comparable) != jsonEncode(incoming)) {
              // Compare maps without relying on JSON property order.
              if (comparable.length != incoming.length ||
                  comparable.keys.any(
                    (key) => comparable[key] != incoming[key],
                  )) {
                throw StateError(
                  'Conflicting record in $t. Restore into an empty shop instead.',
                );
              }
            }
            continue;
          }
          if (t == 'users') {
            final duplicate = await db
                .customSelect(
                  'SELECT id FROM users WHERE lower(username)=lower(?)',
                  variables: [Variable<String>(original['username'] as String)],
                )
                .get();
            if (duplicate.isNotEmpty) {
              throw StateError('An imported username already exists.');
            }
          }
          final uniqueField = t == 'products'
              ? 'sku'
              : t == 'sales'
              ? 'sale_number'
              : null;
          if (uniqueField != null) {
            final duplicates = await db
                .customSelect(
                  'SELECT id FROM "$t" WHERE "$uniqueField"=?',
                  variables: [
                    Variable<String>(original[uniqueField] as String),
                  ],
                )
                .get();
            if (duplicates.isNotEmpty) {
              throw StateError(
                'An existing $uniqueField conflicts with the import.',
              );
            }
          }
          final row = Map<String, dynamic>.from(original)
            ..['local_rev'] = await meta.nextLocalRev()
            ..['created_by_device_id'] = device;
          if (t == 'products') row['image_path'] = restoredImages[row['id']];
          await insertRow(db, t, row);
          counts[t] = counts[t]! + 1;
        }
      }
      if ((await db.customSelect('PRAGMA foreign_key_check').get())
          .isNotEmpty) {
        throw StateError('Import would leave missing related records.');
      }
      await db.customStatement('''UPDATE products SET stock_qty =
        (SELECT COALESCE(SUM(quantity),0) FROM stock_movements
        WHERE product_id=products.id AND deleted_at IS NULL)''');
    });
    db.notifyUpdates({
      for (final table in db.allTables) TableUpdate(table.actualTableName),
    });
    return counts;
  }
}

Future<void> insertRow(
  AppDatabase db,
  String table,
  Map<String, dynamic> row,
) async {
  // Callers validate table/column names against the local schema first.
  final columns = row.keys.map((k) => '"$k"').join(',');
  final placeholders = List.filled(row.length, '?').join(',');
  await db.customStatement(
    'INSERT INTO "$table" ($columns) VALUES ($placeholders)',
    row.values.toList(),
  );
}

class ArchiveEncryption {
  static const minimumPasswordLength = 8;

  static Future<Uint8List> encode(ShopArchive archive, String password) async {
    if (password.length < minimumPasswordLength) {
      throw ArgumentError(
        'Backup password must contain at least $minimumPasswordLength characters.',
      );
    }
    final json = archive.toJson();
    return Isolate.run(() async {
      final plaintext = utf8.encode(jsonEncode(json));
      if (plaintext.length > maxArchiveBytes ~/ 2) {
        throw StateError('Backup exceeds the supported size.');
      }
      final cipher = AesGcm.with256bits();
      final salt = cipher.newNonce();
      final key = await _derive(password, salt);
      final box = await cipher.encrypt(
        plaintext,
        secretKey: key,
        aad: utf8.encode('nexapos.encrypted.v1'),
      );
      return Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'format': 'nexapos.encrypted',
            'version': 1,
            'salt': base64Encode(salt),
            'nonce': base64Encode(box.nonce),
            'mac': base64Encode(box.mac.bytes),
            'data': base64Encode(box.cipherText),
          }),
        ),
      );
    });
  }

  static Future<ShopArchive> decode(Uint8List bytes, String password) async {
    if (bytes.length > maxArchiveBytes) {
      throw const FormatException('Backup exceeds the supported size.');
    }
    final result = await Isolate.run(() async {
      final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (envelope['format'] != 'nexapos.encrypted' ||
          envelope['version'] != 1) {
        throw const FormatException('Choose a NexaPOS encrypted backup.');
      }
      final salt = base64Decode(envelope['salt'] as String);
      final nonce = base64Decode(envelope['nonce'] as String);
      final mac = base64Decode(envelope['mac'] as String);
      if (salt.length != 12 || nonce.length != 12 || mac.length != 16) {
        throw const FormatException('Invalid backup encryption header.');
      }
      final key = await _derive(password, salt);
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(
          base64Decode(envelope['data'] as String),
          nonce: nonce,
          mac: Mac(mac),
        ),
        secretKey: key,
        aad: utf8.encode('nexapos.encrypted.v1'),
      );
      return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    });
    final archive = ShopArchive.fromJson(result);
    await archive.validate();
    return archive;
  }

  static Future<SecretKey> _derive(String password, List<int> salt) => Pbkdf2(
    macAlgorithm: Hmac.sha512(),
    iterations: 210000,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
}
