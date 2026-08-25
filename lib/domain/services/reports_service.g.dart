// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reports_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(reportsService)
final reportsServiceProvider = ReportsServiceProvider._();

final class ReportsServiceProvider
    extends $FunctionalProvider<ReportsService, ReportsService, ReportsService>
    with $Provider<ReportsService> {
  ReportsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reportsServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reportsServiceHash();

  @$internal
  @override
  $ProviderElement<ReportsService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReportsService create(Ref ref) {
    return reportsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReportsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReportsService>(value),
    );
  }
}

String _$reportsServiceHash() => r'3227063bfd5b1be690f5642acd635f0cb507dcf1';
