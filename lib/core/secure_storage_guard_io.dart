import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'windows_dpapi.dart';

const secureStorageFileName = 'flutter_secure_storage.dat';

/// How many copies set aside as unreadable are kept (the newest ones). On 2026-11-25 the shop's real key survived
/// only in such copies - three of them, exactly the old limit - so the limit is generous now, and the newest copy that
/// still holds every protected key is never deleted whatever its age (see [SecureStorageFileGuard]).
const keptUnreadableCopies = 10;

/// Reads the entries of one secure-storage file's bytes; null when it cannot (another Windows user, a torn write).
typedef SecureStoreDecoder = Map<String, String>? Function(Uint8List bytes);

/// flutter_secure_storage_windows keeps every secret (the database key, the
/// licence token, the platform credential, the automatic-backup key) in ONE
/// DPAPI-encrypted file, and deletes that file the moment it cannot be
/// decrypted or parsed (a torn write after a power cut, a profile glitch).
/// With the file gone, the next launch silently mints a new database key and
/// the existing encrypted database becomes unreadable. This keeps a second
/// copy next to it and puts it back when the primary goes missing or fails.
///
/// [protectedKeys] (the database key) get one more rule, from 2026-11-25, when three copies of NexaPOS running at once
/// on one PC left the file holding a single licence entry and the backup was then refreshed from it: a file WITHOUT a
/// protected key never replaces a backup WITH it. [decode] is how the guard looks inside a file to tell; without it
/// (no way to look) every file counts as holding the keys, which is how the guard behaved before.
class SecureStorageFileGuard {
  SecureStorageFileGuard(Directory directory, {this.protectedKeys = const [], this.decode})
    : primary = File(p.join(directory.path, secureStorageFileName)),
      backup = File(p.join(directory.path, '$secureStorageFileName.bak')),
      _directory = directory;

  final File primary;
  final File backup;
  final List<String> protectedKeys;
  final SecureStoreDecoder? decode;
  final Directory _directory;
  DateTime? _snapshotModified;
  int? _snapshotLength;

  /// The entries of [file], or null when it is missing or cannot be read.
  Future<Map<String, String>?> entriesOf(File file) async {
    final reader = decode;
    if (reader == null || !await file.exists()) return null;
    try {
      return reader(await file.readAsBytes());
    } on Object {
      return null;
    }
  }

  /// Whether [file] holds every protected key (true when there is nothing to protect or no way to look).
  Future<bool> holdsProtectedKeys(File file) async {
    if (protectedKeys.isEmpty || decode == null) return true;
    final entries = await entriesOf(file);
    return entries != null && protectedKeys.every((key) => (entries[key] ?? '').isNotEmpty);
  }

  /// Puts the backup back when the primary file does not exist (or is empty).
  Future<bool> restoreIfMissing() async {
    if (await primary.exists() && await primary.length() > 0) return false;
    return restoreFromBackup();
  }

  /// Replaces the primary with the last good backup. Whatever remains of the
  /// primary is kept aside as `.corrupt-<time>` for diagnosis (and, as
  /// 2026-11-25 showed, sometimes for recovery).
  Future<bool> restoreFromBackup() async {
    if (!await backup.exists() || await backup.length() == 0) return false;
    final bytes = await backup.readAsBytes();
    if (await primary.exists()) await _keepCorruptCopy();
    await _writeAtomically(primary, bytes);
    _snapshotModified = null;
    return true;
  }

  /// Refreshes the backup from a primary that was just read or written
  /// successfully. A no-op when nothing changed since the last snapshot.
  ///
  /// Returns false - and leaves the backup alone - when the primary has lost a protected key that the backup still
  /// holds: the primary was emptied behind this process's back, and the backup is then the only good copy.
  /// [allowLosingProtected] is for a call that removed the key on purpose: the backup then follows.
  Future<bool> snapshot({bool allowLosingProtected = false}) async {
    if (!await primary.exists()) return true;
    final length = await primary.length();
    if (length == 0) return true;
    final modified = (await primary.stat()).modified;
    if (_snapshotModified == modified &&
        _snapshotLength == length &&
        await backup.exists()) {
      return true;
    }
    if (!allowLosingProtected &&
        await backup.exists() &&
        !await holdsProtectedKeys(primary) &&
        await holdsProtectedKeys(backup)) {
      return false;
    }
    final bytes = await primary.readAsBytes();
    await _writeAtomically(backup, bytes);
    _snapshotModified = modified;
    _snapshotLength = length;
    return true;
  }

  /// Every copy that may still hold the secrets, best first: the backup, then the copies set aside as unreadable,
  /// newest first.
  Future<List<File>> savedCopies() async {
    final copies = <File>[];
    if (await backup.exists() && await backup.length() > 0) copies.add(backup);
    copies.addAll(await _unreadableCopies());
    return copies;
  }

