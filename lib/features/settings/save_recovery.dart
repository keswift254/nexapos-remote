import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/import/shop_archive.dart';

Future<bool> saveRecoveryArchive(
  BuildContext context,
  ShopArchive archive,
) async {
  final password = await showDialog<String>(
    context: context,
    builder: (_) => const _BackupPasswordDialog(),
  );
  if (password == null) return false;
  final bytes = await ArchiveEncryption.encode(archive, password);
  // Verify the full encrypted payload before handing it to platform storage.
  await ArchiveEncryption.decode(bytes, password);
  final saved = await FilePicker.saveFile(
    fileName:
        'NexaPOS-${DateTime.now().toUtc().millisecondsSinceEpoch}.nexabackup',
    bytes: bytes,
    dialogTitle: 'Save encrypted recovery backup',
    initialDirectory: Platform.isWindows && Directory('G:\\').existsSync()
        ? 'G:\\'
        : null,
  );
  if (saved == null) return false;
  if (saved.scheme == 'file') {
    final diskBytes = await File.fromUri(saved).readAsBytes();
    await ArchiveEncryption.decode(diskBytes, password);
  }
  return true;
}

class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog();
  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final password = TextEditingController();
  final confirm = TextEditingController();
  String? error;
  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Recovery backup password'),
    content: SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Keep this password. It is required to restore this backup on any device.',
          ),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password (8 or more characters)',
            ),
          ),
          TextField(
            controller: confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm password'),
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (password.text.length < ArchiveEncryption.minimumPasswordLength ||
              password.text != confirm.text) {
            setState(
              () => error = 'Use matching passwords of at least 8 characters.',
            );
          } else {
            Navigator.pop(context, password.text);
          }
        },
        child: const Text('Save backup'),
      ),
    ],
  );
}
