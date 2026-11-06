import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/services/paystack_payment_service.dart';
import '../../domain/services/pending_sales_notifier.dart';
import '../dashboard/dashboard_screen.dart';
import '../../core/checkout_return_bridge.dart';
import '../../core/is_web.dart';
import '../../core/payment_page_navigation.dart';
import '../../core/payment_return_signals.dart';

const _pollInterval = Duration(seconds: 3);
const _maxAutoPolls = 100; // ~5 minutes

/// Several "the customer is back" cues usually arrive together (the page
/// becoming visible, regaining focus, the return page announcing itself).
/// They are folded into one check.
const _cueSettle = Duration(milliseconds: 150);

/// Opens the gateway's checkout page. Web builds navigate this same tab,
/// because a popup opened after the network call is blocked by Safari.
typedef CheckoutPageOpener = Future<void> Function(Uri checkoutUrl);

Future<void> _openCheckoutPageDefault(Uri uri, {required bool web}) async {
  if (web) {
    // Same tab, and keep the history entry so the browser's Back button from
    // the payment page lands back in NexaPOS.
    await replaceWithPaymentPage(uri, replace: false);
    return;
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Shown after PaystackPaymentService.start() succeeds: opens the
/// gateway's checkout page (the system browser on native builds, this same
/// tab on web - no in-app WebView, see the plan notes on why a browser
/// redirect is simpler and more portable than embedding one), then polls
/// for confirmation. Stock was already reserved when the sale was recorded
/// as pending, so this screen's only two honest outcomes are "Paystack
/// confirmed it" or "the cashier explicitly cancelled" - see
/// PaystackPaymentService.poll for why a stalled/ambiguous check is never
/// treated as failure on its own.
class PaystackWaitingScreen extends ConsumerStatefulWidget {
  final PaystackCheckoutSession session;

  /// For tests: replaces opening the real payment page.
  @visibleForTesting
  final CheckoutPageOpener? openCheckoutPage;

  /// For tests: behave as the web build even though the VM is not a browser.
  @visibleForTesting
  final bool? forWeb;

  const PaystackWaitingScreen({
    super.key,
    required this.session,
    this.openCheckoutPage,
    this.forWeb,
  });

  @override
  ConsumerState<PaystackWaitingScreen> createState() =>
      _PaystackWaitingScreenState();
}

class _PaystackWaitingScreenState extends ConsumerState<PaystackWaitingScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  Timer? _cueTimer;
  PaymentReturnSignals? _returnSignals;
  late final PendingPaystackSalesNotifier _pendingSales;
  int _attempts = 0;
  int _checkGeneration = 0;
  bool _autoPollingStopped = false;
  bool _checkingNow = false;
  bool _cancelling = false;
  bool _resolved = false;

  bool get _web => widget.forWeb ?? isWeb;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CheckoutReturnBridge.signal.addListener(_cue);
    _returnSignals = PaymentReturnSignals(_cue);
    // Read now: the screen may be torn down (a logout, for one) while the sale
    // is still unpaid, and a ref is not safe to use from dispose().
    _pendingSales = ref.read(pendingPaystackSalesProvider.notifier);
    _openCheckoutPage();
    _restartTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CheckoutReturnBridge.signal.removeListener(_cue);
    _returnSignals?.dispose();
    _timer?.cancel();
    _cueTimer?.cancel();
    // Left without being paid or cancelled: hand the sale to the app-wide
    // pending-payment watcher, which keeps checking it from the dashboard.
    if (!_resolved) unawaited(_pendingSales.reconcile());
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  /// The browser return link (or the page coming back into view) resumes this
  /// screen. Treat it only as a cue to verify the transaction with the server,
  /// never as proof of payment.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _cue();
  }

  void _cue() {
    if (_resolved || (_cueTimer?.isActive ?? false)) return;
    _cueTimer = Timer(_cueSettle, _checkNow);
  }

  Future<void> _openCheckoutPage() async {
    final uri = Uri.parse(widget.session.authorizationUrl);
    final opener = widget.openCheckoutPage;
    if (opener != null) {
      await opener(uri);
      return;
    }
    await _openCheckoutPageDefault(uri, web: _web);
  }

  /// One status check. A timer tick is skipped while a check is already in
  /// flight, but a [force]d check (the customer is back) always goes ahead:
  /// browsers hold back network requests of a page that was in the background,
  /// so the check still "in flight" from before is usually stalled, and waiting
  /// for it would be exactly the delay the cashier sees.
  Future<void> _poll({bool force = false}) async {
    if (!mounted || _resolved) return;
    if (_checkingNow && !force) return;
    final generation = ++_checkGeneration;
    setState(() => _checkingNow = true);

    final outcome = await ref
        .read(paystackPaymentServiceProvider)
        .poll(
          widget.session.sale.id,
          widget.session.reference,
          widget.session.sale.gatewayPortion,
        );

    // A newer check took over while this one was stalled; its answer counts.
    if (!mounted || generation != _checkGeneration) return;
    _attempts++;

    if (outcome is PaystackPollPaid) {
      _resolved = true;
      _timer?.cancel();
      _cueTimer?.cancel();
      setState(() => _checkingNow = false);
      // Explicit, not just relying on dashboardChangeTicker to have
      // caught this write reactively - see cart_screen.dart's identical
      // comment. Particularly relevant here: this whole flow just spent
      // time with the app backgrounded for the external checkout page,
      // exactly the kind of window a purely reactive subscription could
      // miss something during.
      ref.invalidate(dashboardDataProvider);
      // Same reasoning as cart_screen.dart's success handler: collapse
      // to the dashboard first so the receipt isn't left as the only
      // thing on the stack.
      context.go('/');
      context.push('/receipt/${outcome.sale.id}');
      return;
    }

    setState(() {
      _checkingNow = false;
      if (_attempts >= _maxAutoPolls) {
        _autoPollingStopped = true;
        _timer?.cancel();
      }
    });
  }

  Future<void> _checkNow() async {
    _timer?.cancel();
    await _poll(force: true);
    if (!mounted || _resolved) return;
    if (!_autoPollingStopped) _restartTimer();
  }

  Future<void> _cancelSale() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this sale?'),
        content: const Text(
          'The reserved stock will be returned and this sale will be marked cancelled. '
          'Only do this if the customer did not complete the payment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep waiting'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel sale'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    _timer?.cancel();
    final result = await ref
        .read(paystackPaymentServiceProvider)
        .cancel(widget.session.sale.id);
    if (!mounted) return;
    _resolved = true;
    result.when(
      ok: (_) => context.go('/'),
      failure: (message) {
        setState(() => _cancelling = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _cancelSale();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('M-Pesa Prompt')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sale ${widget.session.sale.saleNumber}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (widget.session.sale.isSplitPayment) ...[
                  Text('Cash already received: ${widget.session.sale.cashReceived!.format()}'),
                  Text('M-Pesa amount: ${widget.session.sale.gatewayPortion.format()}'),
                ] else
                  Text('Total: ${widget.session.sale.total.format()}'),
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  _autoPollingStopped
                      ? 'Still waiting for confirmation. Check again once the customer has paid.'
                      : 'Waiting for payment confirmation.',
                  textAlign: TextAlign.center,
                ),
                if (_web && !_autoPollingStopped) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'The payment page opens in this window. When the customer '
                    'has paid, you come back here.',
                    key: Key('web-payment-hint'),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  key: const Key('open-checkout-page'),
                  onPressed: _openCheckoutPage,
                  icon: const Icon(Icons.open_in_browser),
                  label: Text(
                    _web ? 'Open payment page' : 'Open checkout page again',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _checkingNow ? null : _checkNow,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check now'),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _cancelling ? null : _cancelSale,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel sale'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
