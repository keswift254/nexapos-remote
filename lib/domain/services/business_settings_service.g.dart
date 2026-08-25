// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_settings_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(businessSettingsService)
final businessSettingsServiceProvider = BusinessSettingsServiceProvider._();

final class BusinessSettingsServiceProvider
    extends
        $FunctionalProvider<
          BusinessSettingsService,
          BusinessSettingsService,
          BusinessSettingsService
        >
    with $Provider<BusinessSettingsService> {
  BusinessSettingsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'businessSettingsServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$businessSettingsServiceHash();

  @$internal
  @override
  $ProviderElement<BusinessSettingsService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BusinessSettingsService create(Ref ref) {
    return businessSettingsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BusinessSettingsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BusinessSettingsService>(value),
    );
  }
}

String _$businessSettingsServiceHash() =>
    r'4bd6ec6d55d18536809f16811cefd21c17a1fbc4';
