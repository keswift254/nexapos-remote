import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'automatic_backup_service.dart';
import 'google_drive_backup_types.dart';

/// Selected instead of google_drive_backup_service_native.dart when
/// compiling for web - Google Drive backup isn't offered there yet (no
/// clear equivalent for a short-lived browser session with no
/// persistent local database to back up in the first place). connectedEmail()
/// returning null rather than throwing matters: app.dart's background sync
/// cycle calls uploadLatestBackupIfConnected() unconditionally on every
/// platform, and that method already no-ops when connectedEmail() is null -
/// so this stub needs no special-casing there, it just naturally never
/// connects.
GoogleDriveBackupService createGoogleDriveBackupService(
  AutomaticBackupService localBackup,
  FlutterSecureStorage storage,
) => _UnsupportedGoogleDriveBackupService();

class _UnsupportedGoogleDriveBackupService implements GoogleDriveBackupService {
  static const _message = 'Google Drive backup is not available in the browser version yet.';

  @override
  Future<String?> connectedEmail() async => null;

  @override
  Future<void> uploadLatestBackupIfConnected() async {}

  @override
  Future<String> connect({required String recoveryPassphrase}) =>
      throw UnsupportedError(_message);

  @override
  Future<void> disconnect() => throw UnsupportedError(_message);

  @override
  Future<List<GoogleDriveBackupSummary>> listBackups() =>
      throw UnsupportedError(_message);

  @override
  Future<Uint8List> downloadBackup(String fileId) =>
      throw UnsupportedError(_message);

  @override
  Future<Uint8List> recoverBackupKey({required String recoveryPassphrase}) =>
      throw UnsupportedError(_message);
}
