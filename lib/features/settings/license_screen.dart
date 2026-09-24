import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../domain/services/license_service.dart';

/// Settings > License: whether this device's license is active, expired or
/// revoked, and how long is left. Shows what the device has saved straight
/// away, then asks the license server so a revoke or an extension made by
/// the vendor shows up here without waiting for the app's own 15-second
/// check. A device that is offline just keeps showing the saved answer -
/// the same one the app itself enforces.
///
/// An expired or revoked license also locks the whole app back to the
/// activation screen within seconds (LicenseService.backgroundVerify), so
/// those two states are mostly seen in the moments before that happens.
class LicenseScreen extends ConsumerStatefulWidget {
  const LicenseScreen({super.key});

  @override
  ConsumerState<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends ConsumerState<LicenseScreen> {
  LicenseStatus? _status;
  String? _deviceId;
  bool _checking = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Re-reads the clock every second; the countdown itself is computed in
    // build from the injected clock, never accumulated here.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final service = ref.read(licenseServiceProvider);
    try {
      final deviceId = await ref.read(syncMetadataProvider).deviceId();
      final saved = await service.currentStatus(askServer: false);
      if (!mounted) return;
      setState(() {
        _deviceId = deviceId;
        _status = saved;
        _checking = true;
      });
    } catch (_) {
      if (!mounted) return;
    }
    await _refreshFromServer();
  }

  Future<void> _refreshFromServer() async {
    if (mounted) setState(() => _checking = true);
    LicenseStatus? live;
    try {
      live = await ref.read(licenseServiceProvider).currentStatus();
    } catch (_) {
      // Keep showing whatever is already on screen.
    }
    if (!mounted) return;
    setState(() {
      _status = live ?? _status;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      appBar: AppBar(
        title: const Text('License'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Check again',
            onPressed: _checking ? null : _refreshFromServer,
          ),
        ],
      ),
      body: status == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatusCard(
                  status: status,
                  now: ref.read(clockProvider).now(),
                ),
                const SizedBox(height: 12),
                _SourceNote(status: status, checking: _checking),
                if (_deviceId != null) ...[
                  const SizedBox(height: 24),
                  _DeviceIdTile(deviceId: _deviceId!),
                ],
              ],
            ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.now});

  final LicenseStatus status;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // An active license whose end passed while this screen was open is
    // expired now, not "active with 0 seconds left".
    var state = status.state;
    final validUntil = status.validUntil;
    if (state == LicenseState.active &&
        validUntil != null &&
        !validUntil.isAfter(now)) {
      state = LicenseState.expired;
    }

    final (label, color, icon) = switch (state) {
      LicenseState.active => ('Active', Colors.green.shade700, Icons.verified),
      LicenseState.expired => (
        'Expired',
        Colors.orange.shade800,
        Icons.event_busy,
      ),
      LicenseState.revoked => ('Revoked', scheme.error, Icons.block),
      LicenseState.joined => (
        'Joined device',
        scheme.primary,
        Icons.devices,
      ),
      LicenseState.notActivated => (
        'Not activated',
        scheme.outline,
        Icons.help_outline,
      ),
    };

    final children = <Widget>[
      Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
    ];

    switch (state) {
      case LicenseState.active:
        if (validUntil == null) {
          children.add(const Text('This license never expires.'));
        } else {
          children.addAll([
            Text('Expires on ${_formatDateTime(validUntil)}'),
            const SizedBox(height: 16),
            Text('Time remaining', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            _Countdown(remaining: validUntil.difference(now)),
          ]);
        }
      case LicenseState.expired:
        children.add(
          Text(
            validUntil == null
                ? 'This license has expired. Contact NexaPOS to renew it.'
                : 'This license ran out on ${_formatDateTime(validUntil)}. '
                      'Contact NexaPOS to renew it.',
          ),
        );
      case LicenseState.revoked:
        children.add(
          const Text(
            'This license has been revoked. Contact NexaPOS support if you '
            'think this is a mistake.',
          ),
        );
      case LicenseState.joined:
        final verified = status.joinedVerifiedAt;
        children.add(
          const Text(
            'This device has no license of its own - it uses the shop it '
            'joined. It stays active as long as it can confirm with the shop '
            'over the internet at least once every 24 hours.',
          ),
        );
        if (verified != null) {
          final deadline = verified.add(joinedMembershipGrace);
          children.add(const SizedBox(height: 16));
          if (deadline.isAfter(now)) {
            children.addAll([
              Text(
                'Time left before it must reconnect',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              _Countdown(remaining: deadline.difference(now)),
            ]);
          } else {
            children.add(
              const Text(
                'Connect to the internet to keep using NexaPOS.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          }
        }
      case LicenseState.notActivated:
        children.add(const Text('This device has not been activated.'));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) =>
    DateFormat('d MMM yyyy, HH:mm').format(value.toLocal());

class _Countdown extends StatelessWidget {
  const _Countdown({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final left = remaining.isNegative ? Duration.zero : remaining;
    final units = <(String, int)>[
      ('Days', left.inDays),
      ('Hours', left.inHours.remainder(24)),
      ('Minutes', left.inMinutes.remainder(60)),
      ('Seconds', left.inSeconds.remainder(60)),
    ];
    return Row(
      children: [
        for (final (name, value) in units)
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    value.toString().padLeft(2, '0'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(name, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SourceNote extends StatelessWidget {
  const _SourceNote({required this.status, required this.checking});

  final LicenseStatus status;
  final bool checking;

  @override
  Widget build(BuildContext context) {
    final String text;
    if (checking) {
      text = 'Checking with the license server...';
    } else if (status.state == LicenseState.joined ||
        status.state == LicenseState.notActivated) {
      return const SizedBox.shrink();
    } else if (status.checkedWithServer) {
      text = 'Confirmed with the license server just now.';
    } else {
      text =
          'Could not reach the license server - showing what is saved on '
          'this device.';
    }
    return Text(text, style: Theme.of(context).textTheme.bodySmall);
  }
}

class _DeviceIdTile extends StatelessWidget {
  const _DeviceIdTile({required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: const Text('Device ID'),
        subtitle: SelectableText(deviceId),
        trailing: IconButton(
          icon: const Icon(Icons.copy),
          tooltip: 'Copy device ID',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: deviceId));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Device ID copied')),
            );
          },
        ),
      ),
    );
  }
}
