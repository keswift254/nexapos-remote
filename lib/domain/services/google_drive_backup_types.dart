import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Platform-agnostic Drive backup contract + shared types, kept apart
/// from google_drive_backup_service_native.dart (which needs
/// googleapis_auth/auth_io.dart, google_sign_in, and dart:io HttpServer
/// - all native-only) so every caller - including automatic_backup_service.
/// dart's provider wiring and the Settings UI - can depend on just the
/// interface and compile for web. Selected concrete implementation is
/// chosen by google_drive_backup_service.dart's conditional import.
abstract class GoogleDriveBackupService {
  /// The connected account's email, or null if Drive isn't connected.
  Future<String?> connectedEmail();

  /// Runs the sign-in flow, requests the appdata scope, and uploads a
  /// passphrase-wrapped copy of the local backup key so a future device
  /// can recover it. Must be called from a user-initiated action.
  Future<String> connect({required String recoveryPassphrase});

  /// Revokes NexaPOS's Drive access and clears everything stored on
  /// this device. Files already uploaded stay in the merchant's own
  /// Drive - NexaPOS has no other way to reach them once disconnected.
  Future<void> disconnect();

  /// Uploads the most recent local backup to the hidden appdata folder,
  /// pruning older Drive copies down to the same retention window the
  /// local rotation already uses. A no-op if Drive isn't connected or
  /// there is no local backup yet - never blocks the local backup path.
  Future<void> uploadLatestBackupIfConnected();

  Future<List<GoogleDriveBackupSummary>> listBackups();

  Future<Uint8List> downloadBackup(String fileId);

  /// Downloads the key envelope and unwraps it with [recoveryPassphrase],
  /// returning the raw local backup key bytes to decrypt a downloaded
  /// backup with ArchiveEncryption.decode. Throws if the passphrase is
  /// wrong or no envelope was ever uploaded.
  Future<Uint8List> recoverBackupKey({required String recoveryPassphrase});
}

/// Thrown when a Drive operation needs a connected account and there isn't
/// one - distinguished from other failures so UI can prompt to connect
/// rather than showing a generic error.
class GoogleDriveNotConnectedException implements Exception {
  const GoogleDriveNotConnectedException();
}

/// One backup file already uploaded to the hidden app-data folder.
class GoogleDriveBackupSummary {
  const GoogleDriveBackupSummary({
    required this.fileId,
    required this.name,
    required this.modifiedAt,
    required this.sizeBytes,
  });

  final String fileId;
  final String name;
  final DateTime? modifiedAt;
  final int? sizeBytes;
}

/// Wraps/unwraps the local backup key under a merchant-chosen recovery
/// passphrase, independent of Drive/OAuth so it's directly testable and
/// reusable if key escrow is ever needed outside of Drive. Deliberately
/// mirrors ArchiveEncryption's exact KDF cost and cipher (see
/// data/import/shop_archive.dart) rather than inventing a second crypto
/// convention in the same codebase. Pure Dart (package:cryptography is
/// cross-platform) - fine to keep in this shared, web-compilable file.
class BackupKeyEnvelope {
  static const _pbkdf2Iterations = 210000;

  static Future<Uint8List> wrap(List<int> rawKey, String passphrase) async {
    final cipher = AesGcm.with256bits();
    final salt = cipher.newNonce();
    final wrappingKey = await _deriveWrappingKey(passphrase, salt);
    final box = await cipher.encrypt(
      rawKey,
      secretKey: wrappingKey,
      aad: utf8.encode('nexapos.drive.key-envelope.v1'),
    );
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'nexapos.drive.key-envelope',
          'version': 1,
          'salt': base64Encode(salt),
          'nonce': base64Encode(box.nonce),
          'mac': base64Encode(box.mac.bytes),
          'data': base64Encode(box.cipherText),
        }),
      ),
    );
  }

  static Future<Uint8List> unwrap(Uint8List envelopeBytes, String passphrase) async {
    final envelope = jsonDecode(utf8.decode(envelopeBytes)) as Map<String, dynamic>;
    if (envelope['format'] != 'nexapos.drive.key-envelope' || envelope['version'] != 1) {
      throw const FormatException('This does not look like a NexaPOS Drive backup key.');
    }
    final salt = base64Decode(envelope['salt'] as String);
    final nonce = base64Decode(envelope['nonce'] as String);
    final mac = base64Decode(envelope['mac'] as String);
    final wrappingKey = await _deriveWrappingKey(passphrase, salt);
    try {
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(base64Decode(envelope['data'] as String), nonce: nonce, mac: Mac(mac)),
        secretKey: wrappingKey,
        aad: utf8.encode('nexapos.drive.key-envelope.v1'),
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw StateError('That recovery passphrase is incorrect.');
    }
  }

  static Future<SecretKey> _deriveWrappingKey(String passphrase, List<int> salt) => Pbkdf2(
    macAlgorithm: Hmac.sha512(),
    iterations: _pbkdf2Iterations,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);
}
