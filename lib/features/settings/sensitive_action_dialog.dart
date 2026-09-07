import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/services/sensitive_action_service.dart';
import '../../domain/services/session_service.dart';
import '../../domain/services/license_service.dart';
import '../../core/providers.dart';

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
  String? deviceId;

  @override
  void initState() {
    super.initState();
    ref.read(syncMetadataProvider).deviceId().then((id) {
      if (mounted) setState(() => deviceId = id);
    });
  }

  Future<void> checkReset() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(licenseServiceProvider).checkAuthenticatorReset();
      final service = ref.read(sensitiveActionProvider);
      final id = await service.verifyPassword(
        ref.read(sessionProvider)!.username,
        password.text,
      );
      final enrolled = await service.isEnrolled(id);
      if (mounted) {
        setState(() {
          secret = enrolled ? null : service.newSecret();
          code.clear();
          error = enrolled
              ? 'No new approved reset. Contact support with your device ID.'
              : null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

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
                Center(
                  child: QrImageView(
                    data: _otpUri(
                      secret!,
                      ref.read(sessionProvider)?.username ?? 'admin',
                    ),
                    size: 180,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: SelectableText(secret!)),
                    IconButton(
                      tooltip: 'Copy setup key',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: secret!));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Setup key copied.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_outlined),
                    ),
                  ],
                ),
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
            if (verifiedPassword)
              TextButton.icon(
                onPressed: busy ? null : () => _showRecoveryHelp(context),
                icon: const Icon(Icons.help_outline),
                label: const Text('Lost access to your authenticator?'),
              ),
            if (verifiedPassword) ...[
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      'Device ID: ${deviceId ?? "Loading..."}',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy device ID',
                    icon: const Icon(Icons.copy),
                    onPressed: deviceId == null
                        ? null
                        : () =>
                              Clipboard.setData(ClipboardData(text: deviceId!)),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: busy ? null : checkReset,
                icon: const Icon(Icons.refresh),
                label: const Text('Check for approved reset'),
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

  String _otpUri(String secret, String username) {
    final label = Uri.encodeComponent('NexaPOS:$username');
    final issuer = Uri.encodeComponent('NexaPOS');
    return 'otpauth://totp/$label?secret=$secret&issuer=$issuer&algorithm=SHA1&digits=6&period=30';
  }

  Future<void> _showRecoveryHelp(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Authenticator recovery'),
      content: const Text(
        'Use the saved setup key to add NexaPOS to a new authenticator. '
        'If the key is unavailable, contact the shop owner or NexaPOS support. '
        'A reset must be approved by an administrator after verifying ownership; '
        'there is no safe password-only bypass.',
      ),
      actions: [
        TextButton.icon(
          onPressed: () => launchUrl(
            Uri.parse('https://wa.me/message/M5SGWZ664XJ4C1'),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.chat_outlined),
          label: const Text('Contact support'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
