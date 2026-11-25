import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/secure_storage_guard_io.dart';
import 'database_encryption.dart';
import 'database_encryption_key.dart';
import 'database_startup_problem.dart';

const databaseFileName = 'nexapos.sqlite';

/// Decides, before the app starts, whether it is safe to open the database.
///
/// Returns a problem when an encrypted database file exists but its key is
/// missing, unreadable, or does not open it. Starting normally in that state
/// would mint a new key (or a new empty database) beside data that may still be
/// recoverable, which is exactly how a lost key used to destroy a shop's data
/// without any message. Returns null when it is safe to start.
Future<DatabaseStartupProblem?> checkDatabaseStartup({
  FlutterSecureStorage storage = const FlutterSecureStorage(),
  Directory? documents,
  SecureStorageFileGuard? guard,
}) async {
  final directory = documents ?? await getApplicationDocumentsDirectory();
  final dbFile = File(p.join(directory.path, databaseFileName));
  if (!await databaseFileIsEncrypted(dbFile)) return null;

  // Windows: look inside the store file itself first. When its key does not open this data file, the key may still be
  // in a copy the guard kept - its backup, or a copy it set aside as unreadable (on 2026-11-25 the shop's real key was
  // in three such copies while the store had been emptied). This runs BEFORE the key is read the normal way, because a
  // normal read refreshes the backup from the store and could overwrite the one good copy.
  final keeper = guard ?? installedSecureStorageGuard;
  if (keeper != null && !await _storeKeyOpens(keeper, dbFile)) {
    await recoverDatabaseKeyFromSavedCopies(keeper, storage, dbFile);
  }
  return _keyProblem(storage, dbFile);
}

/// Whether the key in the guard's store file opens [dbFile], read straight from the file (no backup refresh).
Future<bool> _storeKeyOpens(SecureStorageFileGuard guard, File dbFile) async {
  final key = (await guard.entriesOf(guard.primary))?[databaseEncryptionKeyName];
  return key != null && key.isNotEmpty && checkDatabaseOpens(dbFile, key) == DatabaseOpenResult.opens;
}

Future<DatabaseStartupProblem?> _keyProblem(FlutterSecureStorage storage, File dbFile) async {
  String? key;
  try {
    key = await readEncryptionKey(storage);
  } on Object {
    key = null;
  }
  if (key == null) {
    return DatabaseStartupProblem(DatabaseProblemKind.keyMissing, dbFile.path);
  }
  if (checkDatabaseOpens(dbFile, key) == DatabaseOpenResult.notADatabase) {
    return DatabaseStartupProblem(DatabaseProblemKind.keyDoesNotOpen, dbFile.path);
  }
  return null;
}

/// Looks through the copies [guard] kept for a database key that really opens [dbFile] (newest first) and makes that
/// copy the store again. Entries of the store it replaces - written after the loss, so the newest - are written back on
/// top, except the database key itself. Returns whether a copy was put back. Nothing is deleted: the replaced store is
/// kept aside as one more copy.
Future<bool> recoverDatabaseKeyFromSavedCopies(
  SecureStorageFileGuard guard,
  FlutterSecureStorage storage,
  File dbFile,
) async {
  try {
    final copy = await guard.findCopy((entries) {
      final key = entries[databaseEncryptionKeyName];
      return key != null && key.isNotEmpty && checkDatabaseOpens(dbFile, key) == DatabaseOpenResult.opens;
    });
    if (copy == null) return false;
    final replaced = await guard.installCopy(copy);
    for (final entry in (replaced ?? const <String, String>{}).entries) {
      if (entry.key == databaseEncryptionKeyName) continue;
      await storage.write(key: entry.key, value: entry.value);
    }
    return true;
  } on Object {
    // A recovery attempt must never stop the person from seeing the recovery screen.
    return false;
  }
}

/// Moves the database files into a dated `NexaPOS-held-...` folder beside them
/// and returns that folder's path. Nothing is deleted: if the key is ever found
/// the files can be put back.
Future<String> setAsideDatabaseFiles(String databasePath, {DateTime? now}) async {
  final moment = (now ?? DateTime.now()).toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  final stamp =
      '${moment.year}${two(moment.month)}${two(moment.day)}-${two(moment.hour)}${two(moment.minute)}${two(moment.second)}';
  final folder = Directory(p.join(File(databasePath).parent.path, 'NexaPOS-held-$stamp'));
  await folder.create(recursive: true);
  for (final suffix in const ['', '-wal', '-shm', '.pre-encryption-backup']) {
    final source = File('$databasePath$suffix');
    if (!await source.exists()) continue;
    final target = File(p.join(folder.path, p.basename(source.path)));
    try {
      await source.rename(target.path);
    } on FileSystemException {
      final length = await source.length();
      await source.copy(target.path);
      if (await target.length() != length) {
        throw FileSystemException('The copy of ${source.path} is incomplete; the original was left in place.');
      }
      await source.delete();
    }
  }
  return folder.path;
}
