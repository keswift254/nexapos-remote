import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/update/update_gateway.dart';
import '../../domain/services/update_service.dart';

/// Reachable from the dashboard's Settings menu ("Check for Updates")
/// and from the dashboard's own update-available banner tap - both just
/// push this route, which always runs its own fresh check on open
/// rather than trusting whatever UpdateAvailabilityNotifier happened to
/// cache last (that cache is only good enough for "should the banner
/// show at all", not for what this screen tells the user to install).
class UpdateScreen extends ConsumerStatefulWidget {
  const UpdateScreen({super.key});

  @override
  ConsumerState<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends ConsumerState<UpdateScreen> {
  bool _checking = true;
  bool _installing = false;
  double _progress = 0;
  String? _error;
  UpdateCheckResult? _result;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final result = await ref.read(updateServiceProvider).checkForUpdate();
      if (!mounted) return;
      ref.read(updateAvailabilityProvider.notifier).applyResult(result);
      setState(() {
        _result = result;
        _checking = false;
      });
    } on UpdateOfflineException {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'Could not reach the update server. Check your internet connection and try again.';
      });
    } on UpdateException catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'Could not check for updates: $e';
      });
    }
  }

  Future<void> _install() async {
    final latest = _result?.latest;
    if (latest == null) return;
    setState(() {
      _installing = true;
      _progress = 0;
      _error = null;
    });
    final result = await ref.read(updateServiceProvider).install(
          latest,
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
        );
    // On a successful Windows install, the app has already called exit()
    // inside install() - this line is unreached there. Android reaches
    // here either way, since its installer runs as a separate activity
    // on top of (not instead of) this one.
    if (!mounted) return;
    result.when(
      ok: (_) {
        setState(() => _installing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Installer opened - finish the install there, then reopen NexaPOS.')),
        );
      },
      failure: (message) {
        setState(() {
          _installing = false;
          _error = message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Software Update')),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_result != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.smartphone),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Installed version', style: theme.textTheme.labelLarge),
                                Text(_result!.currentVersion, style: theme.textTheme.titleMedium),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_result!.updateAvailable && _result!.latest != null) ...[
                    Card(
                      color: theme.colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Update available: ${_result!.latest!.version}',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if ((_result!.latest!.releaseNotes ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(_result!.latest!.releaseNotes!),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_installing) ...[
                      LinearProgressIndicator(value: _progress > 0 ? _progress : null),
                      const SizedBox(height: 8),
                      Text(
                        _progress < 0.9 ? 'Downloading... ${(_progress * 100).round()}%' : 'Installing...',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ] else
                      FilledButton.icon(
                        onPressed: _install,
                        icon: const Icon(Icons.system_update_alt),
                        label: const Text('Download & Install'),
                      ),
                  ] else
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        const Text("You're on the latest version."),
                      ],
                    ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _installing ? null : _check,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check for Updates'),
                ),
              ],
            ),
    );
  }
}
