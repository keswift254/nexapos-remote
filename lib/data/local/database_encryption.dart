import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqlite3/sqlite3.dart';

const _encryptionKeyStorageKey = 'nexapos.db.encryptionKey';

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
Future<String> getOrCreateEncryptionKey(FlutterSecureStorage storage) async {
  final existing = await storage.read(key: _encryptionKeyStorageKey);
  if (existing != null && existing.isNotEmpty) return existing;

  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  final key = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  await storage.write(key: _encryptionKeyStorageKey, value: key);
  return key;
}

/// One-time upgrade path for a device that already has real data in a
/// plain (unencrypted) database from before this feature existed - a
/// fresh install never hits this, since [driftDatabase] simply creates
/// a new file that [_openAndKey]'s PRAGMA key makes encrypted from
/// its very first byte.
///
/// Detects "plain" by reading the file's own header rather than
/// tracking a separate flag: a real SQLite file always starts with the
/// literal bytes "SQLite format 3\0"; an encrypted one's header is
/// exactly as opaque as the rest of the file. Verified for real before
/// this was ever run against actual data - reproduced the exact
/// PRAGMA rekey operation below against a throwaway plain database,
/// confirmed the header changes, the original rows survive, and the
/// wrong key genuinely fails to read afterward (see
/// scripts/sqlcipher_test in this session's history for the standalone
/// proof, not committed to this repo).
///
/// Deliberately does nothing (not even throw) if the file doesn't
/// exist yet, or already looks non-plain - both are the common,
/// already-correct case on every run after the first.
Future<void> migrateToEncryptedIfNeeded(File dbFile, String key) async {
  if (!await dbFile.exists()) return;

  final raf = await dbFile.open();
  final header = await raf.read(16);
  await raf.close();
  final looksPlain = String.fromCharCodes(header).startsWith('SQLite format 3');
  if (!looksPlain) return;

  // Back up before touching anything real - a rekey that's interrupted
  // partway (power loss, the process being killed) must never be the
  // only copy of a shop's actual data. Left in place afterward rather
  // than deleted; harmless, and gives a real fallback if the rekey
  // result somehow fails its own verification below.
  final backup = File('${dbFile.path}.pre-encryption-backup');
  await dbFile.copy(backup.path);

  // No preceding `PRAGMA key = ''` - matches exactly what was verified
  // empirically to work (rekey alone, on a plain-opened connection),
  // not an untested variant of it.
  final db = sqlite3.open(dbFile.path);
  try {
    db.execute("PRAGMA rekey = '$key';");
  } finally {
    db.close();
  }

  // Don't just trust the rekey call returned without throwing - open it
  // back up with the real key and confirm it actually reads, the same
  // standard this project has held every other migration to.
  final verify = sqlite3.open(dbFile.path);
  try {
    verify.execute("PRAGMA key = '$key';");
    verify.select('SELECT count(*) FROM sqlite_master;');
  } finally {
    verify.close();
  }
}
