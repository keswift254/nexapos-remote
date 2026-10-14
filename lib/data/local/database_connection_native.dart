import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database_encryption.dart';
import 'database_encryption_key.dart';

/// Same 'nexapos.sqlite' file/location driftDatabase() has always used
/// (getApplicationDocumentsDirectory() + '$name.sqlite') - real devices
/// already have a file there, so this can't switch to a different name/
/// path without every existing install looking like it lost its data.
/// Wrapped in the same DatabaseConnection.delayed pattern driftDatabase()
/// itself uses internally, so resolving the encryption key and (if
/// needed) migrating an existing plain file happen before the
/// connection driftDatabase() hands back is ever touched - by the time
/// any query runs, the file on disk and the PRAGMA key native.setup
/// applies are already guaranteed to match.
///
/// Split out of database.dart (which must stay platform-agnostic so it
/// can compile for web) because this file's own imports - dart:io,
/// path_provider's filesystem APIs, and (via database_encryption.dart)
/// the native FFI sqlite3 package - only exist on native platforms.
/// database.dart picks this file or database_connection_web.dart via a
/// conditional import keyed on dart.library.js_interop.
DatabaseConnection openConnection() {
  return DatabaseConnection.delayed(
    Future(() async {
      const storage = FlutterSecureStorage();
      final dir = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dir.path, 'nexapos.sqlite'));
      final key = await keyForDatabaseFile(storage, dbFile);
      await migrateToEncryptedIfNeeded(dbFile, key);

      return driftDatabase(
        name: 'nexapos',
        native: DriftNativeOptions(
          setup: (db) => db.execute("PRAGMA key = '$key';"),
        ),
      );
    }),
  );
}

/// The key [dbFile] must be opened with. A key may only be CREATED when no
/// encrypted database exists for it to open: a missing key beside an encrypted
/// file means the key was lost, and a new one would silently orphan that data
/// for good - so this throws [DatabaseKeyMissingException] instead.
Future<String> keyForDatabaseFile(FlutterSecureStorage storage, File dbFile) async =>
    getOrCreateEncryptionKey(storage, allowCreate: !await databaseFileIsEncrypted(dbFile));
