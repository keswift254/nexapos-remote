import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/utils/money.dart';
import '../../data/repositories/business_settings_repository_impl.dart';
import '../../domain/services/refund_service.dart';
import '../settings/sensitive_action_dialog.dart';

/// Give money back for an earlier sale: choose what comes back (all of it, or some of each line), say why,
/// and confirm with your own password. Reached from the sale's receipt; only an administrator or a manager.
class RefundScreen extends ConsumerStatefulWidget {
  final String saleId;

  const RefundScreen({super.key, required this.saleId});

  @override
  ConsumerState<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends ConsumerState<RefundScreen> {
  RefundableSale? _source;
  String _currency = 'KES';
  String? _loadError;
  final Map<String, int> _quantity = {};
  final Map<String, bool> _restock = {};
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final source = await ref.read(refundServiceProvider).refundableSale(widget.saleId);
      final settings = await ref.read(businessSettingsRepositoryProvider).get();
      if (!mounted) return;
      setState(() {
        _source = source;
        _currency = settings.currency;
        _loadError = source == null ? 'Sale not found.' : null;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = '$e');
    }
  }

  String _money(Money value) => value.format(currency: _currency);

  List<RefundChoice> get _choices {
    final source = _source;
    if (source == null) return const [];
    return [
      for (final line in source.lines)
        if ((_quantity[line.item.id] ?? 0) > 0)
          RefundChoice(
            itemId: line.item.id,
            quantity: _quantity[line.item.id]!,
            restock: _restock[line.item.id] ?? true,
          ),
    ];
  }

  void _setQuantity(String itemId, int value, int remaining) {
    setState(() {
      _quantity[itemId] = value.clamp(0, remaining);
      _error = null;
    });
  }

  void _selectWholeSale() {
    final source = _source;
    if (source == null) return;
    setState(() {
      for (final line in source.lines) {
        _quantity[line.item.id] = line.remaining > 0 ? line.remaining : 0;
      }
      _error = null;
    });
  }

  void _clear() => setState(() {
        _quantity.clear();
        _error = null;
      });

