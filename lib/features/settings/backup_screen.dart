import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/import/shop_archive.dart';
import '../../domain/services/sensitive_action_service.dart';
import '../../domain/services/sync_service.dart';
import 'google_drive_backup_screen.dart';
import 'save_recovery.dart';
import 'sensitive_action_dialog.dart';

/// Everything about protecting a shop's data in one place: an on-demand
/// local encrypted backup (saved wherever the merchant chooses), and the
/// optional Google Drive mirror of the automatic backups. Previously
/// split across a dashboard menu action and a separate settings screen -
/// unified here since they're the same concern ("keep my data safe") to
/// a merchant, not two different features.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _savingBackup = false;

  Future<void> _saveManualBackup() async {
    if (_savingBackup) return;
    final approval = await requestSensitiveApproval(
      context,
      action: 'Back up shop data',
    );
    if (approval == null || !mounted) return;
    setState(() => _savingBackup = true);
    try {
      await ref
          .read(sensitiveActionProvider)
          .consume(approval, 'Back up shop data');
      final archive = await ref.read(syncServiceProvider).exclusive(() async {
        final snapshot = await ShopArchive.capture(
          ref.read(appDatabaseProvider),
        );
        await snapshot.validate();
        return snapshot;
      });
      if (!mounted) return;
      final saved = await saveRecoveryArchive(context, archive);
      if (mounted && saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Done. Encrypted backup saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _savingBackup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Local backup', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Save an encrypted snapshot of your shop data to a file you choose. '
            'NexaPOS also does this automatically every few hours.',
          ),
          const SizedBox(height: 12),
          if (_savingBackup)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else
            FilledButton.icon(
              onPressed: _saveManualBackup,
              icon: const Icon(Icons.save_alt),
              label: const Text('Back up data now'),
            ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const GoogleDriveBackupSection(),
        ],
      ),
    );
  }
}
