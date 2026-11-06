import 'package:flutter_riverpod/flutter_riverpod.dart' show Notifier, NotifierProvider;
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
    final paystackCheck = ref.read(paystackPaymentServiceProvider).reconcileAndReport();
    final intaSendCheck = ref.read(intaSendPaymentServiceProvider).reconcilePendingSales();
    final paystack = await paystackCheck;
    final intaSend = await intaSendCheck;
    if (!ref.mounted) return;
    state = [...paystack.stillPending, ...intaSend];
    ref.read(confirmedOnlineSalesProvider.notifier).add(paystack.nowPaid);
  }
}

/// Online payments this reconcile pass found paid while nobody was watching -
/// the page was reloaded on the way back from the payment page, or the cashier
/// left the waiting screen - so the dashboard can say so instead of leaving
/// the cashier to wonder what happened to the sale.
class ConfirmedOnlineSalesNotifier extends Notifier<List<Sale>> {
  @override
  List<Sale> build() => const [];

  void add(List<Sale> sales) {
    if (sales.isEmpty) return;
    final known = {for (final sale in state) sale.id};
    final fresh = [
      for (final sale in sales)
        if (!known.contains(sale.id)) sale,
    ];
    if (fresh.isNotEmpty) state = [...state, ...fresh];
  }

  void dismiss(String saleId) {
    state = [
      for (final sale in state)
        if (sale.id != saleId) sale,
    ];
  }
}

final confirmedOnlineSalesProvider =
    NotifierProvider<ConfirmedOnlineSalesNotifier, List<Sale>>(
      ConfirmedOnlineSalesNotifier.new,
    );
