import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/services/license_service.dart';
import '../../core/providers.dart';
import '../../data/payments/platform_http_client.dart';
import '../../data/payments/platform_onboarding_gateway.dart';
import '../../domain/entities/paystack_credentials.dart';
import '../../domain/services/paystack_credentials_service.dart';

const _whatsappSupportUrl = 'https://wa.me/message/M5SGWZ664XJ4C1';

/// Shown before setup/login whenever no cached activation token exists
/// - the app-wide gate a purchased license key unlocks once, per
/// device. Mirrors setup_screen.dart/login_screen.dart's structure: no
/// manual navigation on success, the redirect guard in app.dart reacts
/// to LicenseChangeSignal and routes away on its own.
class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

/// Tells a user who landed here because their license ended WHY (it ran out,
/// it was revoked, or the device clock looks set back) instead of leaving a
/// bare "Activate NexaPOS" that reads like a fresh install. Nothing is shown
/// for a device that was never licensed. Reloads when the license changes,
/// because the app locks itself onto this screen a moment BEFORE the
/// reason is recorded in some cases (see LicenseService.endedLicense).
class _LicenseEndedBanner extends ConsumerStatefulWidget {
  const _LicenseEndedBanner();

  @override
  ConsumerState<_LicenseEndedBanner> createState() =>
      _LicenseEndedBannerState();
}

class _LicenseEndedBannerState extends ConsumerState<_LicenseEndedBanner> {
  LicenseEnd? _end;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    LicenseEnd? end;
    try {
      end = await ref.read(licenseServiceProvider).endedLicense();
    } catch (_) {
      // No notice is better than a broken activation screen.
    }
    if (!mounted) return;
    setState(() => _end = end);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(licenseChangeSignalProvider, (_, _) => _load());
    final end = _end;
    if (end == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final validUntil = end.validUntil;
    final ranOutOn = validUntil == null
        ? ''
        : 'It ran out on '
              '${DateFormat('d MMM yyyy, HH:mm').format(validUntil.toLocal())}. ';
    final (title, body, color, icon) = switch (end.reason) {
      LicenseEndReason.expired => (
        'Your license has expired',
        '${ranOutOn}Contact NexaPOS to renew it, then enter your license key '
            'below to continue.',
        Colors.orange.shade800,
        Icons.event_busy,
      ),
      LicenseEndReason.revoked => (
        'Your license was revoked',
        'Contact NexaPOS support if you think this is a mistake. If it has '
            'been restored, enter your license key below to continue.',
        scheme.error,
        Icons.block,
      ),
      LicenseEndReason.clockSetBack => (
        "This device's date or time looks wrong",
        'NexaPOS locked itself because the clock on this device was set '
            "back, so your license's end date can't be trusted. Correct the "
            'date and time, then enter your license key below to continue.',
        Colors.orange.shade800,
        Icons.schedule,
      ),
    };

    return _NoticeBox(color: color, icon: icon, title: title, body: body);
  }
}

/// For a device that joined a shop and got locked out only because it has not
/// been able to confirm its shop access online lately. The activation screen
/// it lands on otherwise looks like a fresh install; this says what is
/// actually going on, and that nothing has been lost. Nothing to tap: the
/// app re-checks by itself every few seconds while it runs, and leaves this
/// screen on its own once a check gets through.
class _JoinedAccessBanner extends ConsumerStatefulWidget {
  const _JoinedAccessBanner();

  @override
  ConsumerState<_JoinedAccessBanner> createState() =>
      _JoinedAccessBannerState();
}

class _JoinedAccessBannerState extends ConsumerState<_JoinedAccessBanner> {
  bool _needsInternet = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var needsInternet = false;
    try {
      needsInternet = await ref
          .read(licenseServiceProvider)
          .joinedShopNeedsInternet();
    } catch (_) {
      // No notice is better than a broken activation screen.
    }
    if (!mounted) return;
    setState(() => _needsInternet = needsInternet);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(licenseChangeSignalProvider, (_, _) => _load());
    if (!_needsInternet) return const SizedBox.shrink();
    return _NoticeBox(
      color: Theme.of(context).colorScheme.primary,
      icon: Icons.wifi_off,
      title: 'Connect to the internet to confirm your shop access',
      body:
          'Your data is safe. This device has to confirm its shop access '
          'online at least once every ${joinedMembershipGrace.inHours} hours. '
          'It reopens by itself as soon as it is connected - there is '
          'nothing to enter.',
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await ref
        .read(licenseServiceProvider)
        .activate(_codeController.text);
    result.when(
      ok: (_) => unawaited(_registerPrimaryDevice()),
      failure: (message) => setState(() {
        _submitting = false;
        _error = message;
      }),
    );
  }

  Future<void> _registerPrimaryDevice() async {
    final credentialsService = ref.read(paystackCredentialsServiceProvider);
    final syncMetadata = ref.read(syncMetadataProvider);
    final onboarding = ref.read(platformOnboardingGatewayProvider);
    try {
      final credentials = await credentialsService.load();
      if (credentials.isConfigured) return;
      final registration = await onboarding.registerDevice(
            baseUrl: nexaposPlatformBaseUrl,
            deviceId: await syncMetadata.deviceId(),
            deviceLabel: 'Primary device',
            registrationSecret: await syncMetadata.registrationSecret(),
          );
      await credentialsService.save(
            PaystackCredentials(
              baseUrl: nexaposPlatformBaseUrl,
              apiKey: registration.apiKey,
              currency: 'KES',
              defaultEmail: '',
            ),
          );
      await credentialsService.saveDeviceLabel('Primary device');
    } catch (_) {
      // Setup remains usable offline; Device Sync can retry registration later.
    }
  }

  Future<void> _openWhatsApp() async {
    await launchUrl(
      Uri.parse(_whatsappSupportUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _LicenseEndedBanner(),
                  const _JoinedAccessBanner(),
                  Icon(
                    Icons.vpn_key,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Activate NexaPOS',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the license key you received after purchase.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _codeController,
                    decoration: const InputDecoration(labelText: 'License key'),
                    textCapitalization: TextCapitalization.characters,
                    autofocus: true,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your license key'
                        : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Activate'),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _submitting
                        ? null
                        : () => context.go('/join-shop'),
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('Join an existing shop'),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<bool>(
                    future: ref.read(licenseServiceProvider).membershipBlocked,
                    builder: (context, snapshot) => snapshot.data == true
                        ? const Text(
                            'Shop access ended. Your local records are retained. Contact support for recovery.',
                          )
                        : const SizedBox.shrink(),
                  ),
                  Text(
                    "Don't have a license key? Tap the WhatsApp button below to chat with our agent and get one.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _openWhatsApp,
                    icon: const Icon(Icons.chat_bubble),
                    label: const Text('Tap here to start WhatsApp chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
