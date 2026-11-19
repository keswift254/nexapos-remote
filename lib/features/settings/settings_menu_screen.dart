import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/user_role.dart';
import '../../domain/services/session_service.dart';

/// One page of Settings: its title and the route it opens.
class SettingsMenuEntry {
  const SettingsMenuEntry(this.route, this.title, {this.adminOnly = false});

  final String route;
  final String title;
  final bool adminOnly;
}

/// The pages behind the dashboard's Settings icon, in their order. Administrator pages are left out for everyone else (the
/// router turns them away too).
const settingsMenuEntries = <SettingsMenuEntry>[
  SettingsMenuEntry('/privacy-settings', 'Security & Privacy'),
  SettingsMenuEntry('/business-settings', 'Business, Receipts & Themes', adminOnly: true),
  SettingsMenuEntry('/payment-settings', 'Payments & Payouts', adminOnly: true),
  SettingsMenuEntry('/till-phone', 'M-Pesa Till Phone', adminOnly: true),
  SettingsMenuEntry('/device-sync', 'Sync & Invites', adminOnly: true),
  SettingsMenuEntry('/connected-devices', 'Devices in This Shop', adminOnly: true),
  SettingsMenuEntry('/backup', 'Backup & Restore', adminOnly: true),
  SettingsMenuEntry('/region-time', 'Date, Time & Region', adminOnly: true),
  SettingsMenuEntry('/license', 'My License'),
  SettingsMenuEntry('/update', 'Software Update'),
];

/// The entries [role] may open.
List<SettingsMenuEntry> settingsMenuFor(UserRole role) => [
      for (final entry in settingsMenuEntries)
        if (!entry.adminOnly || role == UserRole.admin) entry,
    ];

/// Settings (the gear on the dashboard): the same pages as before, drawn as the NexaPOS Lite till draws its Settings - a
/// list of rounded rows, each with a chevron, in one column that stays readable on a wide screen.
class SettingsMenuScreen extends ConsumerWidget {
  const SettingsMenuScreen({super.key});

  /// As wide as the Lite till's page.
  static const maxWidth = 860.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: user == null
          ? const SizedBox.shrink()
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxWidth),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    for (final entry in settingsMenuFor(user.role))
                      SettingsMenuRow(
                        key: Key('settings-row-${entry.route}'),
                        title: entry.title,
                        onTap: () => context.push(entry.route),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// One row, like the Lite till's: a raised, rounded tile in the low surface colour, the title on the left and a chevron on
/// the right.
class SettingsMenuRow extends StatelessWidget {
  const SettingsMenuRow({super.key, required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  static const radius = 12.0;
  static const minHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 16, color: scheme.onSurface),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
