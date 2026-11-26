import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../data/payments/sms_forwarding.dart';

/// "M-Pesa messages from this phone": an Android phone that gets the till's payment messages passes them on to the
/// shop, like the iPhone Shortcut does. Opened from Settings > M-Pesa Till Phone ("Use this phone", key filled in), or
/// from the first screen of a phone that does nothing else ("This phone only passes on M-Pesa messages").
class SmsForwardingScreen extends ConsumerStatefulWidget {
  const SmsForwardingScreen({super.key, this.initialKey, this.address, this.httpClient, this.supported});

  /// A key (or set-up link) to fill in.
  final String? initialKey;

  /// Where messages go; the shop's own address unless given.
  final String? address;

  /// For tests.
  final http.Client? httpClient;
  final bool? supported;

  @override
  ConsumerState<SmsForwardingScreen> createState() => _SmsForwardingScreenState();
}

class _SmsForwardingScreenState extends ConsumerState<SmsForwardingScreen> {
  late final TextEditingController _key = TextEditingController(text: widget.initialKey ?? '');
  late final http.Client _client = widget.httpClient ?? http.Client();
  SmsForwardingStatus? _status;
  bool _busy = false;
  String? _problem;
  String? _note;
  bool _permissionHelp = false;
  Timer? _timer;

  bool get _supported => widget.supported ?? smsForwardingSupported;
  String get _address => widget.address ?? paymentIngestAddress();
  SmsForwarding get _forwarding => ref.read(smsForwardingProvider);

  @override
  void initState() {
    super.initState();
    if (_supported) {
      unawaited(_refresh());
      _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _key.dispose();
    if (widget.httpClient == null) _client.close();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final status = await _forwarding.status();
      if (mounted) setState(() => _status = status);
    } on Object {
      // The next refresh tries again.
    }
  }

