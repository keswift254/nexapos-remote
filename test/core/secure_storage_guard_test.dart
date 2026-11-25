import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/secure_storage_guard_io.dart';
import 'package:path/path.dart' as p;

import '../support/plugin_like_secure_storage.dart';

void main() {
  late Directory dir;
  late SecureStorageFileGuard guard;
  late PluginLikePlatform inner;
  late GuardedSecureStoragePlatform platform;
  const options = <String, String>{};

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nexapos_guard_test_');
    guard = SecureStorageFileGuard(dir);
    inner = PluginLikePlatform(guard.primary);
    platform = GuardedSecureStoragePlatform(inner, guard);
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<void> seedKey() => platform.write(key: 'nexapos.db.encryptionKey', value: 'KEY-1', options: options);

  test('a write is mirrored to the backup file byte for byte', () async {
    await seedKey();
    expect(await guard.backup.exists(), isTrue);
    expect(await guard.backup.readAsBytes(), await guard.primary.readAsBytes());
  });

  test('a torn file (power cut mid-write) is healed from the backup instead of losing the key', () async {
    await seedKey();
    // Power cut: the primary is cut off in the middle of its JSON.
    final bytes = await guard.primary.readAsBytes();
    await guard.primary.writeAsBytes(bytes.sublist(0, bytes.length ~/ 2));

    final key = await platform.read(key: 'nexapos.db.encryptionKey', options: options);

    expect(key, 'KEY-1', reason: 'the plugin deleted the torn file; the backup must have been restored and re-read');
    expect(await guard.primary.exists(), isTrue);
  });

  test('a primary that vanished is restored before it is read', () async {
    await seedKey();
    await guard.primary.delete();

    expect(await platform.read(key: 'nexapos.db.encryptionKey', options: options), 'KEY-1');
    expect(await guard.primary.exists(), isTrue);
  });

  test('without any backup a broken file still fails loudly - nothing is invented', () async {
    await guard.primary.writeAsString('{ not json');
    await expectLater(platform.read(key: 'nexapos.db.encryptionKey', options: options), throwsA(anything));
    expect(await guard.backup.exists(), isFalse);
  });

  test('a write after the primary vanished merges into the restored data and keeps the old keys', () async {
    await seedKey();
    await platform.write(key: 'nexapos.platform.apiKey', value: 'API-1', options: options);
    await guard.primary.delete();

    // This is the moment a fresh install would mint a NEW database key.
    await platform.write(key: 'nexapos.session.userId', value: 'u1', options: options);

    final all = await platform.readAll(options: options);
    expect(all['nexapos.db.encryptionKey'], 'KEY-1');
    expect(all['nexapos.platform.apiKey'], 'API-1');
    expect(all['nexapos.session.userId'], 'u1');
    final backedUp = jsonDecode(await guard.backup.readAsString()) as Map;
    expect(backedUp['nexapos.db.encryptionKey'], 'KEY-1', reason: 'the backup must not be overwritten with a near-empty file');
  });

  test('a failure while refreshing the backup never breaks (or undoes) a storage call', () async {
    // A directory squatting on the temp name makes every snapshot fail.
    await Directory('${guard.backup.path}.writing').create();

    await seedKey();
    await platform.write(key: 'other', value: 'v', options: options);

    expect(await platform.read(key: 'nexapos.db.encryptionKey', options: options), 'KEY-1');
    expect(await platform.read(key: 'other', options: options), 'v');
  });

  test('a failure while restoring is not hidden behind a different error', () async {
    await seedKey();
    final bytes = await guard.primary.readAsBytes();
    await guard.primary.writeAsBytes(bytes.sublist(0, 3));
    // Make the restore itself fail: its temp name is occupied by a directory.
    await Directory('${guard.primary.path}.restoring').create();

    await expectLater(
      platform.read(key: 'nexapos.db.encryptionKey', options: options),
      throwsA(isA<FormatException>()),
      reason: 'the original parse failure must surface, not the restore failure',
    );
  });

  test('concurrent calls are serialised and the final state is consistent', () async {
    await Future.wait([
      for (var i = 0; i < 25; i++) platform.write(key: 'k$i', value: 'v$i', options: options),
      for (var i = 0; i < 25; i++) platform.read(key: 'k$i', options: options),
    ]);
    final all = await platform.readAll(options: options);
    expect(all.length, 25);
    final backedUp = jsonDecode(await guard.backup.readAsString()) as Map;
    expect(backedUp.length, 25);
  });

  test('an intentional deleteAll is respected (the backup follows it)', () async {
    await seedKey();
    await platform.deleteAll(options: options);
    expect(await platform.readAll(options: options), isEmpty);
    expect(jsonDecode(await guard.backup.readAsString()), isEmpty);
  });

  test('unchanged files are not copied again on every read', () async {
    await seedKey();
    final before = (await guard.backup.stat()).modified;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    for (var i = 0; i < 5; i++) {
      await platform.read(key: 'nexapos.db.encryptionKey', options: options);
    }
    expect((await guard.backup.stat()).modified, before);
  });

  test('a corrupt leftover is kept aside for diagnosis, newest ten only', () async {
    await seedKey();
    for (var i = 0; i < 12; i++) {
      await guard.primary.writeAsString('broken $i');
      await guard.restoreFromBackup();
    }
    final kept = dir.listSync().where((e) => p.basename(e.path).contains('.corrupt-')).toList();
    expect(kept.length, keptUnreadableCopies);
    expect(keptUnreadableCopies, 10);
  });

  // 2026-11-25: three copies of NexaPOS ran at once on the owner's PC. Between two calls of one copy, another emptied
  // the store to a single licence entry; the next write saved that tiny store and the backup was refreshed from it, so
  // the database key survived only in copies set aside as unreadable. The database key is now protected.
  group('the database key is protected', () {
    const dbKey = 'nexapos.db.encryptionKey';
    late SecureStorageFileGuard keyGuard;
    late GuardedSecureStoragePlatform keyPlatform;

    setUp(() {
      keyGuard = SecureStorageFileGuard(dir, protectedKeys: const [dbKey], decode: decodePlainStore);
      keyPlatform = GuardedSecureStoragePlatform(PluginLikePlatform(keyGuard.primary), keyGuard);
    });

    Map<String, String> entries(File file) => decodePlainStore(file.readAsBytesSync())!;

    /// What another NexaPOS on the same PC did: the store is replaced by one holding only a licence date.
    Future<void> anotherCopyEmptiesTheStore() async {
      writePlainStore(keyGuard.primary, {'nexapos.license.validUntil': 'old'});
      await keyGuard.primary.setLastModified(DateTime.now().add(const Duration(seconds: 5)));
    }

    test('the 2026-11-25 sequence: the next write keeps the key, and the backup is never replaced by the empty store',
        () async {
      await keyPlatform.write(key: dbKey, value: 'KEY-1', options: options);
      await keyPlatform.write(key: 'nexapos.platform.apiKey', value: 'API-1', options: options);
      await anotherCopyEmptiesTheStore();

      await keyPlatform.write(key: 'nexapos.license.validUntil', value: 'new', options: options);

      final store = entries(keyGuard.primary);
      expect(store[dbKey], 'KEY-1', reason: 'the store was put back from the backup and the write done again on it');
      expect(store['nexapos.platform.apiKey'], 'API-1');
      expect(store['nexapos.license.validUntil'], 'new', reason: 'the write itself is not lost');
      expect(entries(keyGuard.backup)[dbKey], 'KEY-1', reason: 'the backup still holds the key');
      final setAside = dir.listSync().where((e) => p.basename(e.path).contains('.corrupt-')).toList();
      expect(setAside, hasLength(1), reason: 'the emptied store is kept aside, not thrown away');
    });

    test('a read after another copy emptied the store returns the real key', () async {
      await keyPlatform.write(key: dbKey, value: 'KEY-1', options: options);
      await anotherCopyEmptiesTheStore();
      expect(await keyPlatform.read(key: dbKey, options: options), 'KEY-1');
      expect(entries(keyGuard.backup)[dbKey], 'KEY-1');
    });

    test('a new install with no key yet is still backed up, and so is the key once it exists', () async {
      await keyPlatform.write(key: 'nexapos.license.validUntil', value: 'x', options: options);
      expect(entries(keyGuard.backup), {'nexapos.license.validUntil': 'x'});
      await keyPlatform.write(key: dbKey, value: 'KEY-1', options: options);
      expect(entries(keyGuard.backup)[dbKey], 'KEY-1');
    });

    test('a store that keeps its key refreshes the backup as before', () async {
      await keyPlatform.write(key: dbKey, value: 'KEY-1', options: options);
      await keyPlatform.write(key: 'nexapos.session.userId', value: 'u1', options: options);
      expect(entries(keyGuard.backup)['nexapos.session.userId'], 'u1');
    });

    test('deleting everything, or the key itself, on purpose is respected - never put back', () async {
      await keyPlatform.write(key: dbKey, value: 'KEY-1', options: options);
      await keyPlatform.delete(key: dbKey, options: options);
      expect(await keyPlatform.read(key: dbKey, options: options), isNull);
      expect(entries(keyGuard.backup).containsKey(dbKey), isFalse);

      await keyPlatform.write(key: dbKey, value: 'KEY-2', options: options);
      await keyPlatform.deleteAll(options: options);
      expect(await keyPlatform.readAll(options: options), isEmpty);
      expect(entries(keyGuard.backup), isEmpty);
    });

    test('set-aside copies: the newest ten are kept, and the newest one still holding the key survives however old',
        () async {
      await keyPlatform.write(key: dbKey, value: 'KEY-1', options: options);
      final name = p.join(dir.path, '$secureStorageFileName.corrupt-');
      writePlainStore(File('${name}1000'), {dbKey: 'KEY-OLD'});
      for (var i = 0; i < 11; i++) {
        File('$name${2000 + i}').writeAsStringSync('unreadable $i');
      }

      await keyGuard.primary.writeAsString('torn');
      await keyGuard.restoreFromBackup();

      final kept = dir.listSync().map((e) => p.basename(e.path)).where((n) => n.contains('.corrupt-')).toList();
      expect(kept, contains('$secureStorageFileName.corrupt-1000'), reason: 'the only set-aside copy with a key');
      expect(kept, hasLength(keptUnreadableCopies + 1));
    });

    test('findCopy looks in the backup first, then the set-aside copies newest first; installCopy puts one back',
        () async {
      writePlainStore(keyGuard.backup, {'nexapos.license.validUntil': 'b'});
      final name = p.join(dir.path, '$secureStorageFileName.corrupt-');
      writePlainStore(File('${name}100'), {dbKey: 'KEY-A'});
      writePlainStore(File('${name}200'), {dbKey: 'KEY-B', 'nexapos.platform.apiKey': 'API'});
      writePlainStore(keyGuard.primary, {'nexapos.license.validUntil': 'newest'});

      final found = await keyGuard.findCopy((e) => (e[dbKey] ?? '').isNotEmpty);
      expect(p.basename(found!.path), '$secureStorageFileName.corrupt-200');

      final replaced = await keyGuard.installCopy(found);
      expect(replaced, {'nexapos.license.validUntil': 'newest'});
      expect(entries(keyGuard.primary)[dbKey], 'KEY-B');
      expect(entries(keyGuard.backup)[dbKey], 'KEY-B');
      expect(dir.listSync().where((e) => p.basename(e.path).contains('.corrupt-')), hasLength(3),
          reason: 'the replaced store is kept aside too');
    });

    test('a store that cannot be looked into counts as holding the key (the old behaviour)', () async {
      final blind = SecureStorageFileGuard(dir, protectedKeys: const [dbKey]);
      expect(await blind.holdsProtectedKeys(blind.primary), isTrue);
    });
  });

  group('installSecureStorageGuard', () {
    final original = FlutterSecureStoragePlatform.instance;
    tearDown(() => FlutterSecureStoragePlatform.instance = original);

    test('does nothing off Windows', () async {
      await installSecureStorageGuard(directory: dir, windows: false);
      expect(FlutterSecureStoragePlatform.instance, same(original));
    });

    test('wraps the registered implementation on Windows', () async {
      await installSecureStorageGuard(directory: dir, windows: true);
      expect(FlutterSecureStoragePlatform.instance, isA<GuardedSecureStoragePlatform>());
    });
  });
}
