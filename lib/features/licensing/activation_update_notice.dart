import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/update_service.dart';

/// "Update available" for a device that is stuck on the activation screen - a
/// fresh install, an expired or revoked license, a phone that was reset. The
/// licensing guard keeps such a device away from every other screen, including
/// the Software Update one, so without this it could never learn that a newer
/// version exists, let alone install it. That matters most for exactly these
/// devices: an old build may lack the way to pay for a license at all, and the
/// update is what brings it.
///
/// The background check that feeds this already runs from the app's root timer
/// whatever the license state; this only shows the answer and runs the same
/// install the Software Update screen does. Nothing here needs a license.
/// Deliberately says only the version (never the release-notes text or a
/// download link), like the Software Update screen.
class ActivationUpdateNotice extends ConsumerStatefulWidget {
  const ActivationUpdateNotice({super.key});

  @override
  ConsumerState<ActivationUpdateNotice> createState() =>
      _ActivationUpdateNoticeState();
}

class _ActivationUpdateNoticeState
    extends ConsumerState<ActivationUpdateNotice> {
  @override
  void initState() {
    super.initState();
    // Opening this screen is the moment someone wonders whether a fix is out, so
    // ask now instead of waiting up to two minutes for the timer. Never blocks
    // painting, and the notifier swallows its own errors.
    unawaited(ref.read(updateAvailabilityProvider.notifier).check());
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(updateAvailabilityProvider);
    final install = ref.watch(updateInstallProvider);
    ref.listen<UpdateInstallState>(updateInstallProvider, (previous, next) {
      final finishedOk =
          (previous?.installing ?? false) &&
          !next.installing &&
          next.error == null;
      if (!finishedOk || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Installer opened - finish the install there, then reopen NexaPOS.',
          ),
        ),
      );
    });

    final info = available ?? install.info;
    if (info == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Container(
      key: const Key('activation-update'),
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.system_update_alt, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update available: ${info.version}',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                if (kIsWeb)
                  const Text(
                    'Reload NexaPOS in your browser to get this version.',
                  )
                else ...[
                  const Text(
                    'You can update this device right now - it does not need a '
                    'license.',
                  ),
                  const SizedBox(height: 12),
                  if (install.installing) ...[
                    LinearProgressIndicator(
                      value: install.progress > 0 ? install.progress : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      install.progress < 0.9
                          ? 'Downloading... ${(install.progress * 100).round()}%'
                          : 'Installing...',
                      key: const Key('activation-update-progress'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ] else
                    FilledButton.icon(
                      key: const Key('activation-update-install'),
                      onPressed: () =>
                          ref.read(updateInstallProvider.notifier).start(info),
                      icon: const Icon(Icons.system_update_alt),
                      label: const Text('Download & Install'),
                    ),
                  if (install.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      install.error!,
                      key: const Key('activation-update-error'),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
