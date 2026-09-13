// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'intasend_payment_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(intaSendPaymentService)
final intaSendPaymentServiceProvider = IntaSendPaymentServiceProvider._();

final class IntaSendPaymentServiceProvider
    extends
        $FunctionalProvider<
          IntaSendPaymentService,
          IntaSendPaymentService,
          IntaSendPaymentService
        >
    with $Provider<IntaSendPaymentService> {
  IntaSendPaymentServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'intaSendPaymentServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$intaSendPaymentServiceHash();

  @$internal
  @override
  $ProviderElement<IntaSendPaymentService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IntaSendPaymentService create(Ref ref) {
    return intaSendPaymentService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IntaSendPaymentService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IntaSendPaymentService>(value),
    );
  }
}

String _$intaSendPaymentServiceHash() =>
    r'8bcdcd591166262361d476fa08e48d23403a0ca8';
