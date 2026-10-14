import 'dart:async';
import 'dart:io';

import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const secureStorageFileName = 'flutter_secure_storage.dat';

/// flutter_secure_storage_windows keeps every secret (the database key, the
/// licence token, the platform credential, the automatic-backup key) in ONE
/// DPAPI-encrypted file, and deletes that file the moment it cannot be
/// decrypted or parsed (a torn write after a power cut, a profile glitch).
/// With the file gone, the next launch silently mints a new database key and
/// the existing encrypted database becomes unreadable. This keeps a second
/// copy next to it and puts it back when the primary goes missing or fails.
class SecureStorageFileGuard {
  SecureStorageFileGuard(Directory directory)
    : primary = File(p.join(directory.path, secureStorageFileName)),
      backup = File(p.join(directory.path, '$secureStorageFileName.bak')),
      _directory = directory;

  final File primary;
  final File backup;
  final Directory _directory;
  DateTime? _snapshotModified;
  int? _snapshotLength;

  /// Puts the backup back when the primary file does not exist (or is empty).
  Future<bool> restoreIfMissing() async {
    if (await primary.exists() && await primary.length() > 0) return false;
    return restoreFromBackup();
  }

  /// Replaces the primary with the last good backup. Whatever remains of the
  /// primary is kept aside as `.corrupt-<time>` (newest three) for diagnosis.
  Future<bool> restoreFromBackup() async {
    if (!await backup.exists() || await backup.length() == 0) return false;
    final bytes = await backup.readAsBytes();
    if (await primary.exists()) await _keepCorruptCopy();
    final temporary = File('${primary.path}.restoring');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(primary.path);
    _snapshotModified = null;
    return true;
  }

  /// Refreshes the backup from a primary that was just read or written
  /// successfully. A no-op when nothing changed since the last snapshot.
  Future<void> snapshot() async {
    if (!await primary.exists()) return;
    final length = await primary.length();
    if (length == 0) return;
    final modified = (await primary.stat()).modified;
    if (_snapshotModified == modified &&
        _snapshotLength == length &&
        await backup.exists()) {
      return;
    }
    final bytes = await primary.readAsBytes();
    final temporary = File('${backup.path}.writing');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(backup.path);
    _snapshotModified = modified;
    _snapshotLength = length;
  }

  Future<void> _keepCorruptCopy() async {
    try {
      final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
      await primary.copy(p.join(_directory.path, '$secureStorageFileName.corrupt-$stamp'));
      final kept = (await _directory.list().where((e) => e is File && p.basename(e.path).startsWith('$secureStorageFileName.corrupt-')).cast<File>().toList())
        ..sort((a, b) => b.path.compareTo(a.path));
      for (final old in kept.skip(3)) {
        await old.delete();
      }
    } on FileSystemException {
      // Diagnostics only - never let it block the restore.
    }
  }
}

/// Wraps whatever platform implementation the plugin registered so every
/// [FlutterSecureStorage] instance in the app goes through the guard.
class GuardedSecureStoragePlatform extends FlutterSecureStoragePlatform {
  GuardedSecureStoragePlatform(this._inner, this._guard);

  final FlutterSecureStoragePlatform _inner;
  final SecureStorageFileGuard _guard;
  Future<void> _tail = Future<void>.value();

  Future<T> _run<T>(Future<T> Function() operation) {
    final result = _tail.then((_) async {
      // Housekeeping on the backup must never break (or redo) a storage call.
      try {
        await _guard.restoreIfMissing();
      } on Object {
        // Fall through: the plugin call below reports the real problem.
      }
      T value;
      try {
        value = await operation();
      } on Object {
        // The plugin deletes a file it cannot read before it throws, so the
        // backup is the only copy left: restore it and try exactly once more.
        bool restored;
        try {
          restored = await _guard.restoreFromBackup();
        } on Object {
          restored = false;
        }
        if (!restored) rethrow;
        value = await operation();
      }
      try {
        await _guard.snapshot();
      } on Object {
        // Best effort only; the next successful call tries again.
      }
      return value;
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<void> write({required String key, required String value, required Map<String, String> options}) =>
      _run(() => _inner.write(key: key, value: value, options: options));

  @override
  Future<String?> read({required String key, required Map<String, String> options}) =>
      _run(() => _inner.read(key: key, options: options));

  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) =>
      _run(() => _inner.containsKey(key: key, options: options));

  @override
  Future<void> delete({required String key, required Map<String, String> options}) =>
      _run(() => _inner.delete(key: key, options: options));

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) =>
      _run(() => _inner.readAll(options: options));

  @override
  Future<void> deleteAll({required Map<String, String> options}) =>
      _run(() => _inner.deleteAll(options: options));
}

/// Call once at startup, before anything touches secure storage. Only Windows
/// uses the single-file store; elsewhere this does nothing.
Future<void> installSecureStorageGuard({Directory? directory, bool? windows}) async {
  if (!(windows ?? Platform.isWindows)) return;
  final guard = SecureStorageFileGuard(directory ?? await getApplicationSupportDirectory());
  FlutterSecureStoragePlatform.instance = GuardedSecureStoragePlatform(FlutterSecureStoragePlatform.instance, guard);
}
