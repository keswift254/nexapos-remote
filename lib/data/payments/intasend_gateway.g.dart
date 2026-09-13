// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'intasend_gateway.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(intaSendGateway)
final intaSendGatewayProvider = IntaSendGatewayProvider._();

final class IntaSendGatewayProvider
    extends
        $FunctionalProvider<IntaSendGateway, IntaSendGateway, IntaSendGateway>
    with $Provider<IntaSendGateway> {
  IntaSendGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'intaSendGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$intaSendGatewayHash();

  @$internal
  @override
  $ProviderElement<IntaSendGateway> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  IntaSendGateway create(Ref ref) {
    return intaSendGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IntaSendGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IntaSendGateway>(value),
    );
  }
}

String _$intaSendGatewayHash() => r'ef8c2098c2a41f9684c968b54d734f53166978a4';
