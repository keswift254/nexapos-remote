// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_onboarding_gateway.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(platformOnboardingGateway)
final platformOnboardingGatewayProvider = PlatformOnboardingGatewayProvider._();

final class PlatformOnboardingGatewayProvider
    extends
        $FunctionalProvider<
          PlatformOnboardingGateway,
          PlatformOnboardingGateway,
          PlatformOnboardingGateway
        >
    with $Provider<PlatformOnboardingGateway> {
  PlatformOnboardingGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'platformOnboardingGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$platformOnboardingGatewayHash();

  @$internal
  @override
  $ProviderElement<PlatformOnboardingGateway> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PlatformOnboardingGateway create(Ref ref) {
    return platformOnboardingGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlatformOnboardingGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlatformOnboardingGateway>(value),
    );
  }
}

String _$platformOnboardingGatewayHash() =>
    r'33bdeb751d114d5d7fd9a58b6c4d20cbc5712fd7';
