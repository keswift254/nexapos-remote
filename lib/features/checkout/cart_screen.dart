import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/money.dart';
import '../../domain/services/checkout_service.dart';
import '../../domain/services/paystack_payment_service.dart';
import '../../domain/services/session_service.dart';
import '../dashboard/dashboard_screen.dart';
import 'cart_notifier.dart';
import 'paystack_waiting_screen.dart';

const _paymentMethodLabels = {
  'cash': 'Cash',
  'mpesa': 'M-Pesa',
  'mpesa_manual': 'M-Pesa Till',
  'paystack': 'Paystack',
};

/// Cart review + checkout details. cash/mpesa/mpesa_manual complete
/// immediately through CheckoutService; paystack hands off to
/// PaystackPaymentService and, on success, PaystackWaitingScreen.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  late final _nameController = TextEditingController(text: ref.read(cartProvider).customerName);
  late final _phoneController = TextEditingController(text: ref.read(cartProvider).customerPhone);
  late final _noteController = TextEditingController(text: ref.read(cartProvider).referenceNote);
  late final _discountController = TextEditingController(
    text: ref.read(cartProvider).discount.cents == 0
        ? ''
        : ref.read(cartProvider).discount.toMajorDouble.toStringAsFixed(2),
  );
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _submit(CartNotifier cart, String paymentMethod, String userId) async {
    setState(() => _submitting = true);

    if (paymentMethod == 'paystack') {
      final service = ref.read(paystackPaymentServiceProvider);
      final state = ref.read(cartProvider);
      final result = await service.start(
        cart: state.items,
        discount: state.discount,
        customerName: _nameController.text,
        customerPhone: _phoneController.text,
        saleType: state.saleType,
        userId: userId,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      result.when(
        ok: (session) {
          cart.clear();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PaystackWaitingScreen(session: session)),
          );
        },
        failure: (message) => _showError(message),
      );
      return;
    }

    final service = ref.read(checkoutServiceProvider);
    final state = ref.read(cartProvider);
    final result = await service.checkout(
      cart: state.items,
      discount: state.discount,
      customerName: _nameController.text,
      customerPhone: _phoneController.text,
      saleType: state.saleType,
      paymentMethod: paymentMethod,
      referenceNote: _noteController.text,
      userId: userId,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    result.when(
      ok: (sale) {
        cart.clear();
        // Explicit, not just relying on dashboardChangeTicker to have
        // caught this write reactively - the dashboard may not have
        // been mounted/watching at all during checkout, and this
        // guarantees a fresh read the moment we land back on it
        // regardless of that.
        ref.invalidate(dashboardDataProvider);
        // go() alone would replace the whole stack with just the
        // receipt, leaving no way back to the dashboard - collapse to
        // the dashboard first, then push the receipt on top of it.
        context.go('/');
        context.push('/receipt/${sale.id}');
      },
      failure: (message) => _showError(message),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final cart = ref.read(cartProvider.notifier);
    final userId = ref.watch(sessionProvider)?.id;
    final discount = cartState.discount;
    final total = discount > cartState.subtotal ? const Money.zero() : cartState.subtotal - discount;
    final isExternal = cartState.paymentMethod == 'mpesa' || cartState.paymentMethod == 'mpesa_manual';

    return Scaffold(
      appBar: AppBar(title: const Text('Cart & Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (cartState.isEmpty) const Text('Your cart is empty.'),
          for (var i = 0; i < cartState.items.length; i++)
            Card(
              child: ListTile(
                title: Text(cartState.items[i].name),
                subtitle: Text('${cartState.items[i].unitPrice.format()} each'),
                leading: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => cart.updateQuantity(i, cartState.items[i].quantity - 1),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${cartState.items[i].quantity}'),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => cart.updateQuantity(i, cartState.items[i].quantity + 1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => cart.removeAt(i),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('Sale type', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Retail'),
                selected: cartState.saleType == 'retail',
                onSelected: (_) => cart.setSaleType('retail'),
              ),
              ChoiceChip(
                label: const Text('Wholesale'),
                selected: cartState.saleType == 'wholesale',
                onSelected: (_) => cart.setSaleType('wholesale'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Customer name (optional)'),
            onChanged: cart.setCustomerName,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Customer phone (optional)'),
            keyboardType: TextInputType.phone,
            onChanged: cart.setCustomerPhone,
          ),
          const SizedBox(height: 16),
          Text('Payment method', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _paymentMethodLabels.entries
                .map((entry) => ChoiceChip(
                      label: Text(entry.value),
                      selected: cartState.paymentMethod == entry.key,
                      onSelected: (_) => cart.setPaymentMethod(entry.key),
                    ))
                .toList(),
          ),
          if (isExternal) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Reference note (optional)'),
              onChanged: cart.setReferenceNote,
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _discountController,
            decoration: const InputDecoration(labelText: 'Discount'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) => cart.setDiscount(Money.fromMajor(double.tryParse(value.trim()) ?? 0)),
          ),
          const SizedBox(height: 16),
          _TotalsRow(label: 'Subtotal', value: cartState.subtotal),
          _TotalsRow(label: 'Discount', value: discount),
          _TotalsRow(label: 'Total', value: total, emphasize: true),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: (_submitting || cartState.isEmpty || userId == null)
                ? null
                : () => _submit(cart, cartState.paymentMethod, userId),
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Complete Sale'),
          ),
        ),
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  final String label;
  final Money value;
  final bool emphasize;

  const _TotalsRow({required this.label, required this.value, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value.format(), style: style)],
      ),
    );
  }
}
