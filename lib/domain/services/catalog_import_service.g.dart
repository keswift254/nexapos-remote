// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_import_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(catalogImportService)
final catalogImportServiceProvider = CatalogImportServiceProvider._();

final class CatalogImportServiceProvider
    extends
        $FunctionalProvider<
          CatalogImportService,
          CatalogImportService,
          CatalogImportService
        >
    with $Provider<CatalogImportService> {
  CatalogImportServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'catalogImportServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$catalogImportServiceHash();

  @$internal
  @override
  $ProviderElement<CatalogImportService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CatalogImportService create(Ref ref) {
    return catalogImportService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CatalogImportService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CatalogImportService>(value),
    );
  }
}

String _$catalogImportServiceHash() =>
    r'c26036b476f9bbbf59f65225b659a9bc472847dc';
