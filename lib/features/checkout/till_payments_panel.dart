import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/money.dart';
import '../../data/payments/payment_inbox_gateway.dart';
import '../../data/payments/platform_http_client.dart';
import '../../domain/services/paystack_credentials_service.dart';

/// "M-Pesa Till/Paybill" in the cart: the payments the shop phone passed on that no sale has used yet (newest first, the
/// one equal to the sale total marked), refreshed by itself every few seconds while it is on screen. A tap puts that
/// payment's M-Pesa code in [codeController]; the code can also be typed.
class TillPaymentsPanel extends ConsumerStatefulWidget {
  const TillPaymentsPanel({
    super.key,
    required this.codeController,
    required this.codeFocus,
    required this.total,
    this.refreshEvery = const Duration(seconds: 8),
  });

  final TextEditingController codeController;
  final FocusNode codeFocus;
  final Money total;
  final Duration refreshEvery;

  @override
  ConsumerState<TillPaymentsPanel> createState() => TillPaymentsPanelState();
}

class TillPaymentsPanelState extends ConsumerState<TillPaymentsPanel> {
  Timer? _timer;
  List<TillPayment>? _payments;
  int? _phones;
  String? _problem;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.codeController.addListener(_codeChanged);
    reload();
    _timer = Timer.periodic(widget.refreshEvery, (_) => reload());
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.codeController.removeListener(_codeChanged);
    super.dispose();
  }

  void _codeChanged() {
    if (mounted) setState(() {});
  }

  /// Loads the list again (also called by the cart when a code turned out to be used or not there).
  Future<void> reload() async {
    if (_loading) return;
    _loading = true;
    try {
      final credentials = await ref.read(paystackCredentialsServiceProvider).load();
      if (!credentials.isConfigured) {
        if (mounted) {
          setState(() {
            _payments ??= const [];
            _problem = 'This device is not connected to the shop sync service yet. Open Settings > Sync & Invites while online.';
          });
        }
        return;
      }
      final result = await ref
          .read(paymentInboxGatewayProvider)
          .list(baseUrl: credentials.baseUrl, apiKey: credentials.apiKey, hours: 6);
      if (!mounted) return;
      setState(() {
        _payments = result.payments.where((p) => p.messageReceived && !p.isUsed && !p.isArchived).toList();
        _phones = result.phones;
        _problem = null;
      });
    } on PaystackOfflineException {
      if (mounted) {
        setState(() {
          _payments ??= const [];
          _problem = 'No internet: the payments cannot be loaded. Checking an M-Pesa payment needs the internet.';
        });
      }
    } on PaystackException catch (e) {
      if (mounted) {
        setState(() {
          _payments ??= const [];
          _problem = e.message;
        });
      }
    } catch (_) {
      // Anything else (the device's keys could not be read, say): said plainly, and tried again on the next refresh.
      if (mounted) {
        setState(() {
          _payments ??= const [];
          _problem = 'The payments could not be loaded. Try again in a moment.';
        });
      }
    } finally {
      _loading = false;
    }
  }

  static final _time = DateFormat('d MMM, h:mm a');

  /// Asked when a payment is swiped from right to left: archive it (no longer suggested here, still in the shop's list)?
  Future<bool> _confirmArchive(TillPayment payment) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive this payment?'),
        content: Text(
          'Are you sure you want to archive this payment?\n'
          '${payment.payerName.isEmpty ? 'M-Pesa payment' : payment.payerName}, '
          '${payment.amount == null ? '' : '${payment.amount!.format()}, '}${payment.code}\n\n'
          'It will no longer be suggested at checkout. You can still see it in NexaPOS Lite: Settings > M-Pesa Till Phone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Archive')),
        ],
      ),
    );
    if (yes != true || !mounted) return false;
    try {
      final credentials = await ref.read(paystackCredentialsServiceProvider).load();
      await ref.read(paymentInboxGatewayProvider).archive(baseUrl: credentials.baseUrl, apiKey: credentials.apiKey, code: payment.code);
    } on PaystackOfflineException {
      _say('No internet: the payment could not be archived. Try again when this device is online.');
      return false;
    } on PaystackException catch (e) {
      _say(e.message);
      return false;
    } catch (_) {
      _say('The payment could not be archived. Try again in a moment.');
      return false;
    }
    return true;
  }

  void _archived(TillPayment payment) {
    if (normalizeMpesaCode(widget.codeController.text) == payment.code) widget.codeController.clear();
    setState(() => _payments = [for (final p in _payments ?? const <TillPayment>[]) if (p.code != payment.code) p]);
    _say('Archived: ${payment.payerName.isEmpty ? payment.code : payment.payerName}. It is no longer suggested here.');
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final picked = normalizeMpesaCode(widget.codeController.text);
    final payments = _payments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'The customer pays your M-Pesa till or paybill from their phone. Their payment shows here a few seconds after the '
          'M-Pesa message reaches your shop phone: tap it, then Complete Sale. Needs the internet.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_problem!, key: const Key('till-problem'), style: TextStyle(color: theme.colorScheme.error)),
          )
        else if (_phones == 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'No shop phone passes M-Pesa messages on yet, so payments cannot be checked. An administrator sets one up in '
              'NexaPOS Lite: Settings > M-Pesa Till Phone.',
              key: const Key('till-no-phone'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        if (payments == null)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Loading the payments...'))
        else if (payments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No new payment yet. It shows here a few seconds after the M-Pesa message reaches the shop phone.'),
          )
        else
          for (final payment in payments)
            Dismissible(
              key: Key('till-swipe-${payment.code}'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => _confirmArchive(payment),
              onDismissed: (_) => _archived(payment),
              background: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.centerRight,
                decoration: BoxDecoration(color: theme.colorScheme.error, borderRadius: BorderRadius.circular(12)),
                child: Text('Archive', style: TextStyle(color: theme.colorScheme.onError, fontWeight: FontWeight.w700)),
              ),
              child: Card(
              key: Key('till-payment-${payment.code}'),
              margin: const EdgeInsets.only(bottom: 6),
              color: payment.code == picked ? theme.colorScheme.primaryContainer : null,
              shape: payment.code == picked
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.colorScheme.primary, width: 2),
                    )
                  : null,
              child: ListTile(
                dense: true,
                title: Text(payment.payerName.isEmpty ? 'M-Pesa payment' : payment.payerName),
                subtitle: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: [
                          payment.code,
                          if (payment.paidAtText.isNotEmpty)
                            payment.paidAtText
                          else if (payment.receivedAt != null)
                            _time.format(payment.receivedAt!.toLocal()),
                        ].join(' · '),
                      ),
                      if (payment.amount != null && payment.amount == widget.total)
                        TextSpan(
                          text: ' · the sale total',
                          style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
                trailing: Text(
                  payment.amount?.format() ?? '?',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  widget.codeController.text = payment.code;
                  setState(() {});
                },
              ),
            ),
            ),
        if (payments != null && payments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Swipe a payment to the left to archive it: it is no longer suggested here.', style: theme.textTheme.bodySmall),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('till-refresh'),
            onPressed: reload,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ),
        TextField(
          key: const Key('till-code'),
          controller: widget.codeController,
          focusNode: widget.codeFocus,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'M-Pesa code',
            hintText: 'Tap a payment above, or type the code',
            prefixIcon: Icon(Icons.receipt_long),
          ),
        ),
      ],
    );
  }
}
