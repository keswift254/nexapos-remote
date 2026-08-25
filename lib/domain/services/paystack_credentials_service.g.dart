// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paystack_credentials_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(paystackCredentialsService)
final paystackCredentialsServiceProvider =
    PaystackCredentialsServiceProvider._();

final class PaystackCredentialsServiceProvider
    extends
        $FunctionalProvider<
          PaystackCredentialsService,
          PaystackCredentialsService,
          PaystackCredentialsService
        >
    with $Provider<PaystackCredentialsService> {
  PaystackCredentialsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paystackCredentialsServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paystackCredentialsServiceHash();

  @$internal
  @override
  $ProviderElement<PaystackCredentialsService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PaystackCredentialsService create(Ref ref) {
    return paystackCredentialsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaystackCredentialsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaystackCredentialsService>(value),
    );
  }
}

String _$paystackCredentialsServiceHash() =>
    r'942f949212bec8efe82e9ce9a056726fce043f8f';
