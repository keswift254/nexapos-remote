import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _encryptionKeyStorageKey = 'nexapos.db.encryptionKey';

/// An encrypted database is already on disk but its key is nowhere to be
/// found. Minting a fresh key here would silently orphan that database for
/// good, so the caller must stop and let a person decide.
class DatabaseKeyMissingException implements Exception {
  const DatabaseKeyMissingException();

  @override
  String toString() =>
      'The database encryption key is missing while an encrypted database '
      'file exists. Refusing to create a new key.';
}

/// The passphrase every local database connection is opened with (via
/// `PRAGMA key`) - generated once per install, on this device only,
/// and kept in the OS's secure credential store rather than anywhere
/// the database file itself could reveal it. 256 bits from
/// [Random.secure] (a real CSPRNG, not [Random]'s default
/// non-cryptographic generator), hex-encoded since PRAGMA key takes a
/// string. Independent of every other secret this app generates
/// (registrationSecret, api keys, license token) - losing this one
/// only affects this device's own copy of its own data, not sync or
/// licensing.
///
/// [allowCreate] must be false whenever an encrypted database file already
/// exists: a missing key then means the key was LOST (a damaged secure-storage
/// file, a reset keystore), and a brand-new key can never open that file.
/// Throws [DatabaseKeyMissingException] in that case instead of creating one.
///
/// Split out of database_encryption.dart (which also has
/// migrateToEncryptedIfNeeded, native-FFI-sqlite3-only) since this
/// function itself has no native dependency and both
/// database_connection_native.dart and database_connection_web.dart
/// need it.
Future<String> getOrCreateEncryptionKey(
  FlutterSecureStorage storage, {
  bool allowCreate = true,
}) async {
  final existing = await storage.read(key: _encryptionKeyStorageKey);
  if (existing != null && existing.isNotEmpty) return existing;
  if (!allowCreate) throw const DatabaseKeyMissingException();

  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  final key = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  await storage.write(key: _encryptionKeyStorageKey, value: key);
  return key;
}

/// The stored key, or null when there is none. Never creates one.
Future<String?> readEncryptionKey(FlutterSecureStorage storage) async {
  final existing = await storage.read(key: _encryptionKeyStorageKey);
  return existing == null || existing.isEmpty ? null : existing;
}
