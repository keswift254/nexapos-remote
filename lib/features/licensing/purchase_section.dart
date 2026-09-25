import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/licensing/license_gateway.dart';
import '../../domain/services/license_purchase_service.dart';

String _shillings(int amount) => 'KSh ${NumberFormat.decimalPattern().format(amount)}';

/// The plans on the activation screen: tap one, pay on Paystack's page (card or
/// M-Pesa), and this device is activated by itself when the payment is
/// confirmed - no key to type. Prices and lengths come from the license server;
/// nothing here decides them. A payment left half-done (the app was closed on
/// the payment page) is offered back as a "Payment in progress" card.
///
/// Never gets in the way of the license-key field below it: with no internet, or
/// before the vendor's payment account is set up, this just says so and the key
/// still works.
class PurchaseSection extends ConsumerStatefulWidget {
  const PurchaseSection({super.key, required this.onActivated});

  /// Called once a purchase has activated this device - the activation screen
  /// uses it to run the same follow-up as after typing a key.
  final VoidCallback onActivated;

  @override
  ConsumerState<PurchaseSection> createState() => _PurchaseSectionState();
}

class _PurchaseSectionState extends ConsumerState<PurchaseSection> {
  PlanCatalog? _catalog;
  bool _loadingPlans = true;
  String? _plansError;
  PendingPurchase? _pending;
  String? _startingPlanId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPending();
    _loadPlans();
  }

  Future<void> _loadPending() async {
    PendingPurchase? pending;
    try {
      pending = await ref.read(licensePurchaseServiceProvider).pending();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _pending = pending);
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loadingPlans = true;
      _plansError = null;
    });
    try {
      final catalog = await ref.read(licensePurchaseServiceProvider).loadPlans();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loadingPlans = false;
      });
    } on LicenseOfflineException {
      if (!mounted) return;
      setState(() {
        _loadingPlans = false;
        _plansError = "Couldn't load the plans - check your internet connection.";
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingPlans = false;
        _plansError = "Couldn't load the plans right now.";
      });
    }
  }

  Future<void> _buy(PurchasePlan plan) async {
    final service = ref.read(licensePurchaseServiceProvider);
    final email = await showDialog<String>(
      context: context,
      builder: (_) => _EmailDialog(
        plan: plan,
        initialEmail: null,
        lastEmail: service.lastEmail(),
      ),
    );
    if (email == null || !mounted) return;

    setState(() {
      _startingPlanId = plan.id;
      _error = null;
    });
    try {
      final purchase = await service.start(plan, email);
      if (!mounted) return;
      setState(() {
        _startingPlanId = null;
        _pending = purchase;
      });
      // A browser blocks a page opened after a wait; there the person opens it
      // with a tap in the next step. Everywhere else it opens by itself.
      await _wait(purchase, openPage: !kIsWeb);
    } on LicenseOfflineException {
      if (!mounted) return;
      setState(() {
        _startingPlanId = null;
        _error = 'Could not reach the server. Check your internet connection and try again.';
      });
    } on LicenseException catch (e) {
      if (!mounted) return;
      setState(() {
        _startingPlanId = null;
        _error = e.message;
      });
    }
  }

  Future<void> _wait(PendingPurchase purchase, {required bool openPage}) async {
    final outcome = await showDialog<PurchaseCheckKind>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentDialog(purchase: purchase, openPageAtStart: openPage),
    );
    if (!mounted) return;
    if (outcome == PurchaseCheckKind.activated) {
      widget.onActivated();
      return;
    }
    await _loadPending();
  }

  Future<void> _forget(PendingPurchase purchase) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forget this payment?'),
        content: Text(
          'If you have already paid, do not forget it - tap "Check payment" '
          'instead. If you need help, contact NexaPOS with this reference:\n\n'
          '${purchase.reference}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Forget it'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await ref.read(licensePurchaseServiceProvider).cancel();
    await _loadPending();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalog = _catalog;
    final pending = _pending;
    final busy = _startingPlanId != null;
    final canPay = catalog?.purchasingEnabled == true && pending == null && !busy;

    final children = <Widget>[];

    if (pending != null) {
      children.add(
        Card(
          key: const Key('purchase-in-progress'),
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment in progress', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '${_shillings(pending.amountKes)} for ${pending.planLabel}. '
                  'If you have paid, tap Check payment and this device activates '
                  'by itself.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    FilledButton(
                      key: const Key('check-payment'),
                      onPressed: () => _wait(pending, openPage: false),
                      child: const Text('Check payment'),
                    ),
                    TextButton(
                      key: const Key('forget-payment'),
                      onPressed: () => _forget(pending),
                      child: const Text('Forget it'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      children.add(const SizedBox(height: 12));
    }

    children.add(
      Text(
        'Choose a plan',
        style: theme.textTheme.titleMedium,
        textAlign: TextAlign.center,
      ),
    );
    children.add(const SizedBox(height: 4));
    children.add(
      Text(
        'Pay securely with Paystack - card or M-Pesa. This device activates '
        'by itself, no key to type.',
        style: theme.textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
    children.add(const SizedBox(height: 12));

    if (_loadingPlans) {
      children.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    } else if (catalog == null || catalog.plans.isEmpty) {
      children.add(
        Column(
          children: [
            Text(
              _plansError ?? "Plans aren't available right now.",
              key: const Key('plans-error'),
              textAlign: TextAlign.center,
            ),
            TextButton(
              key: const Key('retry-plans'),
              onPressed: _loadPlans,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    } else {
      final cheapestPerMonth = catalog.plans
          .map((p) => p.amountKes / p.months)
          .reduce((a, b) => a < b ? a : b);
      final cheapest = catalog.plans
          .where((p) => p.amountKes / p.months == cheapestPerMonth)
          .toList();
      for (final plan in catalog.plans) {
        children.add(
          _PlanCard(
            plan: plan,
            bestValue: catalog.plans.length > 1 &&
                cheapest.length == 1 &&
                cheapest.single.id == plan.id,
            starting: _startingPlanId == plan.id,
            enabled: canPay,
            onTap: () => _buy(plan),
          ),
        );
        children.add(const SizedBox(height: 8));
      }
      if (!catalog.purchasingEnabled) {
        children.add(
          Text(
            "Online payment isn't available yet. Use a license key below, or "
            'chat with us on WhatsApp.',
            key: const Key('payments-unavailable'),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        );
      }
    }

    if (_error != null) {
      children.add(const SizedBox(height: 8));
      children.add(
        Text(
          _error!,
          key: const Key('purchase-error'),
          style: TextStyle(color: theme.colorScheme.error),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.bestValue,
    required this.starting,
    required this.enabled,
    required this.onTap,
  });

  final PurchasePlan plan;
  final bool bestValue;
  final bool starting;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perMonth = (plan.amountKes / plan.months).round();
    return Card(
      key: Key('plan-${plan.id}'),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A Wrap, not a Row: on a narrow screen the badge drops under
                    // the label instead of running off the edge.
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          plan.label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (bestValue) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Best value',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${_shillings(perMonth)} a month',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              starting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : FilledButton(
                      key: Key('pay-${plan.id}'),
                      onPressed: enabled ? onTap : null,
                      child: Text(_shillings(plan.amountKes)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paystack sends the receipt to an email address, so one is needed. Offers the
/// address last paid with.
class _EmailDialog extends StatefulWidget {
  const _EmailDialog({
    required this.plan,
    required this.initialEmail,
    required this.lastEmail,
  });

  final PurchasePlan plan;
  final String? initialEmail;
  final Future<String?> lastEmail;

  @override
  State<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<_EmailDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialEmail ?? '',
  );

  @override
  void initState() {
    super.initState();
    widget.lastEmail.then((email) {
      if (!mounted || email == null || _controller.text.isNotEmpty) return;
      _controller.text = email;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.plan.label} - ${_shillings(widget.plan.amountKes)}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Where should Paystack send your receipt? You will pay on the '
              'next page, by card or M-Pesa.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('purchase-email'),
              controller: _controller,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Email address'),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Enter your email address';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('purchase-continue'),
          onPressed: _submit,
          child: const Text('Continue to payment'),
        ),
      ],
    );
  }
}

/// Watches a payment until it is settled: opens Paystack's page, then asks the
/// server every few seconds. Closes itself with the outcome. Closing it by hand
/// leaves the payment remembered (see "Payment in progress"), never lost.
class _PaymentDialog extends ConsumerStatefulWidget {
  const _PaymentDialog({required this.purchase, required this.openPageAtStart});

  final PendingPurchase purchase;
  final bool openPageAtStart;

  @override
  ConsumerState<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<_PaymentDialog> {
  static const _pollEvery = Duration(seconds: 3);

  Timer? _timer;
  bool _checking = false;
  PurchaseCheck _last = const PurchaseCheck(PurchaseCheckKind.pending);

  @override
  void initState() {
    super.initState();
    if (widget.openPageAtStart) {
      unawaited(ref.read(licensePurchaseServiceProvider).openPaymentPage(widget.purchase));
    }
    _timer = Timer.periodic(_pollEvery, (_) => _check());
    unawaited(_check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      final result = await ref.read(licensePurchaseServiceProvider).check();
      if (!mounted) return;
      setState(() => _last = result);
      if (result.kind == PurchaseCheckKind.activated) {
        _timer?.cancel();
        Navigator.pop(context, PurchaseCheckKind.activated);
      } else if (result.kind == PurchaseCheckKind.failed) {
        _timer?.cancel();
      }
    } finally {
      _checking = false;
    }
  }

  String get _status => switch (_last.kind) {
    PurchaseCheckKind.pending || PurchaseCheckKind.none =>
      widget.openPageAtStart
          ? 'Finish paying on the Paystack page that just opened. This updates by itself - no need to come back and tap anything.'
          : 'Finish paying on the Paystack page (tap "Open payment page" if you closed it). This updates by itself.',
    PurchaseCheckKind.offline => _last.message ?? 'Waiting for a connection...',
    PurchaseCheckKind.problem => _last.message ?? 'Something went wrong. Trying again...',
    PurchaseCheckKind.failed => _last.message ?? 'The payment did not go through.',
    PurchaseCheckKind.activated => 'Payment confirmed - activating...',
  };

  @override
  Widget build(BuildContext context) {
    final failed = _last.kind == PurchaseCheckKind.failed;
    return AlertDialog(
      key: const Key('payment-dialog'),
      title: Text(failed ? 'Payment not completed' : 'Waiting for your payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_shillings(widget.purchase.amountKes)} - ${widget.purchase.planLabel}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (!failed) ...[const LinearProgressIndicator(), const SizedBox(height: 12)],
          Text(_status, key: const Key('payment-status')),
          if (!failed) ...[
            const SizedBox(height: 12),
            Text(
              'Closing this does not cancel anything - you can come back to it '
              'from this screen.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        if (!failed) ...[
          TextButton(
            key: const Key('open-payment-page'),
            onPressed: () => ref
                .read(licensePurchaseServiceProvider)
                .openPaymentPage(widget.purchase),
            child: const Text('Open payment page'),
          ),
          TextButton(
            key: const Key('check-now'),
            onPressed: _check,
            child: const Text('Check now'),
          ),
        ],
        TextButton(
          key: const Key('close-payment'),
          onPressed: () => Navigator.pop(context, _last.kind),
          child: Text(failed ? 'Choose a plan' : 'Close'),
        ),
      ],
    );
  }
}
