import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/app_security_service.dart';
import '../../domain/services/session_service.dart';

/// The dashboard's nudge to set up quick sign in (fingerprint, face or Windows
/// Hello) - nothing at all where the device cannot do it, where somebody has
/// already set it up on this device, or for 72 hours after "Dismiss".
///
/// Tapping the message starts the setup right there (the device asks the person
/// to prove it is them, the same as Settings > Privacy), so it is one step, not a
/// trip through the settings.
class BiometricSetupBanner extends ConsumerStatefulWidget {
  const BiometricSetupBanner({super.key});

  @override
  ConsumerState<BiometricSetupBanner> createState() =>
      _BiometricSetupBannerState();
}

class _BiometricSetupBannerState extends ConsumerState<BiometricSetupBanner> {
  /// A dashboard can stay open for days at a till: look again now and then, so a
  /// dismissed reminder returns without anyone having to leave the screen.
  static const _lookAgainEvery = Duration(minutes: 10);

  bool _show = false;
  bool _busy = false;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _evaluate();
    _timer = Timer.periodic(_lookAgainEvery, (_) => _evaluate());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _evaluate() async {
    final user = ref.read(sessionProvider);
    var show = false;
    if (user != null) {
      try {
        show = await ref
            .read(appSecurityServiceProvider)
            .shouldRemindBiometricSetup(user);
      } catch (_) {
        show = false;
      }
    }
    if (!mounted || _busy) return;
    setState(() {
      _show = show;
      if (!show) _error = null;
    });
  }

  Future<void> _setUp() async {
    final user = ref.read(sessionProvider);
    if (user == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(appSecurityServiceProvider).enableFor(user);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _show = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_name sign in is on.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is StateError ? error.message : 'Could not set it up: $error';
      });
    }
  }

  Future<void> _dismiss() async {
    final user = ref.read(sessionProvider);
    setState(() => _show = false);
    if (user == null) return;
    try {
      await ref.read(appSecurityServiceProvider).dismissBiometricReminder(user);
    } catch (_) {
      // Worst case it shows again next time - never worth an error.
    }
  }

  bool get _isWindows => defaultTargetPlatform == TargetPlatform.windows;

  String get _name => _isWindows ? 'Windows Hello' : 'Fingerprint or face';

  @override
  Widget build(BuildContext context) {
    // A different person signing in gets their own answer.
    ref.listen(sessionProvider, (_, _) => _evaluate());
    if (!_show) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        key: const Key('biometric-setup-banner'),
        color: theme.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.fingerprint, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      key: const Key('biometric-setup-tap'),
                      onTap: _busy ? null : _setUp,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '${_isWindows ? 'Click' : 'Tap'} here to set up '
                          'biometrics for easier login',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    TextButton(
                      key: const Key('biometric-setup-dismiss'),
                      onPressed: _dismiss,
                      child: const Text('Dismiss'),
                    ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(36, 0, 8, 4),
                  child: Text(
                    _error!,
                    key: const Key('biometric-setup-error'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
