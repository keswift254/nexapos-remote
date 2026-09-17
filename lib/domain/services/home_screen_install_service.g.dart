// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_screen_install_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Only ever meaningfully different from the default (nothing to offer)
/// on web - see HomeScreenInstallState.isStandalone's doc. Kept alive so
/// Android Chrome's beforeinstallprompt listener, registered once in
/// build(), stays attached for the tab's whole life instead of being torn
/// down and re-added whenever this provider's last watcher unsubscribes.

@ProviderFor(HomeScreenInstallNotifier)
final homeScreenInstallProvider = HomeScreenInstallNotifierProvider._();

/// Only ever meaningfully different from the default (nothing to offer)
/// on web - see HomeScreenInstallState.isStandalone's doc. Kept alive so
/// Android Chrome's beforeinstallprompt listener, registered once in
/// build(), stays attached for the tab's whole life instead of being torn
/// down and re-added whenever this provider's last watcher unsubscribes.
final class HomeScreenInstallNotifierProvider
    extends
        $NotifierProvider<HomeScreenInstallNotifier, HomeScreenInstallState> {
  /// Only ever meaningfully different from the default (nothing to offer)
  /// on web - see HomeScreenInstallState.isStandalone's doc. Kept alive so
  /// Android Chrome's beforeinstallprompt listener, registered once in
  /// build(), stays attached for the tab's whole life instead of being torn
  /// down and re-added whenever this provider's last watcher unsubscribes.
  HomeScreenInstallNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeScreenInstallProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeScreenInstallNotifierHash();

  @$internal
  @override
  HomeScreenInstallNotifier create() => HomeScreenInstallNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HomeScreenInstallState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HomeScreenInstallState>(value),
    );
  }
}

String _$homeScreenInstallNotifierHash() =>
    r'a27757ecb305e305bb84a7b1e599cfc1037d2162';

/// Only ever meaningfully different from the default (nothing to offer)
/// on web - see HomeScreenInstallState.isStandalone's doc. Kept alive so
/// Android Chrome's beforeinstallprompt listener, registered once in
/// build(), stays attached for the tab's whole life instead of being torn
/// down and re-added whenever this provider's last watcher unsubscribes.

abstract class _$HomeScreenInstallNotifier
    extends $Notifier<HomeScreenInstallState> {
  HomeScreenInstallState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<HomeScreenInstallState, HomeScreenInstallState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<HomeScreenInstallState, HomeScreenInstallState>,
              HomeScreenInstallState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