  /// The first of [savedCopies] whose entries [accept] takes, or null.
  Future<File?> findCopy(bool Function(Map<String, String> entries) accept) async {
    for (final copy in await savedCopies()) {
      final entries = await entriesOf(copy);
      if (entries != null && accept(entries)) return copy;
    }
    return null;
  }

  /// Makes [copy] the store again - and its backup - keeping the store it replaces aside as an unreadable copy.
  /// Returns the entries of the replaced store (null when it had none or could not be read), so the caller can write
  /// back the ones that are newer than [copy].
  Future<Map<String, String>?> installCopy(File copy) async {
    final bytes = await copy.readAsBytes();
    Map<String, String>? replaced;
    if (await primary.exists() && await primary.length() > 0) {
      replaced = await entriesOf(primary);
      await _keepCorruptCopy();
    }
    await _writeAtomically(primary, bytes);
    await _writeAtomically(backup, bytes);
    _snapshotModified = null;
    return replaced;
  }

  Future<List<File>> _unreadableCopies() async {
    if (!await _directory.exists()) return [];
    final copies = await _directory
        .list()
        .where((entry) => entry is File && p.basename(entry.path).startsWith('$secureStorageFileName.corrupt-'))
        .cast<File>()
        .toList();
    int stamp(File file) => int.tryParse(p.basename(file.path).substring('$secureStorageFileName.corrupt-'.length)) ?? 0;
    copies.sort((a, b) => stamp(b).compareTo(stamp(a)));
    return copies;
  }

  Future<void> _writeAtomically(File target, List<int> bytes) async {
    final temporary = File('${target.path}${identical(target, backup) ? '.writing' : '.restoring'}');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(target.path);
  }

  Future<void> _keepCorruptCopy() async {
    try {
      final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
      var name = p.join(_directory.path, '$secureStorageFileName.corrupt-$stamp');
      // two in the same millisecond must not overwrite each other
      for (var n = stamp + 1; await File(name).exists(); n++) {
        name = p.join(_directory.path, '$secureStorageFileName.corrupt-$n');
      }
      await primary.copy(name);
      final kept = await _unreadableCopies();
      if (kept.length <= keptUnreadableCopies) return;
      // The newest copy that still holds every protected key is kept whatever its age: it may be the last place the
      // database key exists.
      File? lastWithKeys;
      if (protectedKeys.isNotEmpty && decode != null) {
        for (final copy in kept) {
          if (await holdsProtectedKeys(copy)) {
            lastWithKeys = copy;
            break;
          }
        }
      }
      for (final old in kept.skip(keptUnreadableCopies)) {
        if (old.path == lastWithKeys?.path) continue;
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

  /// [removesProtected]: the call itself removes a protected key on purpose (deleteAll, or deleting that key), so the
  /// store is allowed to lose it - never put back what was deleted on purpose.
  Future<T> _run<T>(Future<T> Function() operation, {bool removesProtected = false}) {
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
      bool kept;
      try {
        kept = await _guard.snapshot(allowLosingProtected: removesProtected);
      } on Object {
        // Best effort only; the next successful call tries again.
        kept = true;
      }
      if (!kept) {
        // The store lost the database key between two calls (another NexaPOS on this PC emptied it, 2026-11-25) while
        // the backup still holds it: put the backup back and do this call again on it, once.
        bool restored;
        try {
          restored = await _guard.restoreFromBackup();
        } on Object {
          restored = false;
        }
        if (restored) {
          value = await operation();
          try {
            await _guard.snapshot();
          } on Object {
            // Best effort, as above.
          }
        }
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
      _run(() => _inner.delete(key: key, options: options), removesProtected: _guard.protectedKeys.contains(key));

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) =>
      _run(() => _inner.readAll(options: options));

  @override
  Future<void> deleteAll({required Map<String, String> options}) =>
      _run(() => _inner.deleteAll(options: options), removesProtected: true);
}

/// The guard [installSecureStorageGuard] put in place (Windows), for the start-up check to look in its saved copies.
SecureStorageFileGuard? installedSecureStorageGuard;

/// Call once at startup, before anything touches secure storage. Only Windows
/// uses the single-file store; elsewhere this does nothing. [protectedKeys]
/// are the entries a backup must never lose (the database key).
Future<void> installSecureStorageGuard({
  Directory? directory,
  bool? windows,
  List<String> protectedKeys = const [],
  SecureStoreDecoder? decode,
}) async {
  if (!(windows ?? Platform.isWindows)) return;
  final guard = SecureStorageFileGuard(
    directory ?? await getApplicationSupportDirectory(),
    protectedKeys: protectedKeys,
    decode: decode ?? decodeWindowsSecureStore,
  );
  installedSecureStorageGuard = guard;
  FlutterSecureStoragePlatform.instance = GuardedSecureStoragePlatform(FlutterSecureStoragePlatform.instance, guard);
}
