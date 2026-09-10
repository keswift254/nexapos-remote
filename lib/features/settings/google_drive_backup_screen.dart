import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/import/shop_archive.dart';
import '../../domain/services/google_drive_backup_service.dart';
import '../../domain/services/sensitive_action_service.dart';
import '../../domain/services/shop_safety_service.dart';
import '../../domain/services/sync_service.dart';
import 'save_recovery.dart';
import 'sensitive_action_dialog.dart';

part 'google_drive_backup_screen.g.dart';

@riverpod
Future<String?> connectedGoogleDriveEmail(Ref ref) {
  return ref.watch(googleDriveBackupServiceProvider).connectedEmail();
}

@riverpod
Future<List<GoogleDriveBackupSummary>> googleDriveBackups(Ref ref) async {
  final email = await ref.watch(connectedGoogleDriveEmailProvider.future);
  if (email == null) return const [];
  return ref.watch(googleDriveBackupServiceProvider).listBackups();
}

/// Lets an Admin connect the shop's Google account so encrypted local
/// backups also mirror to a hidden Drive folder (see
/// [[project-drive-backup-and-ios-browser-design]] for why this is
/// passphrase-escrowed rather than silently recoverable, and why the
/// scope is drive.appdata rather than a visible folder). NexaPOS never
/// sees or stores the merchant's Google credentials - the token lives
/// only on this device, exactly like every other business-critical
/// setting on this screen tier.
///
/// A plain section widget (no Scaffold of its own) so BackupScreen can
/// embed it alongside the local-backup section on one page - Drive
/// backup is an extra off-device copy of the same local backups, not a
/// separate concern from a merchant's point of view.
class GoogleDriveBackupSection extends ConsumerStatefulWidget {
  const GoogleDriveBackupSection({super.key});

  @override
  ConsumerState<GoogleDriveBackupSection> createState() => _GoogleDriveBackupSectionState();
}

class _GoogleDriveBackupSectionState extends ConsumerState<GoogleDriveBackupSection> {
  bool _busy = false;
  String? _error;

