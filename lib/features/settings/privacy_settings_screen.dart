import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/app_lock_settings.dart';
import '../../domain/services/app_security_service.dart';
import '../../domain/services/session_service.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  bool _saving = false;

  Future<void> _setBiometric(bool enabled) async {
    final user = ref.read(sessionProvider);
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final service = ref.read(appSecurityServiceProvider);
      if (enabled) {
        await service.enableFor(user);
      } else {
        await service.disable();
      }
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error is StateError ? error.message : '$error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockMinutes = ref.watch(appLockSettingsProvider);
    final authenticationName = defaultTargetPlatform == TargetPlatform.windows
        ? 'Windows Hello'
        : 'Fingerprint or face recognition';
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('App lock', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                key: ValueKey(lockMinutes),
            initialValue: lockMinutes,
            decoration: const InputDecoration(labelText: 'Lock NexaPOS after'),
            items: const [
              DropdownMenuItem(
                value: 0,
                child: Text('Immediately when app is left'),
              ),
              DropdownMenuItem(value: 1, child: Text('1 minute')),
              DropdownMenuItem(value: 5, child: Text('5 minutes')),
              DropdownMenuItem(value: 30, child: Text('30 minutes')),
            ],
            onChanged: (value) {
              if (value != null) {
                ref.read(appLockSettingsProvider.notifier).setMinutes(value);
              }
            },
          ),
          const SizedBox(height: 24),
          Text('Quick sign in', style: Theme.of(context).textTheme.titleMedium),
          FutureBuilder<bool>(
            future: ref
                .read(appSecurityServiceProvider)
                .isBiometricLoginEnabled,
            builder: (context, snapshot) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(authenticationName),
              subtitle: const Text(
                'Uses this device security. Your NexaPOS password is never stored.',
              ),
              value: snapshot.data == true,
              onChanged: _saving ? null : _setBiometric,
            ),
          ),
        ],
      ),
    );
  }
}
