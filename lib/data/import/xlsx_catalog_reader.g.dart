// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'xlsx_catalog_reader.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(xlsxCatalogReader)
final xlsxCatalogReaderProvider = XlsxCatalogReaderProvider._();

final class XlsxCatalogReaderProvider
    extends
        $FunctionalProvider<
          XlsxCatalogReader,
          XlsxCatalogReader,
          XlsxCatalogReader
        >
    with $Provider<XlsxCatalogReader> {
  XlsxCatalogReaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'xlsxCatalogReaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$xlsxCatalogReaderHash();

  @$internal
  @override
  $ProviderElement<XlsxCatalogReader> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  XlsxCatalogReader create(Ref ref) {
    return xlsxCatalogReader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(XlsxCatalogReader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<XlsxCatalogReader>(value),
    );
  }
}

String _$xlsxCatalogReaderHash() => r'1ac7ae9c3d98b3fbfee44fd42acafab554227beb';
