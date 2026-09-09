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

  /// Returns the newly written backup file, or null if one wasn't due yet.
  /// Callers that mirror backups elsewhere (e.g. GoogleDriveBackupService)
  /// should only do so when this returns non-null, rather than on every
  /// call - runIfDue is checked far more often than it actually writes.
  Future<File?> runIfDue({bool force = false}) async {
    final now = DateTime.now().toUtc();
    final lastRaw = await _storage.read(key: _lastStorageKey);
    final last = lastRaw == null ? null : DateTime.tryParse(lastRaw);
    if (!force &&
        last != null &&
        now.difference(last) < automaticBackupInterval) {
      return null;
    }

    return _sync.exclusive(() async {
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
      return file;
    });
  }

  Future<String> _backupKey() => backupKey();

  /// The device's local backup encryption key, base64url-encoded. Exposed
  /// publicly so GoogleDriveBackupService can wrap this same key for
  /// off-device recovery instead of keeping a second copy of it anywhere.
  Future<String> backupKey() async {
    final existing = await _storage.read(key: _keyStorageKey);
    if (existing != null && existing.length >= 32) return existing;
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final key = base64UrlEncode(bytes);
    await _storage.write(key: _keyStorageKey, value: key);
    return key;
  }

  /// The most recently written local backup file, or null if none exists
  /// yet. Used by GoogleDriveBackupService to mirror the latest snapshot
  /// off-device without keeping a second notion of "where backups live".
  Future<File?> latestBackupFile() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory(p.join(root.path, 'backups'));
    if (!await directory.exists()) return null;
    final files =
        (await directory.list().where((e) => e is File).cast<File>().toList())
          ..sort((a, b) => b.path.compareTo(a.path));
    return files.isEmpty ? null : files.first;
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
