// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paystack_payment_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(paystackPaymentService)
final paystackPaymentServiceProvider = PaystackPaymentServiceProvider._();

final class PaystackPaymentServiceProvider
    extends
        $FunctionalProvider<
          PaystackPaymentService,
          PaystackPaymentService,
          PaystackPaymentService
        >
    with $Provider<PaystackPaymentService> {
  PaystackPaymentServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paystackPaymentServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paystackPaymentServiceHash();

  @$internal
  @override
  $ProviderElement<PaystackPaymentService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PaystackPaymentService create(Ref ref) {
    return paystackPaymentService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaystackPaymentService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaystackPaymentService>(value),
    );
  }
}

String _$paystackPaymentServiceHash() =>
    r'7a9bdf152524c2ea59ed3d948dd0a382920ab831';
