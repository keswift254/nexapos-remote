import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/license_purchase_service.dart';

/// "Already paid? Restore my license": for a customer who reinstalled the app or
/// changed phone. A license belongs to the device it was first used on and a
/// fresh install is a new device, so this proves they own the email they paid
/// with (a 6-digit code is emailed to it) and moves the license here. Pops `true`
/// once this device has been activated.
Future<bool?> showRestoreDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _RestoreDialog(),
  );
}

class _RestoreDialog extends ConsumerStatefulWidget {
  const _RestoreDialog();

  @override
  ConsumerState<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends ConsumerState<_RestoreDialog> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  /// False while asking for the email, true once a code has been sent.
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _prefillEmail();
  }

  Future<void> _prefillEmail() async {
    String? last;
    try {
      last = await ref.read(licensePurchaseServiceProvider).lastEmail();
    } catch (_) {}
    if (!mounted || last == null || _emailController.text.isNotEmpty) return;
    _emailController.text = last;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  static final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!_emailShape.hasMatch(email)) {
      setState(() => _error = 'Enter the email address you paid with.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final outcome = await ref
        .read(licensePurchaseServiceProvider)
        .requestRestoreCode(email);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (outcome.ok) {
        _codeSent = true;
        _codeController.clear();
        _notice = outcome.message;
      } else {
        _error = outcome.message;
      }
    });
  }

  Future<void> _confirm() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from the email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final outcome = await ref
        .read(licensePurchaseServiceProvider)
        .restore(_emailController.text, code);
    if (!mounted) return;
    if (outcome.ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = outcome.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      key: const Key('restore-dialog'),
      title: const Text('Restore my license'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_codeSent) ...[
              const Text(
                'Reinstalled NexaPOS or changed phone? Enter the email address '
                'you paid with and we will email you a 6-digit code.',
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('restore-email'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Email address'),
                onSubmitted: (_) => _sendCode(),
              ),
            ] else ...[
              Text(
                _notice ??
                    'If a NexaPOS purchase was made with this email, a 6-digit '
                        'code is on its way.',
                key: const Key('restore-info'),
              ),
              const SizedBox(height: 4),
              Text(
                'Sent to ${_emailController.text.trim()}. The code works for '
                '15 minutes.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('restore-code'),
                controller: _codeController,
                keyboardType: TextInputType.number,
                autofocus: true,
                enabled: !_busy,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: '6-digit code'),
                onSubmitted: (_) => _confirm(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                key: const Key('restore-error'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'This moves your license to this device. Your shop data is not '
              'part of it - that comes back from a backup.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('restore-cancel'),
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        if (_codeSent) ...[
          TextButton(
            key: const Key('restore-resend'),
            onPressed: _busy ? null : _sendCode,
            child: const Text('Send a new code'),
          ),
          TextButton(
            key: const Key('restore-other-email'),
            onPressed: _busy
                ? null
                : () => setState(() {
                    _codeSent = false;
                    _error = null;
                    _notice = null;
                  }),
            child: const Text('Different email'),
          ),
          FilledButton(
            key: const Key('restore-confirm'),
            onPressed: _busy ? null : _confirm,
            child: _busy ? const _Spinner() : const Text('Restore'),
          ),
        ] else
          FilledButton(
            key: const Key('restore-send-code'),
            onPressed: _busy ? null : _sendCode,
            child: _busy ? const _Spinner() : const Text('Send code'),
          ),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 18,
    width: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

/// The device's own ID with a copy button - what support asks for to move a
/// license by hand (Settings > License shows it too, but a customer who has just
/// reinstalled is on the activation screen, not in Settings).
class DeviceIdTile extends StatefulWidget {
  const DeviceIdTile({super.key, required this.load});

  final Future<String> Function() load;

  @override
  State<DeviceIdTile> createState() => _DeviceIdTileState();
}

class _DeviceIdTileState extends State<DeviceIdTile> {
  String? _id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String? id;
    try {
      id = await widget.load();
    } catch (_) {
      // No ID shown is better than a broken activation screen.
    }
    if (!mounted) return;
    setState(() => _id = id);
  }

  @override
  Widget build(BuildContext context) {
    final id = _id;
    if (id == null || id.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          'Need help? Give support this device ID:',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: SelectableText(
                id,
                key: const Key('device-id'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              key: const Key('copy-device-id'),
              tooltip: 'Copy device ID',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: id));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Device ID copied')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
