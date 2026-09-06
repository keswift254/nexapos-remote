import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/providers.dart';
import '../../data/import/shop_archive.dart';
import '../../data/local/database.dart';
import 'sync_service.dart';

const automaticBackupInterval = Duration(hours: 6);
const automaticBackupRetention = 7;

final automaticBackupServiceProvider = Provider<AutomaticBackupService>(
  (ref) => AutomaticBackupService(
    ref.watch(appDatabaseProvider),
    ref.watch(secureStorageProvider),
    ref.watch(syncServiceProvider),
  ),
);

/// Creates encrypted local recovery snapshots without interrupting checkout
/// or sync. The key never enters the archive or a command line; it stays in
/// the platform secure store, so a copied backup is not a plaintext database.
class AutomaticBackupService {
  static const _keyStorageKey = 'nexapos.automaticBackup.key';
  static const _lastStorageKey = 'nexapos.automaticBackup.lastAt';

  final AppDatabase _db;
  final FlutterSecureStorage _storage;
  final SyncService _sync;

  AutomaticBackupService(this._db, this._storage, this._sync);

  Future<void> runIfDue({bool force = false}) async {
    final now = DateTime.now().toUtc();
    final lastRaw = await _storage.read(key: _lastStorageKey);
    final last = lastRaw == null ? null : DateTime.tryParse(lastRaw);
    if (!force &&
        last != null &&
        now.difference(last) < automaticBackupInterval) {
      return;
    }

    await _sync.exclusive(() async {
      final archive = await ShopArchive.capture(_db);
      await archive.validate();
      final encrypted = await ArchiveEncryption.encode(
        archive,
        await _backupKey(),
      );
      final root = await getApplicationSupportDirectory();
      final directory = Directory(p.join(root.path, 'backups'));
      await directory.create(recursive: true);
      final file = File(
        p.join(
          directory.path,
          'NexaPOS-auto-${now.millisecondsSinceEpoch}.nexabackup',
        ),
      );
      await file.writeAsBytes(encrypted, flush: true);
      await _rotate(directory);
      await _storage.write(key: _lastStorageKey, value: now.toIso8601String());
    });
  }

  Future<String> _backupKey() async {
    final existing = await _storage.read(key: _keyStorageKey);
    if (existing != null && existing.length >= 32) return existing;
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final key = base64UrlEncode(bytes);
    await _storage.write(key: _keyStorageKey, value: key);
    return key;
  }

  Future<void> _rotate(Directory directory) async {
    final files =
        (await directory.list().where((e) => e is File).cast<File>().toList())
          ..sort((a, b) => b.path.compareTo(a.path));
    for (final file in files.skip(automaticBackupRetention)) {
      try {
        await file.delete();
      } on FileSystemException {
        // A locked snapshot is harmless; the next rotation can remove it.
      }
    }
  }
}
