// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_sales_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds whichever online-gateway sales (Paystack or IntaSend) are still
/// stranded in 'pending' after the startup reconciliation pass - starts
/// empty rather than loading, since most launches have nothing to
/// reconcile and the dashboard shouldn't show a spinner for that common
/// case. Fans out to both services' own reconcilePendingSales (each
/// already filters to its own paymentMethod - see their doc comments)
/// and merges what's left; kept as one notifier/one dashboard banner
/// rather than a separate one per gateway, since a cashier doesn't care
/// which gateway a stuck payment used, only that money might be stuck.

@ProviderFor(PendingPaystackSalesNotifier)
final pendingPaystackSalesProvider = PendingPaystackSalesNotifierProvider._();

/// Holds whichever online-gateway sales (Paystack or IntaSend) are still
/// stranded in 'pending' after the startup reconciliation pass - starts
/// empty rather than loading, since most launches have nothing to
/// reconcile and the dashboard shouldn't show a spinner for that common
/// case. Fans out to both services' own reconcilePendingSales (each
/// already filters to its own paymentMethod - see their doc comments)
/// and merges what's left; kept as one notifier/one dashboard banner
/// rather than a separate one per gateway, since a cashier doesn't care
/// which gateway a stuck payment used, only that money might be stuck.
final class PendingPaystackSalesNotifierProvider
    extends $NotifierProvider<PendingPaystackSalesNotifier, List<Sale>> {
  /// Holds whichever online-gateway sales (Paystack or IntaSend) are still
  /// stranded in 'pending' after the startup reconciliation pass - starts
  /// empty rather than loading, since most launches have nothing to
  /// reconcile and the dashboard shouldn't show a spinner for that common
  /// case. Fans out to both services' own reconcilePendingSales (each
  /// already filters to its own paymentMethod - see their doc comments)
  /// and merges what's left; kept as one notifier/one dashboard banner
  /// rather than a separate one per gateway, since a cashier doesn't care
  /// which gateway a stuck payment used, only that money might be stuck.
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
    r'0ef228b0964d09b4d8c48e992a393ff937a4a11e';

/// Holds whichever online-gateway sales (Paystack or IntaSend) are still
/// stranded in 'pending' after the startup reconciliation pass - starts
/// empty rather than loading, since most launches have nothing to
/// reconcile and the dashboard shouldn't show a spinner for that common
/// case. Fans out to both services' own reconcilePendingSales (each
/// already filters to its own paymentMethod - see their doc comments)
/// and merges what's left; kept as one notifier/one dashboard banner
/// rather than a separate one per gateway, since a cashier doesn't care
/// which gateway a stuck payment used, only that money might be stuck.

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
