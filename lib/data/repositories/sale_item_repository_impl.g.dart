// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_item_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(saleItemRepository)
final saleItemRepositoryProvider = SaleItemRepositoryProvider._();

final class SaleItemRepositoryProvider
    extends
        $FunctionalProvider<
          SaleItemRepository,
          SaleItemRepository,
          SaleItemRepository
        >
    with $Provider<SaleItemRepository> {
  SaleItemRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'saleItemRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$saleItemRepositoryHash();

  @$internal
  @override
  $ProviderElement<SaleItemRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SaleItemRepository create(Ref ref) {
    return saleItemRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SaleItemRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SaleItemRepository>(value),
    );
  }
}

String _$saleItemRepositoryHash() =>
    r'7243e67c63b5f4f0c3ffb9a38bb45454b7c1428f';
