import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/import/shop_archive.dart';
import '../../data/import/legacy_pos_mapper.dart';
import '../../data/import/legacy_pos_reader.dart';
import '../../domain/services/shop_safety_service.dart';
import '../../domain/services/sensitive_action_service.dart';
import '../../domain/services/sync_service.dart';
import '../settings/save_recovery.dart';
import '../settings/sensitive_action_dialog.dart';

class ShopTransferDialog extends ConsumerStatefulWidget {
  const ShopTransferDialog({super.key});
  @override
  ConsumerState<ShopTransferDialog> createState() => _ShopTransferDialogState();
}

class _ShopTransferDialogState extends ConsumerState<ShopTransferDialog> {
  final url = TextEditingController(
    text: 'http://localhost/pos/public/index.php?page=login',
  );
  final php = TextEditingController(text: r'C:\xampp\php\php.exe');
  final database = TextEditingController(text: 'pos');
  final username = TextEditingController(text: 'root');
  final password = TextEditingController();
  final port = TextEditingController(text: '3306');
  final offset = TextEditingController(text: '3');
  final archivePassword = TextEditingController();
  ShopArchive? preview;
  String? message;
  bool busy = false;
  bool failed = false;
  bool sourceConnected = false;

  @override
  void dispose() {
    for (final c in [
      url,
      php,
      database,
      username,
      password,
      port,
      offset,
      archivePassword,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> run(Future<void> Function() task) async {
    if (busy) return;
    setState(() {
      busy = true;
      failed = false;
      message = null;
    });
    try {
      await task();
    } catch (e) {
      if (mounted) {
        setState(() {
          failed = true;
          message = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> readSource() => run(() async {
    setState(() => preview = null);
    final raw = await LegacyPosReader().readDatabase(
      url: url.text,
      phpPath: php.text,
      database: database.text,
      username: username.text,
      password: password.text,
      port: int.tryParse(port.text) ?? 0,
    );
    final timezone = int.tryParse(offset.text);
    if (timezone == null || timezone < -12 || timezone > 14) {
      throw StateError('Invalid source UTC offset.');
    }
    final candidate = LegacyPosMapper(
      raw['source'] as String,
      utcOffsetHours: timezone,
    ).convert(raw);
    await candidate.validate();
    if (mounted) setState(() => preview = candidate);
  });

  Future<void> restoreFile() => run(() async {
    setState(() => preview = null);
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['nexabackup'],
    );
    if (picked == null) return;
    if (await picked.length() > maxArchiveBytes) {
      throw StateError('Backup exceeds the supported size.');
    }
    final candidate = await ArchiveEncryption.decode(
      await picked.readAsBytes(),
      archivePassword.text,
    );
    if (mounted) setState(() => preview = candidate);
  });

  Future<void> importPreview() => run(() async {
    final candidate = preview;
    if (candidate == null) return;
    final approval = await requestSensitiveApproval(
      context,
      action: 'Import shop data',
    );
    if (approval == null || !mounted) return;
    final counts = await ref
        .read(shopSafetyProvider)
        .restore(
          approval,
          candidate,
          (archive) => saveRecoveryArchive(context, archive),
        );
    if (counts == null) return;
    if (mounted) {
      setState(() {
        preview = null;
        message =
            'Imported ${counts.values.fold<int>(0, (a, b) => a + b)} records. Existing records were preserved.';
      });
    }
    await ref.read(syncServiceProvider).runSyncCycle();
  });

  Future<void> exportBackup() => run(() async {
    final approval = await requestSensitiveApproval(
      context,
      action: 'Create shop backup',
    );
    if (approval == null || !mounted) return;
    await ref
        .read(sensitiveActionProvider)
        .consume(approval, 'Create shop backup');
    await ref.read(syncServiceProvider).exclusive(() async {
      final archive = await ShopArchive.capture(ref.read(appDatabaseProvider));
      if (!mounted) return;
      final saved = await saveRecoveryArchive(context, archive);
      if (mounted && saved) {
        setState(
          () => message =
              'Encrypted backup saved. Keep its password for recovery.',
        );
      }
    });
  });

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850, maxHeight: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Import all data from another POS',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (busy) const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextField(
                    controller: url,
                    enabled: !busy,
                    onChanged: (_) => setState(() {
                      sourceConnected = false;
                      preview = null;
                    }),
                    decoration: const InputDecoration(
                      labelText: 'Local POS link',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => run(() async {
                              final result = await LegacyPosReader().inspect(
                                url.text,
                              );
                              if (mounted) {
                                setState(() {
                                  message = result;
                                  sourceConnected = true;
                                });
                              }
                            }),
                      icon: const Icon(Icons.search),
                      label: const Text('Inspect source'),
                    ),
                  ),
                  if (sourceConnected && Platform.isWindows) ...[
                    TextField(
                      controller: php,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: 'XAMPP PHP executable',
                      ),
                    ),
                    TextField(
                      controller: database,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: 'Source database name',
                      ),
                    ),
                    TextField(
                      controller: port,
                      enabled: !busy,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'MySQL port',
                      ),
                    ),
                    TextField(
                      controller: username,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: 'Database username',
                      ),
                    ),
                    TextField(
                      controller: password,
                      enabled: !busy,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Database password',
                      ),
                    ),
                    TextField(
                      controller: offset,
                      enabled: !busy,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Source timestamp UTC offset (Kenya: 3)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: busy ? null : readSource,
                        icon: const Icon(Icons.preview),
                        label: const Text('Read and preview'),
                      ),
                    ),
                  ],
                  const Divider(height: 32),
                  const Text(
                    'Backup and restore',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  TextField(
                    controller: archivePassword,
                    enabled: !busy,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password for the backup to restore',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: busy ? null : restoreFile,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Open backup'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy ? null : exportBackup,
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Create backup'),
                      ),
                    ],
                  ),
                  if (preview != null) ...[
                    const Divider(height: 32),
                    const Text(
                      'Migration preview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    for (final table in preview!.tables.entries)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(table.key.replaceAll('_', ' ')),
                        trailing: Text('${table.value.length}'),
                      ),
                    for (final note in preview!.notes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(note),
                      ),
                    const Text(
                      'A recovery backup of this shop is required before import. Conflicting records stop the import.',
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: busy ? null : importPreview,
                        icon: const Icon(Icons.download_done),
                        label: const Text('Back up and import'),
                      ),
                    ),
                  ],
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: SelectableText(
                        message!,
                        style: TextStyle(
                          color: failed
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
