import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/services/license_service.dart';

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

    final result = await ref.read(licenseServiceProvider).activate(_codeController.text);
    result.when(
      ok: (_) {},
      failure: (message) => setState(() {
        _submitting = false;
        _error = message;
      }),
    );
  }

  Future<void> _openWhatsApp() async {
    await launchUrl(Uri.parse(_whatsappSupportUrl), mode: LaunchMode.externalApplication);
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
                  Icon(Icons.vpn_key, size: 48, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 8),
                  Text(
                    'Activate NexaPOS',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the license key you received after purchase. This only needs to be done once on this device.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _codeController,
                    decoration: const InputDecoration(labelText: 'License key'),
                    textCapitalization: TextCapitalization.characters,
                    autofocus: true,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your license key' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Activate'),
                  ),
                  const SizedBox(height: 16),
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
