// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(updateGateway)
final updateGatewayProvider = UpdateGatewayProvider._();

final class UpdateGatewayProvider
    extends $FunctionalProvider<UpdateGateway, UpdateGateway, UpdateGateway>
    with $Provider<UpdateGateway> {
  UpdateGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateGatewayHash();

  @$internal
  @override
  $ProviderElement<UpdateGateway> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UpdateGateway create(Ref ref) {
    return updateGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateGateway>(value),
    );
  }
}

String _$updateGatewayHash() => r'bd2ade2f33ee43157d6158421ba7fbb15841a2b1';

@ProviderFor(updateService)
final updateServiceProvider = UpdateServiceProvider._();

final class UpdateServiceProvider
    extends $FunctionalProvider<UpdateService, UpdateService, UpdateService>
    with $Provider<UpdateService> {
  UpdateServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateServiceHash();

  @$internal
  @override
  $ProviderElement<UpdateService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UpdateService create(Ref ref) {
    return updateService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateService>(value),
    );
  }
}

String _$updateServiceHash() => r'01c26b090c08db3cbb97aa632f3a89e56aca7eeb';

/// Remembers the last background check's result so the dashboard banner
/// (see dashboard_screen.dart) can show it reactively without every
/// screen re-querying the server itself - mirrors
/// PendingPaystackSalesNotifier's exact shape (starts empty/null rather
/// than loading, updated by an explicit call from app.dart's periodic
/// timer, not by watching a stream).

@ProviderFor(UpdateAvailabilityNotifier)
final updateAvailabilityProvider = UpdateAvailabilityNotifierProvider._();

/// Remembers the last background check's result so the dashboard banner
/// (see dashboard_screen.dart) can show it reactively without every
/// screen re-querying the server itself - mirrors
/// PendingPaystackSalesNotifier's exact shape (starts empty/null rather
/// than loading, updated by an explicit call from app.dart's periodic
/// timer, not by watching a stream).
final class UpdateAvailabilityNotifierProvider
    extends $NotifierProvider<UpdateAvailabilityNotifier, LatestVersionInfo?> {
  /// Remembers the last background check's result so the dashboard banner
  /// (see dashboard_screen.dart) can show it reactively without every
  /// screen re-querying the server itself - mirrors
  /// PendingPaystackSalesNotifier's exact shape (starts empty/null rather
  /// than loading, updated by an explicit call from app.dart's periodic
  /// timer, not by watching a stream).
  UpdateAvailabilityNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateAvailabilityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateAvailabilityNotifierHash();

  @$internal
  @override
  UpdateAvailabilityNotifier create() => UpdateAvailabilityNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LatestVersionInfo? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LatestVersionInfo?>(value),
    );
  }
}

String _$updateAvailabilityNotifierHash() =>
    r'89e721458a32a117ea74525c530c77677398bf5c';

/// Remembers the last background check's result so the dashboard banner
/// (see dashboard_screen.dart) can show it reactively without every
/// screen re-querying the server itself - mirrors
/// PendingPaystackSalesNotifier's exact shape (starts empty/null rather
/// than loading, updated by an explicit call from app.dart's periodic
/// timer, not by watching a stream).

abstract class _$UpdateAvailabilityNotifier
    extends $Notifier<LatestVersionInfo?> {
  LatestVersionInfo? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LatestVersionInfo?, LatestVersionInfo?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LatestVersionInfo?, LatestVersionInfo?>,
              LatestVersionInfo?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Owns the in-flight download/install Future instead of UpdateScreen's
/// own State - that used to live as plain widget state, so navigating
/// away (e.g. back to the dashboard) and returning built a brand new
/// UpdateScreen with no idea a download was already running: the
/// button reappeared as "Download & Install" even though the actual
/// download was never really cancelled (nothing about disposing a
/// widget stops an in-flight Future), just orphaned from any UI. Worse,
/// tapping the button again from that fresh screen started a second,
/// concurrent download to the exact same temp file path. keepAlive so
/// this survives exactly the navigation that used to lose it.

@ProviderFor(UpdateInstallNotifier)
final updateInstallProvider = UpdateInstallNotifierProvider._();

/// Owns the in-flight download/install Future instead of UpdateScreen's
/// own State - that used to live as plain widget state, so navigating
/// away (e.g. back to the dashboard) and returning built a brand new
/// UpdateScreen with no idea a download was already running: the
/// button reappeared as "Download & Install" even though the actual
/// download was never really cancelled (nothing about disposing a
/// widget stops an in-flight Future), just orphaned from any UI. Worse,
/// tapping the button again from that fresh screen started a second,
/// concurrent download to the exact same temp file path. keepAlive so
/// this survives exactly the navigation that used to lose it.
final class UpdateInstallNotifierProvider
    extends $NotifierProvider<UpdateInstallNotifier, UpdateInstallState> {
  /// Owns the in-flight download/install Future instead of UpdateScreen's
  /// own State - that used to live as plain widget state, so navigating
  /// away (e.g. back to the dashboard) and returning built a brand new
  /// UpdateScreen with no idea a download was already running: the
  /// button reappeared as "Download & Install" even though the actual
  /// download was never really cancelled (nothing about disposing a
  /// widget stops an in-flight Future), just orphaned from any UI. Worse,
  /// tapping the button again from that fresh screen started a second,
  /// concurrent download to the exact same temp file path. keepAlive so
  /// this survives exactly the navigation that used to lose it.
  UpdateInstallNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateInstallProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateInstallNotifierHash();

  @$internal
  @override
  UpdateInstallNotifier create() => UpdateInstallNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateInstallState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateInstallState>(value),
    );
  }
}

String _$updateInstallNotifierHash() =>
    r'4ada53b5b5289e0b9013a32f2d0b6324a121b6ba';

/// Owns the in-flight download/install Future instead of UpdateScreen's
/// own State - that used to live as plain widget state, so navigating
/// away (e.g. back to the dashboard) and returning built a brand new
/// UpdateScreen with no idea a download was already running: the
/// button reappeared as "Download & Install" even though the actual
/// download was never really cancelled (nothing about disposing a
/// widget stops an in-flight Future), just orphaned from any UI. Worse,
/// tapping the button again from that fresh screen started a second,
/// concurrent download to the exact same temp file path. keepAlive so
/// this survives exactly the navigation that used to lose it.

abstract class _$UpdateInstallNotifier extends $Notifier<UpdateInstallState> {
  UpdateInstallState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UpdateInstallState, UpdateInstallState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UpdateInstallState, UpdateInstallState>,
              UpdateInstallState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
