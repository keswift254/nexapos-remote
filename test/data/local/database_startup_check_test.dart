import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/data/local/database_encryption.dart';
import 'package:nexapos_mobile/data/local/database_connection_native.dart';
import 'package:nexapos_mobile/data/local/database_encryption_key.dart';
import 'package:nexapos_mobile/data/local/database_startup_check_io.dart';
import 'package:nexapos_mobile/data/local/database_startup_problem.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../support/fake_secure_storage.dart';

class _UnreadableStorage extends FlutterSecureStoragePlatform {
  @override
  Future<String?> read({required String key, required Map<String, String> options}) async =>
      throw StateError('secure storage unreadable');
  @override
  Future<void> write({required String key, required String value, required Map<String, String> options}) async {}
  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) async => false;
  @override
  Future<void> delete({required String key, required Map<String, String> options}) async {}
  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async => {};
  @override
  Future<void> deleteAll({required Map<String, String> options}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  const storage = FlutterSecureStorage();
  const keyName = 'nexapos.db.encryptionKey';
  const goodKey = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

  setUp(() async {
    installFakeSecureStorage();
    dir = await Directory.systemTemp.createTemp('nexapos_startup_check_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  File encryptedDb(String key) {
    final file = File(p.join(dir.path, 'nexapos.sqlite'));
    final db = sqlite3.open(file.path);
    db.execute("PRAGMA key = '$key';");
    db.execute('CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT)');
    db.execute("INSERT INTO products (name) VALUES ('Sugar 1kg')");
    db.close();
    return file;
  }

  group('getOrCreateEncryptionKey(allowCreate: false)', () {
    test('refuses to mint a key and writes nothing', () async {
      await expectLater(
        getOrCreateEncryptionKey(storage, allowCreate: false),
        throwsA(isA<DatabaseKeyMissingException>()),
      );
      expect(await storage.read(key: keyName), isNull);
    });

    test('still returns a key that exists', () async {
      await storage.write(key: keyName, value: goodKey);
      expect(await getOrCreateEncryptionKey(storage, allowCreate: false), goodKey);
    });

    test('mints one by default for a brand-new install', () async {
      final key = await getOrCreateEncryptionKey(storage);
      expect(key, hasLength(64));
      expect(await readEncryptionKey(storage), key);
    });
  });

  group('keyForDatabaseFile (what openConnection() uses)', () {
    test('an encrypted database with no key: throws, never mints a replacement', () async {
      final file = encryptedDb(goodKey);
      await expectLater(keyForDatabaseFile(storage, file), throwsA(isA<DatabaseKeyMissingException>()));
      expect(await storage.read(key: keyName), isNull, reason: 'a new key must not have been written');
    });

    test('an encrypted database with its key: returns that key', () async {
      final file = encryptedDb(goodKey);
      await storage.write(key: keyName, value: goodKey);
      expect(await keyForDatabaseFile(storage, file), goodKey);
    });

    test('no database file yet: creates the key (fresh install)', () async {
      final file = File(p.join(dir.path, 'nexapos.sqlite'));
      expect(await keyForDatabaseFile(storage, file), hasLength(64));
    });

    test('a plain legacy database: creates the key so it can be migrated', () async {
      final file = File(p.join(dir.path, 'nexapos.sqlite'));
      final plain = sqlite3.open(file.path);
      plain.execute('CREATE TABLE t (id INTEGER)');
      plain.close();
      expect(await keyForDatabaseFile(storage, file), hasLength(64));
    });
  });

  group('databaseFileIsEncrypted', () {
    test('false for missing, empty, tiny and plain files; true for an encrypted one', () async {
      final file = File(p.join(dir.path, 'nexapos.sqlite'));
      expect(await databaseFileIsEncrypted(file), isFalse, reason: 'missing');
      await file.writeAsBytes(const []);
      expect(await databaseFileIsEncrypted(file), isFalse, reason: 'empty');
      await file.writeAsBytes(List.filled(8, 7));
      expect(await databaseFileIsEncrypted(file), isFalse, reason: 'tiny');
      await file.delete();
      final plain = sqlite3.open(file.path);
      plain.execute('CREATE TABLE t (id INTEGER)');
      plain.close();
      expect(await databaseFileIsEncrypted(file), isFalse, reason: 'plain legacy file - the migration handles it');
      await file.delete();
      encryptedDb(goodKey);
      expect(await databaseFileIsEncrypted(file), isTrue);
    });
  });

  group('checkDatabaseStartup', () {
    test('no database yet (fresh install): safe to start', () async {
      expect(await checkDatabaseStartup(storage: storage, documents: dir), isNull);
    });

    test('encrypted database and its own key: safe to start', () async {
      encryptedDb(goodKey);
      await storage.write(key: keyName, value: goodKey);
      expect(await checkDatabaseStartup(storage: storage, documents: dir), isNull);
    });

    test('encrypted database but NO key: stops instead of letting the app mint one', () async {
      final file = encryptedDb(goodKey);
      final problem = await checkDatabaseStartup(storage: storage, documents: dir);
      expect(problem, isNotNull);
      expect(problem!.kind, DatabaseProblemKind.keyMissing);
      expect(problem.databasePath, file.path);
    });

    test('encrypted database and a DIFFERENT key (the state a lost key leaves behind)', () async {
      encryptedDb(goodKey);
      await storage.write(key: keyName, value: 'ff' * 32);
      final problem = await checkDatabaseStartup(storage: storage, documents: dir);
      expect(problem?.kind, DatabaseProblemKind.keyDoesNotOpen);
    });

    test('secure storage that throws is treated as a missing key, not as permission to start', () async {
      encryptedDb(goodKey);
      final original = FlutterSecureStoragePlatform.instance;
      FlutterSecureStoragePlatform.instance = _UnreadableStorage();
      addTearDown(() => FlutterSecureStoragePlatform.instance = original);
      final problem = await checkDatabaseStartup(storage: const FlutterSecureStorage(), documents: dir);
      expect(problem?.kind, DatabaseProblemKind.keyMissing);
    });

    test('checking never changes the database file', () async {
      final file = encryptedDb(goodKey);
      await storage.write(key: keyName, value: 'ee' * 32);
      final before = await file.readAsBytes();
      await checkDatabaseStartup(storage: storage, documents: dir);
      expect(await file.readAsBytes(), before);
    });
  });

  group('setAsideDatabaseFiles', () {
    test('moves every database file into a dated folder and deletes nothing', () async {
      final file = encryptedDb(goodKey);
      await File('${file.path}-wal').writeAsString('wal bytes');
      await File('${file.path}-shm').writeAsString('shm bytes');
      final original = await file.readAsBytes();

      final folder = await setAsideDatabaseFiles(file.path, now: DateTime.utc(2026, 10, 15, 1, 2, 3));

      expect(p.basename(folder), 'NexaPOS-held-20261015-010203');
      expect(await file.exists(), isFalse);
      expect(await File('${file.path}-wal').exists(), isFalse);
      expect(await File('${file.path}-shm').exists(), isFalse);
      expect(await File(p.join(folder, 'nexapos.sqlite')).readAsBytes(), original);
      expect(await File(p.join(folder, 'nexapos.sqlite-wal')).readAsString(), 'wal bytes');
      expect(await File(p.join(folder, 'nexapos.sqlite-shm')).readAsString(), 'shm bytes');
    });

    test('after setting aside, a new key may be created and the app can start fresh', () async {
      final file = encryptedDb(goodKey);
      await setAsideDatabaseFiles(file.path);
      expect(await databaseFileIsEncrypted(file), isFalse);
      final key = await getOrCreateEncryptionKey(storage, allowCreate: !await databaseFileIsEncrypted(file));
      expect(key, hasLength(64));
    });
  });
}
