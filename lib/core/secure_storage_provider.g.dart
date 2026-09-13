// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'secure_storage_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Split out of providers.dart so that files needing only the plain,
/// platform-agnostic providers there (appDatabase, syncMetadata, clock,
/// idGenerator - all of which compile for web) don't transitively pull
/// in flutter_secure_storage, which is Flutter-only (imports the real
/// Flutter framework, not just a plugin interface). This was blocking
/// the drift-web spike test from running via plain `dart test`, since
/// every repository imported providers.dart just for appDatabaseProvider
/// and got flutter_secure_storage along for the ride.

@ProviderFor(secureStorage)
final secureStorageProvider = SecureStorageProvider._();

/// Split out of providers.dart so that files needing only the plain,
/// platform-agnostic providers there (appDatabase, syncMetadata, clock,
/// idGenerator - all of which compile for web) don't transitively pull
/// in flutter_secure_storage, which is Flutter-only (imports the real
/// Flutter framework, not just a plugin interface). This was blocking
/// the drift-web spike test from running via plain `dart test`, since
/// every repository imported providers.dart just for appDatabaseProvider
/// and got flutter_secure_storage along for the ride.

final class SecureStorageProvider
    extends
        $FunctionalProvider<
          FlutterSecureStorage,
          FlutterSecureStorage,
          FlutterSecureStorage
        >
    with $Provider<FlutterSecureStorage> {
  /// Split out of providers.dart so that files needing only the plain,
  /// platform-agnostic providers there (appDatabase, syncMetadata, clock,
  /// idGenerator - all of which compile for web) don't transitively pull
  /// in flutter_secure_storage, which is Flutter-only (imports the real
  /// Flutter framework, not just a plugin interface). This was blocking
  /// the drift-web spike test from running via plain `dart test`, since
  /// every repository imported providers.dart just for appDatabaseProvider
  /// and got flutter_secure_storage along for the ride.
  SecureStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secureStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secureStorageHash();

  @$internal
  @override
  $ProviderElement<FlutterSecureStorage> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FlutterSecureStorage create(Ref ref) {
    return secureStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FlutterSecureStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FlutterSecureStorage>(value),
    );
  }
}

String _$secureStorageHash() => r'0cd1b80f91784467390034386f925a0be155bfbd';
