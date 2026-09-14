import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/secure_storage_provider.dart';
import 'automatic_backup_service.dart';
export 'google_drive_backup_types.dart';
import 'google_drive_backup_service_native.dart'
    if (dart.library.js_interop) 'google_drive_backup_service_stub.dart'
    as drive_service;
import 'google_drive_backup_types.dart';

final googleDriveBackupServiceProvider = Provider<GoogleDriveBackupService>(
  (ref) => drive_service.createGoogleDriveBackupService(
    ref.watch(automaticBackupServiceProvider),
    ref.watch(secureStorageProvider),
  ),
);
