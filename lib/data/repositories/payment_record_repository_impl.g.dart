// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_record_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(paymentRecordRepository)
final paymentRecordRepositoryProvider = PaymentRecordRepositoryProvider._();

final class PaymentRecordRepositoryProvider
    extends
        $FunctionalProvider<
          PaymentRecordRepository,
          PaymentRecordRepository,
          PaymentRecordRepository
        >
    with $Provider<PaymentRecordRepository> {
  PaymentRecordRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paymentRecordRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paymentRecordRepositoryHash();

  @$internal
  @override
  $ProviderElement<PaymentRecordRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PaymentRecordRepository create(Ref ref) {
    return paymentRecordRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaymentRecordRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaymentRecordRepository>(value),
    );
  }
}

String _$paymentRecordRepositoryHash() =>
    r'dd8cfcf39af0847fa5c83f73e41b64f7ed33cade';
