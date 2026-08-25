// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'products_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(allProducts)
final allProductsProvider = AllProductsProvider._();

final class AllProductsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Product>>,
          List<Product>,
          FutureOr<List<Product>>
        >
    with $FutureModifier<List<Product>>, $FutureProvider<List<Product>> {
  AllProductsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allProductsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allProductsHash();

  @$internal
  @override
  $FutureProviderElement<List<Product>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Product>> create(Ref ref) {
    return allProducts(ref);
  }
}

String _$allProductsHash() => r'6f1761fbefa0941a2e7361f56deaac5ccc0a0dc4';

@ProviderFor(productFormCategories)
final productFormCategoriesProvider = ProductFormCategoriesProvider._();

final class ProductFormCategoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Category>>,
          List<Category>,
          FutureOr<List<Category>>
        >
    with $FutureModifier<List<Category>>, $FutureProvider<List<Category>> {
  ProductFormCategoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'productFormCategoriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$productFormCategoriesHash();

  @$internal
  @override
  $FutureProviderElement<List<Category>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Category>> create(Ref ref) {
    return productFormCategories(ref);
  }
}

String _$productFormCategoriesHash() =>
    r'b85e4a198c7928bd1f6fe09e28179a70c8f875ad';
