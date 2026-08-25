import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../entities/sale.dart';
import 'paystack_payment_service.dart';

part 'pending_sales_notifier.g.dart';

/// Holds whichever paystack sales are still stranded in 'pending' after
/// the startup reconciliation pass (see
/// PaystackPaymentService.reconcilePendingSales) - starts empty rather
/// than loading, since most launches have nothing to reconcile and the
/// dashboard shouldn't show a spinner for that common case.
@Riverpod(keepAlive: true)
class PendingPaystackSalesNotifier extends _$PendingPaystackSalesNotifier {
  @override
  List<Sale> build() => const [];

  Future<void> reconcile() async {
    final stillPending = await ref.read(paystackPaymentServiceProvider).reconcilePendingSales();
    if (ref.mounted) state = stillPending;
  }
}
