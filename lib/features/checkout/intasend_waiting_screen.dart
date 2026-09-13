import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/services/intasend_payment_service.dart';
import '../dashboard/dashboard_screen.dart';

const _pollInterval = Duration(seconds: 4);
const _maxAutoPolls = 75; // ~5 minutes

/// Shown after IntaSendPaymentService.start() succeeds. Unlike
/// PaystackWaitingScreen, there is no checkout page to open - the STK
/// prompt goes straight to the customer's own phone and this device
/// never leaves the app, so there's no app-lifecycle/external-browser
/// handling to do here, just polling. Stock was already reserved when
/// the sale was recorded as pending, so this screen's only two honest
/// outcomes are "IntaSend confirmed it" or "the cashier explicitly
/// cancelled" - see IntaSendPaymentService.poll.
class IntaSendWaitingScreen extends ConsumerStatefulWidget {
  final IntaSendCheckoutSession session;

  const IntaSendWaitingScreen({super.key, required this.session});

  @override
  ConsumerState<IntaSendWaitingScreen> createState() => _IntaSendWaitingScreenState();
}

class _IntaSendWaitingScreenState extends ConsumerState<IntaSendWaitingScreen> {
  Timer? _timer;
  int _attempts = 0;
  bool _autoPollingStopped = false;
  bool _checkingNow = false;
  bool _cancelling = false;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_resolved || _checkingNow) return;
    setState(() => _checkingNow = true);

    final outcome = await ref
        .read(intaSendPaymentServiceProvider)
        .poll(
          widget.session.sale.id,
          widget.session.reference,
          widget.session.sale.total,
        );

    if (!mounted) return;
    _attempts++;

    if (outcome is IntaSendPollPaid) {
      _resolved = true;
      _timer?.cancel();
      setState(() => _checkingNow = false);
      ref.invalidate(dashboardDataProvider);
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
          'Only do this if the customer did not complete the IntaSend payment.',
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
    final result = await ref.read(intaSendPaymentServiceProvider).cancel(widget.session.sale.id);
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
        appBar: AppBar(title: const Text('IntaSend Prompt')),
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
                Text('Total: ${widget.session.sale.total.format()}'),
                const SizedBox(height: 8),
                Text('Prompt sent to ${widget.session.phoneNumber}'),
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  _autoPollingStopped
                      ? 'Still waiting for confirmation. Check again once the customer has entered their PIN.'
                      : 'Waiting for the customer to enter their M-Pesa PIN.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
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
