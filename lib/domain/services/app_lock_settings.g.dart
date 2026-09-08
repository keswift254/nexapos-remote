// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_lock_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppLockSettings)
final appLockSettingsProvider = AppLockSettingsProvider._();

final class AppLockSettingsProvider
    extends $NotifierProvider<AppLockSettings, int> {
  AppLockSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLockSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLockSettingsHash();

  @$internal
  @override
  AppLockSettings create() => AppLockSettings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$appLockSettingsHash() => r'7f49e2db7d488be32f13f968726ef7a41c91f330';

abstract class _$AppLockSettings extends $Notifier<int> {
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
