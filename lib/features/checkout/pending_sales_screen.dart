import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/sale.dart';
import '../../domain/services/paystack_payment_service.dart';
import '../../domain/services/pending_sales_notifier.dart';

/// Lists paystack sales left stranded in 'pending' - reached only from
/// the dashboard's warning banner, which only appears once startup
/// reconciliation has already resolved everything it silently could
/// (see PendingPaystackSalesNotifier). Deliberately has no "reopen
/// checkout page" action like PaystackWaitingScreen does: the original
/// authorizationUrl was never persisted, so it can't be reconstructed
/// after an app restart - only "check again" (re-poll the gateway) and
/// "cancel and restore stock" are honest options here.
class PendingSalesScreen extends ConsumerStatefulWidget {
  const PendingSalesScreen({super.key});

  @override
  ConsumerState<PendingSalesScreen> createState() => _PendingSalesScreenState();
}

class _PendingSalesScreenState extends ConsumerState<PendingSalesScreen> {
  final _busy = <String>{};

  Future<void> _checkNow(Sale sale) async {
    setState(() => _busy.add(sale.id));
    final outcome = await ref.read(paystackPaymentServiceProvider).checkPending(sale);
    if (!mounted) return;
    if (outcome is PaystackPollPaid) {
      await ref.read(pendingPaystackSalesProvider.notifier).reconcile();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${sale.saleNumber} confirmed paid.')));
    } else {
      setState(() => _busy.remove(sale.id));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Still not confirmed by Paystack.')));
    }
  }

  Future<void> _cancel(Sale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this sale?'),
        content: Text(
          'The reserved stock for ${sale.saleNumber} will be returned and the sale marked cancelled. '
          'Only do this if the customer did not complete the Paystack payment.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep waiting')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel sale')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy.add(sale.id));
    final result = await ref.read(paystackPaymentServiceProvider).cancel(sale.id);
    if (!mounted) return;
    result.when(
      ok: (_) async {
        await ref.read(pendingPaystackSalesProvider.notifier).reconcile();
      },
      failure: (message) {
        setState(() => _busy.remove(sale.id));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingPaystackSalesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pending Payments')),
      body: pending.isEmpty
          ? const Center(child: Text('No pending Paystack payments.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: pending.length,
              itemBuilder: (context, index) {
                final sale = pending[index];
                final isBusy = _busy.contains(sale.id);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sale.saleNumber, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('${sale.customerName} · ${sale.total.format()}'),
                        Text(
                          'Since ${DateFormat('d MMM, HH:mm').format(sale.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isBusy ? null : () => _checkNow(sale),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Check now'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: isBusy ? null : () => _cancel(sale),
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Cancel'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
