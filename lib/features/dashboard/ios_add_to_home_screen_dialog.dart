import 'package:flutter/material.dart';

/// What an iPhone/iPad user is told after tapping "Add NexaPOS to your home screen" in Safari.
///
/// Since iOS 26 every Home Screen icon opens as a separate "web app" with its own data, apart from
/// Safari's, unless "Open as Web App" is switched off - and the shop lives in Safari. So the steps
/// say to switch it off, and what to do (join with an invite code) if it was left on.
class IosAddToHomeScreenDialog extends StatelessWidget {
  const IosAddToHomeScreenDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('ios-add-to-home-dialog'),
      title: const Text('Add NexaPOS to your home screen'),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Tap the Share icon in Safari\'s toolbar, then choose '
              '"Add to Home Screen".',
            ),
            SizedBox(height: 8),
            Text(
              '2. If you see "Open as Web App", switch it OFF, then tap Add. '
              'The icon then opens NexaPOS in Safari, with this shop and all its data.',
            ),
            SizedBox(height: 12),
            Text(
              'If you leave it on, the icon opens a separate copy of NexaPOS with its '
              'own, empty data (iPhone keeps it apart from Safari). Open it, tap '
              '"Join an existing shop" and enter an invite code from here '
              '(Settings > Sync & Invites > Invite a device).',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}
