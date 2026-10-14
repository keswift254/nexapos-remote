import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
}) async {
  final directory = documents ?? await getApplicationDocumentsDirectory();
  final dbFile = File(p.join(directory.path, databaseFileName));
  if (!await databaseFileIsEncrypted(dbFile)) return null;

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
