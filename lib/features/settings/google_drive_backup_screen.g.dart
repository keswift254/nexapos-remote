// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_drive_backup_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(connectedGoogleDriveEmail)
final connectedGoogleDriveEmailProvider = ConnectedGoogleDriveEmailProvider._();

final class ConnectedGoogleDriveEmailProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  ConnectedGoogleDriveEmailProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectedGoogleDriveEmailProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectedGoogleDriveEmailHash();

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    return connectedGoogleDriveEmail(ref);
  }
}

String _$connectedGoogleDriveEmailHash() =>
    r'f2b3d0e53bd180704ee5bbd865c84ce992905122';

@ProviderFor(googleDriveBackups)
final googleDriveBackupsProvider = GoogleDriveBackupsProvider._();

final class GoogleDriveBackupsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<GoogleDriveBackupSummary>>,
          List<GoogleDriveBackupSummary>,
          FutureOr<List<GoogleDriveBackupSummary>>
        >
    with
        $FutureModifier<List<GoogleDriveBackupSummary>>,
        $FutureProvider<List<GoogleDriveBackupSummary>> {
  GoogleDriveBackupsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'googleDriveBackupsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$googleDriveBackupsHash();

  @$internal
  @override
  $FutureProviderElement<List<GoogleDriveBackupSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<GoogleDriveBackupSummary>> create(Ref ref) {
    return googleDriveBackups(ref);
  }
}

String _$googleDriveBackupsHash() =>
    r'9b56de322270f84f1be5b79a32ba491ef19bf5f5';
