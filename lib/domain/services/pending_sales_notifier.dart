import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../entities/sale.dart';
import 'intasend_payment_service.dart';
import 'paystack_payment_service.dart';

part 'pending_sales_notifier.g.dart';

/// Holds whichever online-gateway sales (Paystack or IntaSend) are still
/// stranded in 'pending' after the startup reconciliation pass - starts
/// empty rather than loading, since most launches have nothing to
/// reconcile and the dashboard shouldn't show a spinner for that common
/// case. Fans out to both services' own reconcilePendingSales (each
/// already filters to its own paymentMethod - see their doc comments)
/// and merges what's left; kept as one notifier/one dashboard banner
/// rather than a separate one per gateway, since a cashier doesn't care
/// which gateway a stuck payment used, only that money might be stuck.
@Riverpod(keepAlive: true)
class PendingPaystackSalesNotifier extends _$PendingPaystackSalesNotifier {
  @override
  List<Sale> build() => const [];

  Future<void> reconcile() async {
    final results = await Future.wait([
      ref.read(paystackPaymentServiceProvider).reconcilePendingSales(),
      ref.read(intaSendPaymentServiceProvider).reconcilePendingSales(),
    ]);
    if (ref.mounted) state = [...results[0], ...results[1]];
  }
}
