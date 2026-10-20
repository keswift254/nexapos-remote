import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'web_update_controller.dart';

/// "Download & Install" for the browser build: shows how far the download has got and
/// restarts the page on the new version by itself when it is done. The state lives in
/// [webUpdateProvider], so it survives the screen around it rebuilding.
class WebUpdateButton extends ConsumerWidget {
  const WebUpdateButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(webUpdateProvider);
    final theme = Theme.of(context);
    final percent = update.progress == null
        ? null
        : (update.progress! * 100).clamp(0, 100).floor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: update.running
              ? null
              : () => ref.read(webUpdateProvider.notifier).start(),
          icon: const Icon(Icons.system_update_alt),
          label: Text(
            update.running
                ? 'Updating…'
                : update.error != null
                ? 'Try again'
                : 'Download & Install',
          ),
        ),
        if (update.running) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(value: update.progress),
          const SizedBox(height: 8),
          Text(
            percent == null ? update.phrase : '${update.phrase} $percent%',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Keep this page open. NexaPOS restarts by itself when it is done - your shop data is not touched.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (update.error != null) ...[
          const SizedBox(height: 12),
          Text(update.error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
      ],
    );
  }
}
