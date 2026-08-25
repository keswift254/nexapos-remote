// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_sync_gateway.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(platformSyncGateway)
final platformSyncGatewayProvider = PlatformSyncGatewayProvider._();

final class PlatformSyncGatewayProvider
    extends
        $FunctionalProvider<
          PlatformSyncGateway,
          PlatformSyncGateway,
          PlatformSyncGateway
        >
    with $Provider<PlatformSyncGateway> {
  PlatformSyncGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'platformSyncGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$platformSyncGatewayHash();

  @$internal
  @override
  $ProviderElement<PlatformSyncGateway> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PlatformSyncGateway create(Ref ref) {
    return platformSyncGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlatformSyncGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlatformSyncGateway>(value),
    );
  }
}

String _$platformSyncGatewayHash() =>
    r'cfd365e5e1009ada021c729c1a618c526cee382b';
