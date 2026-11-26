import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/payments/payment_inbox_gateway.dart';
import '../../data/payments/platform_http_client.dart';
import '../../data/payments/sms_forwarding.dart';
import '../../domain/entities/paystack_credentials.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/services/paystack_credentials_service.dart';
import '../../domain/services/session_service.dart';

/// Settings > M-Pesa Till Phone (administrators): the phone that passes the shop's M-Pesa payment messages on.
///
/// Customers pay the shop's own till or paybill; the phone that gets Safaricom's "payment received" message passes it on to
/// the shop (an iPhone through a Shortcut), and every till can then check a customer's code against the real message. Here an
/// administrator sets that phone up (with their own password, which the SHOP checks: whoever holds a phone's key could pass on
/// a made-up payment), sees the phones that are set up, removes one, and sees the payments that arrived - archived ones can be
/// suggested at checkout again. The same page as the Lite till's.
class TillPhoneScreen extends ConsumerStatefulWidget {
  const TillPhoneScreen({super.key, this.refreshEvery = const Duration(seconds: 20)});

  final Duration refreshEvery;

  @override
  ConsumerState<TillPhoneScreen> createState() => _TillPhoneScreenState();
}

class _TillPhoneScreenState extends ConsumerState<TillPhoneScreen> {
  static final _time = DateFormat('d MMM, h:mm a');

