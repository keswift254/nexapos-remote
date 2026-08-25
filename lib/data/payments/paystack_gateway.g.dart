// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paystack_gateway.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(paystackGateway)
final paystackGatewayProvider = PaystackGatewayProvider._();

final class PaystackGatewayProvider
    extends
        $FunctionalProvider<PaystackGateway, PaystackGateway, PaystackGateway>
    with $Provider<PaystackGateway> {
  PaystackGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paystackGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paystackGatewayHash();

  @$internal
  @override
  $ProviderElement<PaystackGateway> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PaystackGateway create(Ref ref) {
    return paystackGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaystackGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaystackGateway>(value),
    );
  }
}

String _$paystackGatewayHash() => r'684c6addc80792615cac839c83595c1cf87ca298';
