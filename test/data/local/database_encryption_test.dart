import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:nexapos_mobile/data/local/database_encryption.dart';

import '../../support/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installFakeSecureStorage);

  group('getOrCreateEncryptionKey', () {
    test('generates a real, non-trivial key and persists it across calls', () async {
      const storage = FlutterSecureStorage();
      final first = await getOrCreateEncryptionKey(storage);

      expect(first, isNotEmpty);
      expect(first.length, greaterThanOrEqualTo(32), reason: 'should be real entropy, not a short placeholder');

      final second = await getOrCreateEncryptionKey(storage);
      expect(second, first, reason: 'must not silently regenerate and orphan already-encrypted data');
    });

    test('two devices (two storages) get different keys', () async {
      const storageA = FlutterSecureStorage();
      final keyA = await getOrCreateEncryptionKey(storageA);

      // installFakeSecureStorage's backing map is shared per test via
      // the mocked channel, so simulate a distinct device by clearing
      // it before the second call rather than needing a second fake.
      await storageA.deleteAll();
      final keyB = await getOrCreateEncryptionKey(storageA);

      expect(keyA, isNot(keyB));
    });
  });

  group('migrateToEncryptedIfNeeded', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nexapos_encryption_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('does nothing when no database file exists yet (fresh install)', () async {
      final dbFile = File('${tempDir.path}/nexapos.sqlite');
      await migrateToEncryptedIfNeeded(dbFile, 'some-key');
      expect(await dbFile.exists(), isFalse);
    });

    test('rekeys a real plain database in place, preserving its data', () async {
      final dbFile = File('${tempDir.path}/nexapos.sqlite');

      // A real plain (unencrypted) database, exactly like every
      // pre-encryption install already has on disk.
      final plain = sqlite3.open(dbFile.path);
      plain.execute('CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT)');
      plain.execute("INSERT INTO products (name) VALUES ('Real Product')");
      plain.close();

      final headerBefore = await dbFile.openRead(0, 16).first;
      expect(String.fromCharCodes(headerBefore), startsWith('SQLite format 3'), reason: 'sanity check on the test setup itself');

      const key = 'a-real-32-byte-hex-style-test-key';
      await migrateToEncryptedIfNeeded(dbFile, key);

      final headerAfter = await dbFile.openRead(0, 16).first;
      expect(String.fromCharCodes(headerAfter), isNot(startsWith('SQLite format 3')), reason: 'file should no longer look like plain SQLite');

      // The actual point: real data survives, readable with the real key.
      final reopened = sqlite3.open(dbFile.path);
      reopened.execute("PRAGMA key = '$key';");
      final rows = reopened.select('SELECT name FROM products');
      reopened.close();
      expect(rows.single['name'], 'Real Product');

      // And the wrong key must NOT be able to read it.
      final wrongKeyAttempt = sqlite3.open(dbFile.path);
      wrongKeyAttempt.execute("PRAGMA key = 'totally-wrong-key';");
      expect(() => wrongKeyAttempt.select('SELECT name FROM products'), throwsA(isA<SqliteException>()));
      wrongKeyAttempt.close();
    });

    test('is a no-op on a database that is already encrypted (idempotent across every app launch)', () async {
      final dbFile = File('${tempDir.path}/nexapos.sqlite');
      const key = 'already-encrypted-key';

      final plain = sqlite3.open(dbFile.path);
      plain.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, val TEXT)');
      plain.execute("INSERT INTO t (val) VALUES ('original')");
      plain.close();
      await migrateToEncryptedIfNeeded(dbFile, key);

      // Second call, same already-encrypted file - must not attempt a
      // second rekey (which would need the CURRENT key, not silently
      // succeed) or otherwise disturb it.
      await migrateToEncryptedIfNeeded(dbFile, key);

      final reopened = sqlite3.open(dbFile.path);
      reopened.execute("PRAGMA key = '$key';");
      final rows = reopened.select('SELECT val FROM t');
      reopened.close();
      expect(rows.single['val'], 'original');
    });
  });
}
