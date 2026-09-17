import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/payments/platform_http_client.dart' show PaystackException;
import '../../data/payments/platform_onboarding_gateway.dart';
import '../../domain/entities/paystack_credentials.dart';
import 'payment_settings_screen.dart' show currentPaymentCredentialsProvider;

/// Reachable straight from General Settings (not just via Payment
/// Settings), so it needs to load this device's own platform
/// credentials itself rather than requiring a caller that already has
/// them in hand - DeviceManagementScreen below stays exactly as
/// PaymentSettingsScreen's own entry point already constructs it.
class ConnectedDevicesEntryScreen extends ConsumerWidget {
  const ConnectedDevicesEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credentialsAsync = ref.watch(currentPaymentCredentialsProvider);
    return credentialsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Connected Devices')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Connected Devices')),
        body: Center(child: Text('Failed to load: $error')),
      ),
      data: (credentials) => credentials.isConfigured
          ? DeviceManagementScreen(credentials: credentials)
          : Scaffold(
              appBar: AppBar(title: const Text('Connected Devices')),
              body: const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'This device isn\'t registered with a shop yet - set that up first from Payment Settings or Device Sync.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
    );
  }
}

/// Owner-only (the entry point in PaymentSettingsScreen only shows for
/// an owner device, and the server enforces the same gate independently
/// - see list_devices/revoke_device in nexapos_platform). Lets the shop
/// founder see every device currently able to sync this shop's data and
/// cut one off immediately - the fix for a gap where a lost, stolen, or
/// ex-employee device stayed a fully-trusted peer forever, since nothing
/// could ever move it out of 'active'. Revoking here wipes the target
/// device's local data and returns it to the activation screen the next
/// time it makes an authenticated call - see LicenseService's own
/// _blockMembership doc for that side of it.
class DeviceManagementScreen extends ConsumerStatefulWidget {
  final PaystackCredentials credentials;
  const DeviceManagementScreen({super.key, required this.credentials});

  @override
  ConsumerState<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends ConsumerState<DeviceManagementScreen> {
  late Future<List<DeviceInfo>> _devicesFuture;
  int? _revokingId;

  @override
  void initState() {
    super.initState();
    _devicesFuture = _load();
  }

  Future<List<DeviceInfo>> _load() {
    return ref
        .read(platformOnboardingGatewayProvider)
        .listDevices(baseUrl: widget.credentials.baseUrl, apiKey: widget.credentials.apiKey);
  }

  void _reload() => setState(() => _devicesFuture = _load());

  Future<void> _confirmRevoke(DeviceInfo device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Revoke "${device.deviceLabel}"?'),
        content: const Text(
          'This device will immediately lose access to this shop\'s data and cannot sync again. The next time it '
          'connects, its local data is wiped and it returns to the activation screen - this cannot be undone from '
          'here. To let the same physical device back in later, it would need to register again with a fresh '
          'invite code.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _revokingId = device.id);
    try {
      await ref
          .read(platformOnboardingGatewayProvider)
          .revokeDevice(baseUrl: widget.credentials.baseUrl, apiKey: widget.credentials.apiKey, clientId: device.id);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is PaystackException ? e.message : '$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _revokingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connected Devices')),
      body: FutureBuilder<List<DeviceInfo>>(
        future: _devicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return Center(child: Text(error is PaystackException ? error.message : 'Failed to load: $error'));
          }
          final devices = snapshot.data ?? const [];
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: devices.length,
            separatorBuilder: (context, _) => const Divider(),
            itemBuilder: (context, index) {
              final device = devices[index];
              return ListTile(
                leading: Icon(
                  device.isDisabled
                      ? Icons.phonelink_erase
                      : device.isOnline
                          ? Icons.smartphone
                          : Icons.smartphone_outlined,
                  color: device.isDisabled
                      ? null
                      : device.isOnline
                          ? Colors.green
                          : null,
                ),
                title: Text(device.deviceLabel.isEmpty ? 'Unnamed device' : device.deviceLabel),
                subtitle: Text(_statusLabel(device)),
                trailing: device.isOwner || device.isDisabled
                    ? null
                    : _revokingId == device.id
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                            icon: const Icon(Icons.block),
                            tooltip: 'Revoke this device',
                            onPressed: () => _confirmRevoke(device),
                          ),
              );
            },
          );
        },
      ),
    );
  }

  String _statusLabel(DeviceInfo device) {
    if (device.isOwner) return 'Owner (this device)';
    if (device.isDisabled) return 'Revoked';
    if (device.isOnline) return 'Online';
    final lastSeen = device.lastSeenAt;
    if (lastSeen == null) return 'Offline - never checked in';
    return 'Offline for ${_formatDuration(DateTime.now().toUtc().difference(lastSeen))}';
  }

  // Mirrors dashboard.html's formatDuration.
  String _formatDuration(Duration elapsed) {
    final days = elapsed.inDays;
    final hours = elapsed.inHours % 24;
    final minutes = elapsed.inMinutes % 60;
    if (days > 0) return '${days}d ${hours}h';
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m';
    return '${elapsed.inSeconds}s';
  }
}
