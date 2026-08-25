// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_settings_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(currentBusinessSettings)
final currentBusinessSettingsProvider = CurrentBusinessSettingsProvider._();

final class CurrentBusinessSettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<BusinessSettings>,
          BusinessSettings,
          FutureOr<BusinessSettings>
        >
    with $FutureModifier<BusinessSettings>, $FutureProvider<BusinessSettings> {
  CurrentBusinessSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentBusinessSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentBusinessSettingsHash();

  @$internal
  @override
  $FutureProviderElement<BusinessSettings> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BusinessSettings> create(Ref ref) {
    return currentBusinessSettings(ref);
  }
}

String _$currentBusinessSettingsHash() =>
    r'8ad8d2f1f9b9820d7676e9a7c87d2aba0fe8948d';