  Future<void> _submit(RefundableSale source) async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Enter the reason for the refund.');
      return;
    }
    final approval = await requestSensitiveApproval(
      context,
      action: refundApprovalAction,
      requireAuthenticator: false,
      roles: refundRoles,
    );
    if (approval == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(refundServiceProvider).refund(
          saleId: source.sale.id,
          choices: _choices,
          reason: reason,
          approval: approval,
        );
    if (!mounted) return;
    result.when(
      ok: (refund) => context.go('/receipt/${refund.id}?from=reports'),
      failure: (message) => setState(() {
        _busy = false;
        _error = message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    return Scaffold(
      appBar: AppBar(title: const Text('Refund')),
      body: _loadError != null
          ? Center(child: Text(_loadError!, key: const Key('refund-load-error')))
          : source == null
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: _body(context, source),
                  ),
                ),
    );
  }

  Widget _body(BuildContext context, RefundableSale source) {
    final sale = source.sale;
    final blocked = source.whyNot;
    final quote = _choices.isEmpty ? null : ref.read(refundServiceProvider).quote(source, _choices);
    final amounts = quote?.when(ok: (q) => q, failure: (_) => null);
    final problem = quote?.when(ok: (_) => null, failure: (m) => m);
    final reasonFilled = _reason.text.trim().isNotEmpty;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sale ${sale.saleNumber}', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(DateFormat('d MMM yyyy HH:mm').format(sale.createdAt.toLocal())),
                Text('Paid: ${_money(sale.total)} (${sale.paymentMethodLabel})'),
                if (source.refundedTotal.cents > 0)
                  Text(
                    'Already refunded: ${_money(source.refundedTotal)}',
                    key: const Key('refund-already'),
                  ),
              ],
            ),
          ),
        ),
        if (blocked != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(blocked, key: const Key('refund-blocked'), style: theme.textTheme.titleMedium),
          )
        else ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text('What is being given back?', style: theme.textTheme.titleMedium)),
              TextButton(
                key: const Key('refund-whole'),
                onPressed: _busy ? null : _selectWholeSale,
                child: const Text('Whole sale'),
              ),
              TextButton(
                key: const Key('refund-clear'),
                onPressed: _busy ? null : _clear,
                child: const Text('Clear'),
              ),
            ],
          ),
          for (final line in source.lines) _lineCard(line),
          const SizedBox(height: 12),
          TextField(
            key: const Key('refund-reason'),
            controller: _reason,
            enabled: !_busy,
            maxLength: maxRefundReasonLength,
            decoration: const InputDecoration(
              labelText: 'Reason for the refund',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 8),
          if (amounts != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Refund', style: theme.textTheme.titleMedium),
                        Text(
                          _money(amounts.total),
                          key: const Key('refund-total'),
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (amounts.discount.cents > 0)
                      Text(
                        'Goods ${_money(amounts.subtotal)} less its share of the discount ${_money(amounts.discount)}',
                        key: const Key('refund-discount-note'),
                      ),
                    const SizedBox(height: 8),
                    Text(_payBackText(sale.paymentMethod, amounts), key: const Key('refund-pay-back')),
                  ],
                ),
              ),
            ),
          if (problem != null) Text(problem, key: const Key('refund-problem'), style: TextStyle(color: theme.colorScheme.error)),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, key: const Key('refund-error'), style: TextStyle(color: theme.colorScheme.error)),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('refund-submit'),
            onPressed: (_busy || amounts == null || !reasonFilled) ? null : () => _submit(source),
            icon: _busy
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.undo),
            label: Text(amounts == null ? 'Refund' : 'Refund ${_money(amounts.total)}'),
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  /// Plain words about handing the money back: NexaPOS records the refund, the person pays it out.
  String _payBackText(String method, RefundQuote q) {
    if (method == 'cash') return 'Hand ${_money(q.total)} back to the customer in cash.';
    final cash = q.cash;
    if (cash != null && cash.cents > 0) {
      final rest = Money(q.total.cents - cash.cents);
      return 'Hand ${_money(cash)} back in cash and send ${_money(rest)} back by M-Pesa yourself. NexaPOS does not send money.';
    }
    return 'Send ${_money(q.total)} back to the customer by M-Pesa yourself. NexaPOS does not send money.';
  }

  Widget _lineCard(RefundableLine line) {
    final item = line.item;
    final id = item.id;
    final qty = _quantity[id] ?? 0;
    final stockItem = item.productId != null;
    if (line.remaining < 1) {
      return Card(
        child: ListTile(
          title: Text(item.itemName),
          subtitle: Text('Already refunded (${item.quantity} sold)'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.itemName, style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        '${_money(item.unitPrice)} each, ${item.quantity} sold'
                        '${line.refunded > 0 ? ', ${line.refunded} already refunded' : ''}',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: Key('refund-minus-$id'),
                  onPressed: _busy || qty < 1 ? null : () => _setQuantity(id, qty - 1, line.remaining),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                SizedBox(
                  width: 28,
                  child: Text('$qty', key: Key('refund-qty-$id'), textAlign: TextAlign.center),
                ),
                IconButton(
                  key: Key('refund-plus-$id'),
                  onPressed: _busy || qty >= line.remaining ? null : () => _setQuantity(id, qty + 1, line.remaining),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (qty > 0 && stockItem)
              SwitchListTile(
                key: Key('refund-restock-$id'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Put back in stock'),
                subtitle: const Text('Switch off if it is damaged or cannot be sold again.'),
                value: _restock[id] ?? true,
                onChanged: _busy ? null : (value) => setState(() => _restock[id] = value),
              ),
          ],
        ),
      ),
    );
  }
}
