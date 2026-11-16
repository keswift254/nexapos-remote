// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'refund_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(refundService)
final refundServiceProvider = RefundServiceProvider._();

final class RefundServiceProvider
    extends $FunctionalProvider<RefundService, RefundService, RefundService>
    with $Provider<RefundService> {
  RefundServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'refundServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$refundServiceHash();

  @$internal
  @override
  $ProviderElement<RefundService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RefundService create(Ref ref) {
    return refundService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RefundService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RefundService>(value),
    );
  }
}

String _$refundServiceHash() => r'81a11d7282aa74cb405bab1a12e369f246e3d996';
