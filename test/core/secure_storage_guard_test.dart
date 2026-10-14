import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/secure_storage_guard_io.dart';
import 'package:path/path.dart' as p;

/// Behaves like flutter_secure_storage_windows: one file holding every
/// secret, and - the part that destroyed a shop's data - the file is DELETED
/// the moment it cannot be parsed, before the error is rethrown.
class PluginLikePlatform extends FlutterSecureStoragePlatform {
  PluginLikePlatform(this.file);

  final File file;
  int reads = 0;

  Map<String, String> _load() {
    if (!file.existsSync()) return {};
    try {
      final decoded = jsonDecode(file.readAsStringSync()) as Map;
      return decoded.map((key, value) => MapEntry(key as String, value as String));
    } on Object {
      file.deleteSync();
      rethrow;
    }
  }

  void _save(Map<String, String> data) => file.writeAsStringSync(jsonEncode(data), flush: true);

  @override
  Future<String?> read({required String key, required Map<String, String> options}) async {
    reads++;
    return _load()[key];
  }

  @override
  Future<void> write({required String key, required String value, required Map<String, String> options}) async =>
      _save({..._load(), key: value});

  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) async =>
      _load().containsKey(key);

  @override
  Future<void> delete({required String key, required Map<String, String> options}) async =>
      _save(_load()..remove(key));

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async => _load();

  @override
  Future<void> deleteAll({required Map<String, String> options}) async => _save({});
}

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

  test('a corrupt leftover is kept aside for diagnosis, newest three only', () async {
    await seedKey();
    for (var i = 0; i < 5; i++) {
      await guard.primary.writeAsString('broken $i');
      await guard.restoreFromBackup();
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final kept = dir.listSync().where((e) => p.basename(e.path).contains('.corrupt-')).toList();
    expect(kept.length, 3);
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
