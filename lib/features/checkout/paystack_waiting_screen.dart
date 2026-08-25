import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/services/paystack_payment_service.dart';
import '../dashboard/dashboard_screen.dart';

const _pollInterval = Duration(seconds: 4);
const _maxAutoPolls = 75; // ~5 minutes

/// Shown after PaystackPaymentService.start() succeeds: opens the
/// gateway's checkout page in the system browser (no in-app WebView -
/// see the plan notes on why a browser redirect is simpler and more
/// portable than embedding one), then polls for confirmation. Stock was
/// already reserved when the sale was recorded as pending, so this
/// screen's only two honest outcomes are "Paystack confirmed it" or
/// "the cashier explicitly cancelled" - see PaystackPaymentService.poll
/// for why a stalled/ambiguous check is never treated as failure on
/// its own.
class PaystackWaitingScreen extends ConsumerStatefulWidget {
  final PaystackCheckoutSession session;

  const PaystackWaitingScreen({super.key, required this.session});

  @override
  ConsumerState<PaystackWaitingScreen> createState() => _PaystackWaitingScreenState();
}

class _PaystackWaitingScreenState extends ConsumerState<PaystackWaitingScreen> with WidgetsBindingObserver {
  Timer? _timer;
  int _attempts = 0;
  bool _autoPollingStopped = false;
  bool _checkingNow = false;
  bool _cancelling = false;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openCheckoutPage();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  /// The checkout page opens in the system browser, not embedded in
  /// this app (see the class doc) - there's no callback URL wiring the
  /// browser back to us, so the OS never automatically refocuses
  /// NexaPOS once the customer finishes paying. The next best thing:
  /// the instant the cashier switches back to this app (alt-tab, or
  /// backgrounding on mobile), check immediately rather than waiting
  /// for the next scheduled poll tick.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNow();
    }
  }

  Future<void> _openCheckoutPage() async {
    final uri = Uri.parse(widget.session.authorizationUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _poll() async {
    if (_resolved || _checkingNow) return;
    setState(() => _checkingNow = true);

    final outcome = await ref.read(paystackPaymentServiceProvider).poll(
          widget.session.sale.id,
          widget.session.reference,
          widget.session.sale.total,
        );

    if (!mounted) return;
    _attempts++;

    if (outcome is PaystackPollPaid) {
      _resolved = true;
      _timer?.cancel();
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
    await _poll();
    if (!mounted || _resolved) return;
    if (!_autoPollingStopped) {
      _timer = Timer.periodic(_pollInterval, (_) => _poll());
    }
  }

  Future<void> _cancelSale() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this sale?'),
        content: const Text(
          'The reserved stock will be returned and this sale will be marked cancelled. '
          'Only do this if the customer did not complete the Paystack payment.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep waiting')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel sale')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    _timer?.cancel();
    final result = await ref.read(paystackPaymentServiceProvider).cancel(widget.session.sale.id);
    if (!mounted) return;
    _resolved = true;
    result.when(
      ok: (_) => context.go('/'),
      failure: (message) {
        setState(() => _cancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        appBar: AppBar(title: const Text('Paystack payment')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Sale ${widget.session.sale.saleNumber}', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Total: ${widget.session.sale.total.format()}'),
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  _autoPollingStopped
                      ? 'Still waiting for confirmation. Check again once the customer has paid.'
                      : 'Waiting for the customer to complete payment in the browser. '
                          'Once they\'re done, switch back to this screen - it checks automatically.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _openCheckoutPage,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Open checkout page again'),
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
