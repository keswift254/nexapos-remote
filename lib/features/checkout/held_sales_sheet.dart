import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart' show clockProvider;
import '../../domain/services/session_service.dart';
import 'cart_notifier.dart';
import 'held_sales_notifier.dart';

/// "Held sales" button for an app bar: shows how many sales are set aside and opens the
/// list they can be opened (or thrown away) from.
class HeldSalesButton extends ConsumerWidget {
  /// Called after a held sale has been opened into the cart (the list closes first).
  final VoidCallback? onResumed;

  const HeldSalesButton({super.key, this.onResumed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(heldSalesProvider).length;
    return IconButton(
      tooltip: count == 0 ? 'Held sales' : 'Held sales ($count)',
      icon: Badge(
        label: Text('$count'),
        isLabelVisible: count > 0,
        child: const Icon(Icons.pause_circle_outline),
      ),
      onPressed: () => showHeldSalesSheet(context, onResumed: onResumed),
    );
  }
}

Future<void> showHeldSalesSheet(BuildContext context, {VoidCallback? onResumed}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => HeldSalesSheet(onResumed: onResumed),
  );
}

String heldAgo(DateTime heldAt, DateTime now) {
  final difference = now.difference(heldAt);
  if (difference.inMinutes < 1) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} h ago';
  return '${difference.inDays} d ago';
}

class HeldSalesSheet extends ConsumerWidget {
  final VoidCallback? onResumed;

  const HeldSalesSheet({super.key, this.onResumed});

  Future<void> _open(BuildContext context, WidgetRef ref, HeldSale held) async {
    final cart = ref.read(cartProvider);
    final user = ref.read(sessionProvider);
    var holdCurrentFirst = false;
    if (cart.isNotEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Open this held sale?'),
          content: Text(
            'The sale you are working on has ${cart.itemCount} '
            '${cart.itemCount == 1 ? 'item' : 'items'}. It will be held, so you can come back to it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('Hold it and open "${held.label}"'),
            ),
          ],
        ),
      );
      if (go != true) return;
      holdCurrentFirst = true;
    }
    final opened = await ref
        .read(heldSalesProvider.notifier)
        .resume(held.id, heldBy: user?.name ?? 'Cashier', holdCurrentFirst: holdCurrentFirst);
    if (!context.mounted) return;
    if (opened) {
      Navigator.pop(context);
      onResumed?.call();
    }
  }

  Future<void> _discard(BuildContext context, WidgetRef ref, HeldSale held) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Throw away this held sale?'),
        content: Text(
          '"${held.label}" (${held.cart.itemCount} ${held.cart.itemCount == 1 ? 'item' : 'items'}, '
          '${held.total.format()}) will be removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Throw away'),
          ),
        ],
      ),
    );
    if (confirmed == true) await ref.read(heldSalesProvider.notifier).discard(held.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final held = ref.watch(heldSalesProvider);
    final now = ref.watch(clockProvider).now();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Held sales', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Sales set aside to serve someone else first. Holding does not take stock or record any payment.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (held.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No held sales.')),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final sale in held)
                      Card(
                        child: ListTile(
                          key: ValueKey('held-${sale.id}'),
                          title: Text(sale.label),
                          subtitle: Text(
                            '${sale.cart.itemCount} ${sale.cart.itemCount == 1 ? 'item' : 'items'} · '
                            '${sale.total.format()} · ${heldAgo(sale.heldAt, now)} · ${sale.heldBy}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Throw away',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _discard(context, ref, sale),
                              ),
                              FilledButton(
                                onPressed: () => _open(context, ref, sale),
                                child: const Text('Open'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