  Future<void> _turnOn() async {
    final key = tillPhoneKeyFrom(_key.text);
    setState(() {
      _problem = null;
      _note = null;
    });
    if (key == null) {
      setState(() => _problem = 'Paste the till phone key (it starts with npk_) or the set-up link the PC shows.');
      return;
    }
    setState(() => _busy = true);
    try {
      final check = await checkTillPhoneKey(_client, address: _address, key: key);
      if (check == TillKeyCheck.refused) {
        setState(() => _problem = 'The shop does not know this key. On the PC, open Settings > M-Pesa Till Phone and set '
            'up a phone again, then paste the new key.');
        return;
      }
      if (check == TillKeyCheck.unknown) {
        _note = 'The key could not be checked just now (no internet?). Messages wait on this phone and go as soon as it '
            'is online.';
      }
      final allowed = await _forwarding.requestPermission();
      if (!allowed) {
        setState(() {
          _permissionHelp = true;
          _problem = 'Android has not let NexaPOS receive text messages yet, so nothing was switched on.';
        });
        return;
      }
      final on = await _forwarding.enable(key: key, address: _address);
      if (!on) {
        setState(() => _problem = 'That is not a till phone key.');
        return;
      }
      _permissionHelp = false;
      await _refresh();
    } on Object catch (e) {
      setState(() => _problem = 'Could not switch it on: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _allowAgain() async {
    final allowed = await _forwarding.requestPermission();
    if (!allowed && mounted) setState(() => _permissionHelp = true);
    await _refresh();
  }

  Future<void> _turnOff() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop passing messages on?'),
        content: const Text('Payments to your till will no longer reach NexaPOS from this phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it on')),
          FilledButton(key: const Key('sms-turn-off-confirm'), onPressed: () => Navigator.pop(context, true), child: const Text('Stop')),
        ],
      ),
    );
    if (sure != true) return;
    await _forwarding.disable();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('M-Pesa messages from this phone')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_supported)
            const Card(
              key: Key('sms-not-android'),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Passing messages on from the phone itself works on Android phones. On an iPhone, use the Shortcut: on '
                  'the PC, open Settings > M-Pesa Till Phone and set up a phone - the page it shows explains the steps.',
                ),
              ),
            )
          else ...[
            // What to do first, then what went wrong right under it (on a phone the bottom of the page is out of
            // sight), and how it works last.
            _statusCard(theme),
            if (_permissionHelp || (_status?.enabled == true && _status?.permission == false)) _permissionHelpCard(theme),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How it works', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    const Text(
                      'This phone gets the M-Pesa (or bank) message when a customer pays your till or paybill. Switched '
                      'on, NexaPOS passes each payment message on to your shop, so your tills can check a customer\'s code '
                      'against the real message.\n\nOnly messages from MPESA and banks that mention Ksh, KES or Confirmed '
                      'leave the phone - never a message from a person\'s number. It works with NexaPOS closed; without '
                      'internet the messages wait and go later.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusCard(ThemeData theme) {
    final status = _status;
    if (status == null) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Checking...')));
    }
    if (status.enabled) {
      final working = status.working;
      return Card(
        key: const Key('sms-status-on'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(working ? Icons.check_circle : Icons.warning_amber_rounded,
                      color: working ? Colors.green.shade700 : theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      working ? 'On: payment messages are passed on' : 'On, but Android does not let it receive messages',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              if (status.keyEnd != null) Text('Key ending ...${status.keyEnd}', style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              Text('Last message', style: theme.textTheme.labelLarge),
              if (status.lastAt != null)
                Text('${DateFormat('d MMM, HH:mm').format(status.lastAt!)} from ${status.lastSender ?? 'unknown'}'),
              Text(smsForwardingResultWords(status.lastResult), key: const Key('sms-last-result')),
              if (status.waiting > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    status.waiting == 1 ? '1 message is waiting for internet.' : '${status.waiting} messages are waiting for internet.',
                    key: const Key('sms-waiting'),
                  ),
                ),
              Text('Payments passed on from this phone: ${status.passedOn}', style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!working)
                    FilledButton(key: const Key('sms-allow-again'), onPressed: _allowAgain, child: const Text('Allow messages again')),
                  OutlinedButton(key: const Key('sms-turn-off'), onPressed: _turnOff, child: const Text('Turn off')),
                ],
              ),
              ..._messages(theme),
            ],
          ),
        ),
      );
    }
    return Card(
      key: const Key('sms-status-off'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Off', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              key: const Key('sms-key-field'),
              controller: _key,
              decoration: const InputDecoration(
                labelText: 'Till phone key or set-up link',
                hintText: 'npk_...',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 4),
            Text(
              'On the PC: Settings > M-Pesa Till Phone > Set up a phone shows the key once, with a Copy button. Send it '
              'to this phone (WhatsApp to yourself, for example) and paste it here.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('sms-turn-on'),
              onPressed: _busy ? null : _turnOn,
              child: Text(_busy ? 'Switching on...' : 'Turn on'),
            ),
            ..._messages(theme),
          ],
        ),
      ),
    );
  }

  /// What went wrong (or what to know) after "Turn on", shown right under the button.
  List<Widget> _messages(ThemeData theme) => [
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_problem!, key: const Key('sms-problem'), style: TextStyle(color: theme.colorScheme.error)),
          ),
        if (_note != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_note!, key: const Key('sms-note'), style: theme.textTheme.bodySmall),
          ),
      ];

  Widget _permissionHelpCard(ThemeData theme) {
    return Card(
      key: const Key('sms-permission-help'),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Let NexaPOS receive text messages', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            const Text(
              'If Android said "Restricted setting", or did not ask at all (Android 13 and later do this for apps that '
              'did not come from a store):\n'
              '1. Tap Open App info below.\n'
              '2. Tap the three dots at the top right > Allow restricted settings, and confirm.\n'
              '3. Tap Permissions > SMS > Allow.\n'
              '4. Come back here and tap Turn on again.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('sms-open-settings'),
              onPressed: () => _forwarding.openAppSettings(),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Open App info'),
            ),
          ],
        ),
      ),
    );
  }
}
