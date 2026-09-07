import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../domain/entities/user.dart';
import '../../domain/services/auth_service.dart';
import '../../domain/services/license_service.dart';

class SupportRecoveryDialog extends ConsumerStatefulWidget {
  final String initialPassword;
  const SupportRecoveryDialog({super.key, this.initialPassword = ''});
  @override
  ConsumerState<SupportRecoveryDialog> createState() => _SupportRecoveryState();
}

class _SupportRecoveryState extends ConsumerState<SupportRecoveryDialog> {
  final supportPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirmPassword = TextEditingController();
  List<User>? users;
  User? selected;
  DateTime? authorizedUntil;
  String? deviceId;
  String? message;
  bool busy = false;
  bool done = false;

  @override
  void initState() {
    super.initState();
    supportPassword.text = widget.initialPassword;
    ref.read(syncMetadataProvider).deviceId().then((id) {
      if (mounted) setState(() => deviceId = id);
    });
  }

  @override
  void dispose() {
    supportPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final auth = ref.read(authServiceProvider);
      if (users == null) {
        await ref
            .read(licenseServiceProvider)
            .authorizeSupport(supportPassword.text);
        final accounts = await auth.getAllUsers();
        if (!mounted) return;
        setState(() {
          users = accounts.where((u) => u.isActive).toList();
          authorizedUntil = DateTime.now().add(const Duration(minutes: 15));
          supportPassword.clear();
        });
      } else {
        if (authorizedUntil == null ||
            !DateTime.now().isBefore(authorizedUntil!)) {
          throw StateError(
            'Support session expired. Close and request a new support password.',
          );
        }
        final account = selected;
        if (account == null) throw StateError('Select the account to recover.');
        if (newPassword.text.length < 8 ||
            newPassword.text != confirmPassword.text) {
          throw StateError(
            'Enter matching passwords of at least 8 characters.',
          );
        }
        final result = await auth.resetUserPassword(account.id, newPassword.text);
        result.when(
          ok: (_) {
            done = true;
            authorizedUntil = null;
          },
          failure: (error) => throw StateError(error),
        );
        if (mounted) {
          setState(
            () => message =
                'Done. Sign in as ${account.username} using the new password.',
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Super admin recovery'),
    scrollable: true,
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ask your shop administrator to reset your password in Users & Roles. If no administrator can sign in, contact NexaPOS support: 0768415017.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SelectableText('Device ID: ${deviceId ?? "Loading..."}'),
              ),
              IconButton(
                tooltip: 'Copy device ID',
                onPressed: deviceId == null
                    ? null
                    : () => Clipboard.setData(ClipboardData(text: deviceId!)),
                icon: const Icon(Icons.copy),
              ),
            ],
          ),
          if (!done && users == null) ...[
            const Text('Support username: nexapos-support'),
            TextField(
              controller: supportPassword,
              obscureText: true,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'One-time support password',
              ),
            ),
          ],
          if (!done && users != null) ...[
            DropdownButtonFormField<User>(
              isExpanded: true,
              initialValue: selected,
              decoration: const InputDecoration(labelText: 'Account'),
              items: users!
                  .map(
                    (u) => DropdownMenuItem(
                      value: u,
                      child: Text(
                        '${u.name} (${u.username})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: busy ? null : (u) => setState(() => selected = u),
            ),
            TextField(
              controller: newPassword,
              obscureText: true,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'New password (at least 8 characters)',
              ),
            ),
            TextField(
              controller: confirmPassword,
              obscureText: true,
              enabled: !busy,
              decoration: const InputDecoration(labelText: 'Confirm password'),
            ),
          ],
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(message!),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: Text(done ? 'Done' : 'Cancel'),
      ),
      if (!done)
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(
            busy
                ? 'Verifying...'
                : users == null
                ? 'Authorize recovery'
                : 'Reset password',
          ),
        ),
    ],
  );
}
