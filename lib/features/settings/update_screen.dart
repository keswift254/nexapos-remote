import 'package:flutter/foundation.dart' show kIsWeb;
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
  String? _error;
  UpdateCheckResult? _result;

  @override
  void initState() {
    super.initState();
    // Skip the redundant re-check if a download from before navigating
    // away is already running - updateInstallProvider is
    // keepAlive and already carries what's being installed (see its
    // .info field), so re-checking here would just flash a loading
    // spinner over progress that's already known.
    if (ref.read(updateInstallProvider).installing) {
      _checking = false;
    } else {
      _check();
    }
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

  void _install() {
    final latest = _result?.latest ?? ref.read(updateInstallProvider).info;
    if (latest == null) return;
    // Fire-and-forget: the notifier owns the Future from here, keeping it
    // running (and its progress visible to whichever screen is watching
    // it) no matter what this widget does next, including being disposed
    // by navigating away.
    ref.read(updateInstallProvider.notifier).start(latest);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final installState = ref.watch(updateInstallProvider);
    ref.listen<UpdateInstallState>(updateInstallProvider, (previous, next) {
      final finishedOk = (previous?.installing ?? false) && !next.installing && next.error == null;
      if (!finishedOk) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Installer opened - finish the install there, then reopen NexaPOS.')),
      );
      // Android reaches here (Windows already called exit(0) on success) -
      // re-check so "You're on the latest version" reflects reality once
      // the OS installer actually finishes, next time this screen opens.
      _check();
    });

    final latest = _result?.latest ?? installState.info;
    final updateAvailable = _result != null ? _result!.updateAvailable : installState.info != null;

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
                ],
                if (updateAvailable && latest != null) ...[
                  Card(
                    color: theme.colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Update available: ${latest.version}',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if ((latest.releaseNotes ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(latest.releaseNotes!),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (kIsWeb)
                    // The browser edition has no installer to download -
                    // it updates itself the next time the page loads fresh,
                    // once the newly-deployed version is live. Showing the
                    // same "Download & Install" button as native here would
                    // always fail with "not available on this platform yet",
                    // which reads as broken rather than as the different
                    // (and simpler) way web actually updates.
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'The browser version updates itself - reload NexaPOS in your browser to get this version.',
                          ),
                        ),
                      ],
                    )
                  else if (installState.installing) ...[
                    LinearProgressIndicator(value: installState.progress > 0 ? installState.progress : null),
                    const SizedBox(height: 8),
                    Text(
                      installState.progress < 0.9
                          ? 'Downloading... ${(installState.progress * 100).round()}%'
                          : 'Installing...',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ] else
                    FilledButton.icon(
                      onPressed: _install,
                      icon: const Icon(Icons.system_update_alt),
                      label: const Text('Download & Install'),
                    ),
                ] else if (_result != null)
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      const Text("You're on the latest version."),
                    ],
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                if (installState.error != null) ...[
                  const SizedBox(height: 16),
                  Text(installState.error!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: installState.installing ? null : _check,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check for Updates'),
                ),
              ],
            ),
    );
  }
}
