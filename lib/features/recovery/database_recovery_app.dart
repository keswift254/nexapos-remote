import 'dart:ui' show AppExitType;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/local/database_startup_check.dart';

/// Shown instead of the app when its saved data is on disk but the key that
/// unlocks it is gone. It never deletes anything: starting fresh moves the old
/// files into a dated folder and the shop is then rebuilt from the cloud.
class DatabaseRecoveryApp extends StatefulWidget {
  const DatabaseRecoveryApp({
    super.key,
    required this.problem,
    required this.onFinished,
    this.recheck = checkDatabaseStartup,
    this.setAside = setAsideDatabaseFiles,
    this.exitApp = _exit,
  });

  final DatabaseStartupProblem problem;

  /// Called when it is safe to start the normal app.
  final VoidCallback onFinished;
  final Future<DatabaseStartupProblem?> Function() recheck;
  final Future<String> Function(String databasePath) setAside;
  final VoidCallback exitApp;

  static void _exit() => ServicesBinding.instance.exitApplication(AppExitType.required);

  @override
  State<DatabaseRecoveryApp> createState() => _DatabaseRecoveryAppState();
}

class _DatabaseRecoveryAppState extends State<DatabaseRecoveryApp> {
  bool _busy = false;
  String? _message;
  String? _heldFolder;

  Future<void> _tryAgain() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final problem = await widget.recheck();
    if (!mounted) return;
    if (problem == null) {
      widget.onFinished();
      return;
    }
    setState(() {
      _busy = false;
      _message = 'Still cannot open the saved data.';
    });
  }

  Future<void> _startFresh(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start fresh?'),
        content: const Text(
          'The old data file is not deleted - it is moved into a folder next to it, '
          'so it can be recovered later if its key is found. NexaPOS then starts empty '
          'and downloads this shop from the cloud after you activate it.\n\n'
          'Anything that never reached the cloud stays only in the old file.',
        ),
        actions: [
          TextButton(
            key: const Key('recovery-cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('recovery-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Start fresh'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final folder = await widget.setAside(widget.problem.databasePath);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _heldFolder = folder;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'Could not move the old data aside, so nothing was changed. $error';
      });
    }
  }

  String get _explanation => switch (widget.problem.kind) {
    DatabaseProblemKind.keyMissing =>
      'NexaPOS cannot read the security key that unlocks its saved data on this computer. '
          'This can follow a power cut or a Windows profile problem.',
    DatabaseProblemKind.keyDoesNotOpen =>
      'The security key stored on this computer does not unlock the saved data. '
          'This can follow a power cut or a Windows profile problem.',
  };

  @override
  Widget build(BuildContext context) {
    final held = _heldFolder;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Builder(
                builder: (innerContext) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      held == null ? "NexaPOS can't open its saved data" : 'Old data set aside',
                      style: Theme.of(innerContext).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    if (held == null) ...[
                      Text(_explanation),
                      const SizedBox(height: 12),
                      const Text('Your data file has NOT been deleted or changed.'),
                      const SizedBox(height: 12),
                      const Text(
                        'If you have a backup of this computer from before the problem, ask for help '
                        'before choosing anything - it may contain the key. Otherwise you can start '
                        'fresh and rebuild the shop from the cloud.',
                      ),
                    ] else ...[
                      Text('The old data was moved to:\n$held'),
                      const SizedBox(height: 12),
                      const Text('Keep that folder. Continue to activate NexaPOS and download your shop again.'),
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(_message!, style: TextStyle(color: Theme.of(innerContext).colorScheme.error)),
                    ],
                    const SizedBox(height: 24),
                    if (_busy)
                      const Center(child: CircularProgressIndicator())
                    else if (held == null) ...[
                      OutlinedButton(
                        key: const Key('recovery-try-again'),
                        onPressed: _tryAgain,
                        child: const Text('Try again'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        key: const Key('recovery-start-fresh'),
                        onPressed: () => _startFresh(innerContext),
                        child: const Text('Start fresh and rebuild from the cloud'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        key: const Key('recovery-close'),
                        onPressed: widget.exitApp,
                        child: const Text('Close NexaPOS'),
                      ),
                    ] else
                      FilledButton(
                        key: const Key('recovery-continue'),
                        onPressed: widget.onFinished,
                        child: const Text('Continue'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
