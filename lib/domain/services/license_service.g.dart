// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'license_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether a cached, still-valid activation exists on this device - the
/// single source of truth app.dart's redirect guard checks, mirroring
/// how hasAnyUsersProvider backs the setup-wizard gate: a plain
/// autodispose FutureProvider re-read fresh on every redirect call
/// rather than cached reactive state, so there's no restore-timing race
/// to get wrong on cold start. Delegates to LicenseService so the same
/// "is the cached license still within its valid_until window" check
/// backs both this and the periodic offline re-check in
/// LicenseService.backgroundVerify.

@ProviderFor(hasCachedLicense)
final hasCachedLicenseProvider = HasCachedLicenseProvider._();

/// Whether a cached, still-valid activation exists on this device - the
/// single source of truth app.dart's redirect guard checks, mirroring
/// how hasAnyUsersProvider backs the setup-wizard gate: a plain
/// autodispose FutureProvider re-read fresh on every redirect call
/// rather than cached reactive state, so there's no restore-timing race
/// to get wrong on cold start. Delegates to LicenseService so the same
/// "is the cached license still within its valid_until window" check
/// backs both this and the periodic offline re-check in
/// LicenseService.backgroundVerify.

final class HasCachedLicenseProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether a cached, still-valid activation exists on this device - the
  /// single source of truth app.dart's redirect guard checks, mirroring
  /// how hasAnyUsersProvider backs the setup-wizard gate: a plain
  /// autodispose FutureProvider re-read fresh on every redirect call
  /// rather than cached reactive state, so there's no restore-timing race
  /// to get wrong on cold start. Delegates to LicenseService so the same
  /// "is the cached license still within its valid_until window" check
  /// backs both this and the periodic offline re-check in
  /// LicenseService.backgroundVerify.
  HasCachedLicenseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hasCachedLicenseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hasCachedLicenseHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return hasCachedLicense(ref);
  }
}

String _$hasCachedLicenseHash() => r'578079816d98081a1697b100e4f8c5fc93041a67';

/// Purely a ping for _RouterRefreshNotifier to listen to - the int
/// itself carries no meaning beyond "something changed, re-run
/// redirect", which then re-reads hasCachedLicenseProvider fresh. Same
/// two-provider split sessionProvider/hasAnyUsersProvider use together
/// for the setup/login gate.

@ProviderFor(LicenseChangeSignal)
final licenseChangeSignalProvider = LicenseChangeSignalProvider._();

/// Purely a ping for _RouterRefreshNotifier to listen to - the int
/// itself carries no meaning beyond "something changed, re-run
/// redirect", which then re-reads hasCachedLicenseProvider fresh. Same
/// two-provider split sessionProvider/hasAnyUsersProvider use together
/// for the setup/login gate.
final class LicenseChangeSignalProvider
    extends $NotifierProvider<LicenseChangeSignal, int> {
  /// Purely a ping for _RouterRefreshNotifier to listen to - the int
  /// itself carries no meaning beyond "something changed, re-run
  /// redirect", which then re-reads hasCachedLicenseProvider fresh. Same
  /// two-provider split sessionProvider/hasAnyUsersProvider use together
  /// for the setup/login gate.
  LicenseChangeSignalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'licenseChangeSignalProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$licenseChangeSignalHash();

  @$internal
  @override
  LicenseChangeSignal create() => LicenseChangeSignal();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$licenseChangeSignalHash() =>
    r'50984fc44efab3c4b49401d1237fb70ee4bc678c';

/// Purely a ping for _RouterRefreshNotifier to listen to - the int
/// itself carries no meaning beyond "something changed, re-run
/// redirect", which then re-reads hasCachedLicenseProvider fresh. Same
/// two-provider split sessionProvider/hasAnyUsersProvider use together
/// for the setup/login gate.

abstract class _$LicenseChangeSignal extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(licenseGateway)
final licenseGatewayProvider = LicenseGatewayProvider._();

final class LicenseGatewayProvider
    extends $FunctionalProvider<LicenseGateway, LicenseGateway, LicenseGateway>
    with $Provider<LicenseGateway> {
  LicenseGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'licenseGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$licenseGatewayHash();

  @$internal
  @override
  $ProviderElement<LicenseGateway> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LicenseGateway create(Ref ref) {
    return licenseGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LicenseGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LicenseGateway>(value),
    );
  }
}

String _$licenseGatewayHash() => r'0b33ed54d7b15fd7a2030d35fc639988921f9b1c';

@ProviderFor(licenseService)
final licenseServiceProvider = LicenseServiceProvider._();

final class LicenseServiceProvider
    extends $FunctionalProvider<LicenseService, LicenseService, LicenseService>
    with $Provider<LicenseService> {
  LicenseServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'licenseServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$licenseServiceHash();

  @$internal
  @override
  $ProviderElement<LicenseService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LicenseService create(Ref ref) {
    return licenseService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LicenseService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LicenseService>(value),
    );
  }
}

String _$licenseServiceHash() => r'd0c0c7400f7fedd7eed553a9bb36b2383b0e3e62';