  PaystackCredentials? _credentials;
  List<TillPhone>? _phones;
  int _max = 5;
  List<TillPayment>? _payments;
  String? _problem;
  String? _paymentsProblem;
  TillPhoneKey? _newKey;
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(widget.refreshEvery, (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  PaymentInboxGateway get _gateway => ref.read(paymentInboxGatewayProvider);

  Future<PaystackCredentials?> _connected() async {
    final credentials = _credentials ?? await ref.read(paystackCredentialsServiceProvider).load();
    if (!credentials.isConfigured) {
      if (mounted) {
        setState(() {
          _phones ??= const [];
          _payments ??= const [];
          _problem = 'This device is not connected to the shop sync service yet. Open Settings > Sync & Invites while online.';
        });
      }
      return null;
    }
    _credentials = credentials;
    return credentials;
  }

  String _words(Object error) {
    if (error is PaystackOfflineException) return 'No internet. Try again when this device is online.';
    if (error is PaystackException) return error.message;
    return 'Something went wrong. Try again in a moment.';
  }

  Future<void> _load({bool quiet = false}) async {
    final credentials = await _connected();
    if (credentials == null || !mounted) return;
    try {
      final result = await _gateway.phones(baseUrl: credentials.baseUrl, apiKey: credentials.apiKey);
      if (!mounted) return;
      setState(() {
        _phones = result.phones;
        _max = result.max;
        _problem = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phones ??= const [];
        if (!quiet || _problem == null) _problem = _words(e);
      });
    }
    try {
      final result = await _gateway.list(baseUrl: credentials.baseUrl, apiKey: credentials.apiKey, hours: 24);
      if (!mounted) return;
      setState(() {
        _payments = result.payments;
        _paymentsProblem = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _payments ??= const [];
        if (!quiet || _paymentsProblem == null) _paymentsProblem = _words(e);
      });
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---- set a phone up -----------------------------------------------------------------------------------------------------

  /// [thisPhone]: the phone being set up is the one in hand (Android): its key goes straight to "M-Pesa messages from
  /// this phone" instead of being copied over.
  Future<void> _setUp({bool thisPhone = false}) async {
    final user = ref.read(sessionProvider);
    if (user == null) return;
    final answer = await showDialog<({String label, String password})>(
      context: context,
      builder: (_) => const _SetUpDialog(),
    );
    if (answer == null || !mounted) return;
    final credentials = await _connected();
    if (credentials == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final key = await _gateway.addPhone(
        baseUrl: credentials.baseUrl,
        apiKey: credentials.apiKey,
        label: answer.label,
        userId: user.id,
        password: answer.password,
      );
      if (!mounted) return;
      setState(() => _newKey = key);
      unawaited(_load(quiet: true));
      if (thisPhone) unawaited(context.push('/sms-forwarding', extra: key.key));
    } catch (e) {
      _say(_words(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _hideKey() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hide the key?'),
        content: const Text('It cannot be shown again. If the phone is not set up yet, you will have to remove it and set it up again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it on screen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hide the key')),
        ],
      ),
    );
    if (sure == true && mounted) setState(() => _newKey = null);
  }

  Future<void> _copy(String what, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    _say('$what copied.');
  }

  // ---- remove a phone -----------------------------------------------------------------------------------------------------

  Future<void> _remove(TillPhone phone) async {
    final user = ref.read(sessionProvider);
    if (user == null) return;
    final password = await showDialog<String>(
      context: context,
      builder: (_) => _RemoveDialog(label: phone.label),
    );
    if (password == null || !mounted) return;
    final credentials = await _connected();
    if (credentials == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final left = await _gateway.removePhone(
        baseUrl: credentials.baseUrl,
        apiKey: credentials.apiKey,
        phoneId: phone.id,
        userId: user.id,
        password: password,
      );
      if (!mounted) return;
      setState(() => _phones = left);
      _say('Phone removed. Its key no longer works.');
    } catch (e) {
      _say(_words(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- suggest an archived payment again ----------------------------------------------------------------------------------

  Future<void> _suggestAgain(TillPayment payment) async {
    final credentials = await _connected();
    if (credentials == null || !mounted) return;
    try {
      await _gateway.archive(baseUrl: credentials.baseUrl, apiKey: credentials.apiKey, code: payment.code, archived: false);
      _say('${payment.payerName.isEmpty ? payment.code : payment.payerName} is suggested at checkout again.');
      await _load(quiet: true);
    } catch (e) {
      _say(_words(e));
    }
  }

  // ---- the page -----------------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);
    final theme = Theme.of(context);
    if (user == null || user.role != UserRole.admin) {
      return Scaffold(
        appBar: AppBar(title: const Text('M-Pesa Till Phone')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Only an administrator of the shop can set up the M-Pesa till phone.'),
        ),
      );
    }
    final phones = _phones;
    final payments = _payments;
    final full = phones != null && phones.length >= _max;
    return Scaffold(
      appBar: AppBar(
        title: const Text('M-Pesa Till Phone'),
        actions: [IconButton(key: const Key('till-phone-refresh'), icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _load)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customers pay your own M-Pesa till or paybill, so the money reaches you straight away. The phone that gets '
                    'Safaricom\'s payment message passes it on to NexaPOS, and your tills can then check a customer\'s M-Pesa code '
                    'against the real message.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Only payments you receive are kept. Your balance, and anything you send or withdraw, is dropped unread.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          if (_problem != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_problem!, key: const Key('till-phone-problem'), style: TextStyle(color: theme.colorScheme.error)),
            ),
          if (_newKey case final key?) _KeyCard(newKey: key, onCopy: _copy, onHide: _hideKey),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Phones', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (phones == null)
                    const Text('Loading...')
                  else if (phones.isEmpty)
                    const Text('No phone is set up yet.')
                  else
                    for (final phone in phones)
                      ListTile(
                        key: Key('till-phone-${phone.id}'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.phone_iphone),
                        title: Text(phone.label),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text([
                              'Added${phone.addedBy.isEmpty ? '' : ' by ${phone.addedBy}'}'
                                  '${phone.addedAt == null ? '' : ' on ${_time.format(phone.addedAt!.toLocal())}'}',
                              phone.lastMessageAt == null
                                  ? 'No message from this phone yet'
                                  : 'Last message: ${_time.format(phone.lastMessageAt!.toLocal())}',
                            ].join('\n')),
                            Text(
                              phone.senderCheck
                                  ? 'Sender check on: a message typed by a person and sent from their own number is never '
                                      'taken as a payment.'
                                  : 'Sender check off: add the "sender" field to this phone\'s Shortcut (see the set-up '
                                      'page, step 2), so a message a person types and sends from their own number is never '
                                      'taken as a payment.',
                              key: Key('till-phone-sender-${phone.id}'),
                              style: TextStyle(
                                color: phone.senderCheck ? Colors.green.shade800 : theme.colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                        trailing: OutlinedButton(
                          onPressed: _busy ? null : () => _remove(phone),
                          child: const Text('Remove'),
                        ),
                      ),
                  if (full)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('This shop has $_max phones set up, which is the most. Remove one to set up another.',
                          style: theme.textTheme.bodySmall),
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const Key('till-phone-set-up'),
                    onPressed: (_busy || full || phones == null) ? null : _setUp,
                    icon: const Icon(Icons.add),
                    label: const Text('Set up a phone'),
                  ),
                  // On an Android phone that itself gets the till's messages: set it up and switch passing on on here.
                  if (smsForwardingSupported) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('till-phone-use-this-phone'),
                      onPressed: (_busy || full || phones == null) ? null : () => _setUp(thisPhone: true),
                      icon: const Icon(Icons.sms_outlined),
                      label: const Text('Use this phone (Android)'),
                    ),
                    TextButton(
                      key: const Key('till-phone-this-phone-status'),
                      onPressed: () => context.push('/sms-forwarding'),
                      child: const Text('M-Pesa messages from this phone'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Payments received', style: theme.textTheme.titleMedium),
                  Text('The last 24 hours, newest first. The list updates by itself.', style: theme.textTheme.bodySmall),
                  if (_paymentsProblem != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_paymentsProblem!, style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  const SizedBox(height: 8),
                  if (payments == null)
                    const Text('Loading...')
                  else if (payments.isEmpty)
                    const Text('Nothing yet. A payment shows here a few seconds after its M-Pesa message reaches the phone.')
                  else
                    for (final payment in payments) _paymentTile(payment, theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentTile(TillPayment p, ThemeData theme) {
    if (!p.messageReceived) {
      return ListTile(
        key: Key('till-received-${p.code}'),
        contentPadding: EdgeInsets.zero,
        title: const Text('Code typed at a till'),
        subtitle: Text([
          [p.code, if (p.usedOnSaleNumber != null) 'Sale ${p.usedOnSaleNumber}'].join(' · '),
          'No M-Pesa message has arrived for this code.',
        ].join('\n')),
        trailing: Text(p.usedAmount?.format() ?? ''),
      );
    }
    final status = p.isUsed
        ? 'Used on sale ${p.usedOnSaleNumber}'
            '${p.usedAmount != null && p.amount != null && p.usedAmount != p.amount ? ' (the sale was ${p.usedAmount!.format()})' : ''}'
        : (p.isArchived ? 'Archived: not suggested at checkout' : 'Not used on a sale yet');
    // A plain row rather than a ListTile: an archived payment carries a "Suggest again" button, which does not fit in a
    // list row's trailing space beside the amount.
    return Padding(
      key: Key('till-received-${p.code}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.payerName.isEmpty ? 'M-Pesa payment' : p.payerName, style: theme.textTheme.titleSmall),
                Text(
                  [
                    p.code,
                    if (p.payerPhone.isNotEmpty) p.payerPhone,
                    if (p.accountRef.isNotEmpty) 'Account ${p.accountRef}',
                    if (p.paidAtText.isNotEmpty) p.paidAtText else if (p.receivedAt != null) _time.format(p.receivedAt!.toLocal()),
                    if (p.phoneLabel.isNotEmpty) 'via ${p.phoneLabel}',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
                Text(status, style: theme.textTheme.bodySmall),
                if (p.isArchived && !p.isUsed)
                  TextButton(
                    key: Key('till-suggest-${p.code}'),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                    onPressed: () => _suggestAgain(p),
                    child: const Text('Suggest again'),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(p.amount?.format() ?? 'Amount not read', style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

/// The new phone's key, shown once: a code the phone's camera scans (it opens the set-up page with the steps), and the
/// address and key to copy by hand.
class _KeyCard extends StatelessWidget {
  const _KeyCard({required this.newKey, required this.onCopy, required this.onHide});

  final TillPhoneKey newKey;
  final Future<void> Function(String what, String value) onCopy;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget copyRow(String what, String value, Key key) => Row(
          children: [
            Expanded(
              child: SelectableText(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
            ),
            TextButton(key: key, onPressed: () => onCopy(what, value), child: const Text('Copy')),
          ],
        );
    return Card(
      key: const Key('till-phone-key-card'),
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Set up "${newKey.phone.label}"', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('This key is shown only once. Finish setting the phone up before you leave this page.',
                style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('On the phone that gets your M-Pesa payment messages, open the camera and point it at this code. '
                'It opens a page with the steps.'),
            const SizedBox(height: 12),
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(
                  key: const Key('till-phone-qr'),
                  data: newKey.setupPageLink,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Or copy these to the phone by hand:', style: theme.textTheme.bodySmall),
            Text('Address', style: theme.textTheme.labelLarge),
            copyRow('Address', newKey.address, const Key('till-phone-copy-address')),
            Text('Key', style: theme.textTheme.labelLarge),
            copyRow('Key', newKey.key, const Key('till-phone-copy-key')),
            const SizedBox(height: 8),
            FilledButton(key: const Key('till-phone-hide-key'), onPressed: onHide, child: const Text('Done - hide the key')),
          ],
        ),
      ),
    );
  }
}

class _SetUpDialog extends StatefulWidget {
  const _SetUpDialog();

  @override
  State<_SetUpDialog> createState() => _SetUpDialogState();
}

class _SetUpDialogState extends State<_SetUpDialog> {
  final _label = TextEditingController(text: 'Shop phone');
  final _password = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set up a phone'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('till-phone-label'),
            controller: _label,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Name for this phone'),
          ),
          TextField(
            key: const Key('till-phone-password'),
            controller: _password,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Your password',
              helperText: 'Your own NexaPOS password. Only an administrator can set a phone up.',
              helperMaxLines: 2,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          key: const Key('till-phone-create'),
          onPressed: () {
            if (_password.text.isEmpty) return;
            Navigator.pop(context, (label: _label.text.trim(), password: _password.text));
          },
          child: const Text('Create the key'),
        ),
      ],
    );
  }
}

class _RemoveDialog extends StatefulWidget {
  const _RemoveDialog({required this.label});
  final String label;

  @override
  State<_RemoveDialog> createState() => _RemoveDialogState();
}

class _RemoveDialogState extends State<_RemoveDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Remove "${widget.label}"?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Its key stops working at once: the phone must be set up again to pass messages on.'),
          TextField(
            key: const Key('till-phone-remove-password'),
            controller: _password,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Your password'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep it')),
        FilledButton(
          key: const Key('till-phone-remove-confirm'),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () {
            if (_password.text.isEmpty) return;
            Navigator.pop(context, _password.text);
          },
          child: const Text('Remove this phone'),
        ),
      ],
    );
  }
}
