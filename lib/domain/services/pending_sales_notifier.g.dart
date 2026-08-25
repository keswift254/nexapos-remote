// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_sales_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds whichever paystack sales are still stranded in 'pending' after
/// the startup reconciliation pass (see
/// PaystackPaymentService.reconcilePendingSales) - starts empty rather
/// than loading, since most launches have nothing to reconcile and the
/// dashboard shouldn't show a spinner for that common case.

@ProviderFor(PendingPaystackSalesNotifier)
final pendingPaystackSalesProvider = PendingPaystackSalesNotifierProvider._();

/// Holds whichever paystack sales are still stranded in 'pending' after
/// the startup reconciliation pass (see
/// PaystackPaymentService.reconcilePendingSales) - starts empty rather
/// than loading, since most launches have nothing to reconcile and the
/// dashboard shouldn't show a spinner for that common case.
final class PendingPaystackSalesNotifierProvider
    extends $NotifierProvider<PendingPaystackSalesNotifier, List<Sale>> {
  /// Holds whichever paystack sales are still stranded in 'pending' after
  /// the startup reconciliation pass (see
  /// PaystackPaymentService.reconcilePendingSales) - starts empty rather
  /// than loading, since most launches have nothing to reconcile and the
  /// dashboard shouldn't show a spinner for that common case.
  PendingPaystackSalesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingPaystackSalesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingPaystackSalesNotifierHash();

  @$internal
  @override
  PendingPaystackSalesNotifier create() => PendingPaystackSalesNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Sale> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Sale>>(value),
    );
  }
}

String _$pendingPaystackSalesNotifierHash() =>
    r'31c22ecc75415519894ae7af106d1c3071bc8f30';

/// Holds whichever paystack sales are still stranded in 'pending' after
/// the startup reconciliation pass (see
/// PaystackPaymentService.reconcilePendingSales) - starts empty rather
/// than loading, since most launches have nothing to reconcile and the
/// dashboard shouldn't show a spinner for that common case.

abstract class _$PendingPaystackSalesNotifier extends $Notifier<List<Sale>> {
  List<Sale> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<Sale>, List<Sale>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<Sale>, List<Sale>>,
              List<Sale>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
