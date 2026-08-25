// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_settings_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(businessSettingsRepository)
final businessSettingsRepositoryProvider =
    BusinessSettingsRepositoryProvider._();

final class BusinessSettingsRepositoryProvider
    extends
        $FunctionalProvider<
          BusinessSettingsRepository,
          BusinessSettingsRepository,
          BusinessSettingsRepository
        >
    with $Provider<BusinessSettingsRepository> {
  BusinessSettingsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'businessSettingsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$businessSettingsRepositoryHash();

  @$internal
  @override
  $ProviderElement<BusinessSettingsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BusinessSettingsRepository create(Ref ref) {
    return businessSettingsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BusinessSettingsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BusinessSettingsRepository>(value),
    );
  }
}

String _$businessSettingsRepositoryHash() =>
    r'c02e935b74ce7d267e834b8d19467710ffee3792';