  Future<void> _connect() async {
    final approval = await requestSensitiveApproval(context, action: 'Connect Google Drive backup');
    if (approval == null || !mounted) return;

    final passphrase = await _promptForNewRecoveryPassphrase();
    if (passphrase == null || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sensitiveActionProvider).consume(approval, 'Connect Google Drive backup');
      final email = await ref.read(googleDriveBackupServiceProvider).connect(recoveryPassphrase: passphrase);
      ref.invalidate(connectedGoogleDriveEmailProvider);
      ref.invalidate(googleDriveBackupsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to Google Drive as $email.')),
      );
    } catch (e) {
      setState(() => _error = 'Could not connect Google Drive: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    final approval = await requestSensitiveApproval(context, action: 'Disconnect Google Drive backup');
    if (approval == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Google Drive?'),
        content: const Text(
          'NexaPOS will stop uploading backups to this Google account. '
          'Backups already there are left alone - NexaPOS has no other way to reach them once disconnected.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Disconnect')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(sensitiveActionProvider).consume(approval, 'Disconnect Google Drive backup');
      await ref.read(googleDriveBackupServiceProvider).disconnect();
      ref.invalidate(connectedGoogleDriveEmailProvider);
      ref.invalidate(googleDriveBackupsProvider);
    } catch (e) {
      setState(() => _error = 'Could not disconnect: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadNow() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(googleDriveBackupServiceProvider).uploadLatestBackupIfConnected();
      ref.invalidate(googleDriveBackupsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploaded the latest backup to Google Drive.')),
      );
    } catch (e) {
      setState(() => _error = 'Could not upload to Google Drive: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Downloads [backup], recovers the archive's encryption key with the
  /// merchant's recovery passphrase, and merges it into this device via
  /// the same ShopSafetyService.restore() the local-file "Import shop
  /// data" flow already uses - a fresh device's database is empty, so
  /// "merge into existing" and "become this shop" are the same operation
  /// here, without needing a second restore code path.
  Future<void> _restore(GoogleDriveBackupSummary backup) async {
    final passphrase = await _promptForExistingRecoveryPassphrase();
    if (passphrase == null || !mounted) return;

    // ShopSafetyService.restore() consumes this approval itself against
    // the fixed action name "Import shop data" - it must match exactly.
    final approval = await requestSensitiveApproval(context, action: 'Import shop data');
    if (approval == null || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final drive = ref.read(googleDriveBackupServiceProvider);
      final keyBytes = await drive.recoverBackupKey(recoveryPassphrase: passphrase);
      final bytes = await drive.downloadBackup(backup.fileId);
      final archive = await ArchiveEncryption.decode(bytes, base64Url.encode(keyBytes));
      final counts = await ref.read(shopSafetyProvider).restore(
            approval,
            archive,
            (archive) => saveRecoveryArchive(context, archive),
          );
      if (counts == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Restored ${counts.values.fold<int>(0, (a, b) => a + b)} records from Google Drive.',
          ),
        ),
      );
      unawaited(ref.read(syncServiceProvider).runSyncCycle().catchError((Object _) {}));
    } catch (e) {
      setState(() => _error = 'Could not restore from Google Drive: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _promptForExistingRecoveryPassphrase() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter recovery passphrase'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Recovery passphrase'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptForNewRecoveryPassphrase() async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    var acknowledged = false;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set a recovery passphrase'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This passphrase - not your login password - is the only way to '
                'restore a backup from Google Drive onto a new device. NexaPOS '
                'does not store it anywhere and cannot reset it for you. '
                'If it is lost, Drive backups made with it are permanently unrecoverable.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Recovery passphrase (at least 8 characters)'),
              ),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm passphrase'),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: acknowledged,
                onChanged: (value) => setDialogState(() => acknowledged = value ?? false),
                title: const Text('I understand this cannot be recovered if lost.'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: !acknowledged
                  ? null
                  : () {
                      final value = controller.text;
                      if (value.length < 8 || value != confirmController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Passphrases must match and be at least 8 characters.')),
                        );
                        return;
                      }
                      Navigator.pop(context, value);
                    },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emailAsync = ref.watch(connectedGoogleDriveEmailProvider);
    final backupsAsync = ref.watch(googleDriveBackupsProvider);

    return emailAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Could not load status: $error')),
      data: (email) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Google Drive backup', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Keep an extra encrypted copy of your local backups in your own Google account.',
          ),
          const SizedBox(height: 12),
          if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            Card(
              child: ListTile(
                leading: Icon(email != null ? Icons.cloud_done : Icons.cloud_off),
                title: Text(email != null ? 'Connected as $email' : 'Not connected'),
                subtitle: Text(
                  email != null
                      ? 'Backups upload to a hidden folder in this Google account.'
                      : 'Connect a Google account to keep an off-device copy of your backups.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_busy)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else if (email == null)
              FilledButton.icon(
                onPressed: _connect,
                icon: const Icon(Icons.add_link),
                label: const Text('Connect Google Drive'),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _uploadNow,
                      icon: const Icon(Icons.upload),
                      label: const Text('Upload now'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _disconnect,
                      icon: const Icon(Icons.link_off),
                      label: const Text('Disconnect'),
                    ),
                  ),
                ],
              ),
            if (email != null) ...[
              const SizedBox(height: 24),
              Text('Backups on Drive', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              backupsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('Could not list backups: $error'),
                data: (backups) => backups.isEmpty
                    ? const Text('No backups uploaded yet.')
                    : Column(
                        children: backups
                            .map(
                              (b) => ListTile(
                                leading: const Icon(Icons.description_outlined),
                                title: Text(b.modifiedAt?.toLocal().toString() ?? b.name),
                                subtitle: b.sizeBytes == null
                                    ? null
                                    : Text('${(b.sizeBytes! / 1024).toStringAsFixed(0)} KB'),
                                trailing: TextButton(
                                  onPressed: _busy ? null : () => _restore(b),
                                  child: const Text('Restore'),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ],
      ),
    );
  }
}
