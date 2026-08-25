// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(saleRepository)
final saleRepositoryProvider = SaleRepositoryProvider._();

final class SaleRepositoryProvider
    extends $FunctionalProvider<SaleRepository, SaleRepository, SaleRepository>
    with $Provider<SaleRepository> {
  SaleRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'saleRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$saleRepositoryHash();

  @$internal
  @override
  $ProviderElement<SaleRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SaleRepository create(Ref ref) {
    return saleRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SaleRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SaleRepository>(value),
    );
  }
}

String _$saleRepositoryHash() => r'c39f985ef1fd2b0d4e27b317be12924a144f0ce6';
