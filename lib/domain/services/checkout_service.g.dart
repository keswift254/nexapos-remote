// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checkout_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(checkoutService)
final checkoutServiceProvider = CheckoutServiceProvider._();

final class CheckoutServiceProvider
    extends
        $FunctionalProvider<CheckoutService, CheckoutService, CheckoutService>
    with $Provider<CheckoutService> {
  CheckoutServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'checkoutServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$checkoutServiceHash();

  @$internal
  @override
  $ProviderElement<CheckoutService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CheckoutService create(Ref ref) {
    return checkoutService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CheckoutService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CheckoutService>(value),
    );
  }
}

String _$checkoutServiceHash() => r'd9cfc85277ff7b6bce6e836c9e71b722402adbc1';
