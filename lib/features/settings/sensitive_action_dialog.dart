import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/sensitive_action_service.dart';
import '../../domain/services/session_service.dart';

Future<ActionApproval?> requestSensitiveApproval(
  BuildContext context, {
  required String action,
}) => showDialog<ActionApproval>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _ApprovalDialog(action: action),
);

class _ApprovalDialog extends ConsumerStatefulWidget {
  final String action;
  const _ApprovalDialog({required this.action});
  @override
  ConsumerState<_ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends ConsumerState<_ApprovalDialog> {
  final password = TextEditingController();
  final code = TextEditingController();
  String? secret;
  String? error;
  bool verifiedPassword = false;
  bool busy = false;

  @override
  void dispose() {
    password.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> verify() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final service = ref.read(sensitiveActionProvider);
      final username = ref.read(sessionProvider)?.username ?? '';
      if (!verifiedPassword) {
        final id = await service.verifyPassword(username, password.text);
        final enrolled = await service.isEnrolled(id);
        if (!mounted) return;
        setState(() {
          verifiedPassword = true;
          secret = enrolled ? null : service.newSecret();
        });
      } else {
        final approval = await service.approve(
          username: username,
          password: password.text,
          code: code.text,
          action: widget.action,
          enrollmentSecret: secret,
        );
        if (mounted) Navigator.pop(context, approval);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.action),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ref.watch(sessionProvider)?.username ?? 'Administrator'),
            TextField(
              controller: password,
              obscureText: true,
              enabled: !busy && !verifiedPassword,
              decoration: const InputDecoration(
                labelText: 'Administrator password',
              ),
              onSubmitted: (_) => busy ? null : verify(),
            ),
            if (verifiedPassword) ...[
              const SizedBox(height: 16),
              if (secret != null) ...[
                const Text(
                  'Add NexaPOS to your authenticator using this setup key. Keep a secure copy for recovery.',
                ),
                const SizedBox(height: 8),
                SelectableText(secret!),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Authenticator code',
                ),
                onSubmitted: (_) => busy ? null : verify(),
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy ? null : verify,
        child: Text(
          busy
              ? 'Verifying...'
              : verifiedPassword
              ? 'Authorize'
              : 'Continue',
        ),
      ),
    ],
  );
}
