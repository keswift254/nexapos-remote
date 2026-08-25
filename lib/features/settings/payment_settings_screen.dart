import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../data/payments/paystack_gateway.dart' show PaystackException;
import '../../data/payments/platform_http_client.dart' show nexaposPlatformBaseUrl;
import '../../data/payments/platform_onboarding_gateway.dart';
import '../../domain/entities/paystack_credentials.dart';
import '../../domain/services/paystack_credentials_service.dart';
import 'device_management_screen.dart';

part 'payment_settings_screen.g.dart';

@riverpod
Future<PaystackCredentials> currentPaymentCredentials(Ref ref) {
  return ref.watch(paystackCredentialsServiceProvider).load();
}

/// The live source of truth for settlement status - never cached on the
/// phone (see PaystackCredentialsService's class doc) so an operator or
/// dashboard-side change is always reflected next time this screen opens.
@riverpod
Future<ClientStatus?> currentClientStatus(Ref ref) async {
  final credentials = await ref.watch(currentPaymentCredentialsProvider.future);
  if (!credentials.isConfigured) return null;
  return ref
      .watch(platformOnboardingGatewayProvider)
      .getClientStatus(baseUrl: credentials.baseUrl, apiKey: credentials.apiKey);
}

/// Three states: not registered with the payments server yet ->
/// registered but settlement (bank/mobile money) details not saved yet
/// -> active, with an Edit action that reopens the same form pre-filled
/// - saving always succeeds (create the first time, update every time
/// after), so a client can change their settlement details freely
/// without contacting support.
class PaymentSettingsScreen extends ConsumerStatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  ConsumerState<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends ConsumerState<PaymentSettingsScreen> {
  final _registerFormKey = GlobalKey<FormState>();
  final _settlementFormKey = GlobalKey<FormState>();
  final _deviceLabelController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  String _settlementType = 'bank';
  BankOption? _selectedBank;
  List<BankOption> _banks = [];
  bool _loadingBanks = false;
  bool _submitting = false;
  bool _editing = false;
  String? _prefilledForStatus;

  @override
  void dispose() {
    _deviceLabelController.dispose();
    _businessNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _register(PaystackCredentials credentials) async {
    if (!_registerFormKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final deviceId = await ref.read(syncMetadataProvider).deviceId();
      final registrationSecret = await ref.read(syncMetadataProvider).registrationSecret();
      final registration = await ref.read(platformOnboardingGatewayProvider).registerDevice(
            baseUrl: nexaposPlatformBaseUrl,
            deviceId: deviceId,
            deviceLabel: _deviceLabelController.text.trim(),
            registrationSecret: registrationSecret,
          );
      await ref
          .read(paystackCredentialsServiceProvider)
          .save(credentials.copyWith(baseUrl: nexaposPlatformBaseUrl, apiKey: registration.apiKey));
      ref.invalidate(currentPaymentCredentialsProvider);
    } catch (e) {
      _showError(e is PaystackException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _loadBanks(PaystackCredentials credentials, ClientStatus? existing) async {
    if (_banks.isNotEmpty || _loadingBanks) return;
    setState(() => _loadingBanks = true);
    try {
      final banks = await ref
          .read(platformOnboardingGatewayProvider)
          .listBanks(baseUrl: credentials.baseUrl, apiKey: credentials.apiKey);
      if (!mounted) return;
      setState(() {
        _banks = banks;
        // Editing: re-select whichever bank/provider was already saved,
        // so the cashier isn't forced to re-pick it just to tweak the
        // account number.
        if (_selectedBank == null && existing != null) {
          for (final bank in banks) {
            if (bank.code == existing.bankCode) {
              _selectedBank = bank;
              break;
            }
          }
        }
      });
    } catch (e) {
      if (mounted) _showError(e is PaystackException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _loadingBanks = false);
    }
  }

  /// Seeds the form once per distinct status snapshot (keyed by
  /// subaccount_code + whether we're editing) rather than every build,
  /// so typing isn't clobbered by a rebuild.
  void _prefillFrom(ClientStatus status) {
    final key = '${status.subaccountCode}|$_editing';
    if (_prefilledForStatus == key) return;
    _prefilledForStatus = key;
    if (!status.isSettled) return;
    _businessNameController.text = status.businessName;
    _accountNumberController.text = status.accountNumber;
    _settlementType = status.settlementType == 'mpesa' ? 'mpesa' : 'bank';
  }

  /// Switching Bank <-> Mobile Money clears the type-specific fields -
  /// a bank account number and a phone/till number are different data,
  /// and leftover text from the other type was confusing to see.
  void _selectSettlementType(String type) {
    setState(() {
      _settlementType = type;
      _selectedBank = null;
      _accountNumberController.clear();
    });
  }

  Future<void> _saveSettlement(PaystackCredentials credentials) async {
    if (!_settlementFormKey.currentState!.validate()) return;
    if (_selectedBank == null) {
      _showError(_settlementType == 'mpesa' ? 'Select a mobile money provider.' : 'Select a bank.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await ref.read(platformOnboardingGatewayProvider).saveSettlementDetails(
            baseUrl: credentials.baseUrl,
            apiKey: credentials.apiKey,
            businessName: _businessNameController.text.trim(),
            settlementType: _settlementType,
            bankCode: _selectedBank!.code,
            accountNumber: _accountNumberController.text.trim(),
          );
      ref.invalidate(currentClientStatusProvider);
      setState(() => _editing = false);
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Settlement saved'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.accountName.isEmpty ? 'Your settlement details were saved.' : 'Confirm this is your account: ${result.accountName}',
                ),
                const SizedBox(height: 12),
                Text(_settlementTimingNote, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      }
    } on PaystackException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// The only way back to the registration form after the first
  /// registration - see PaystackCredentialsService.clearRegistration.
  /// nexaposPlatformBaseUrl is now a fixed constant (no longer something
  /// an operator picks per device), so this no longer means "point at a
  /// different server" - it means starting this device's registration
  /// over from scratch. Confirmed first since it drops the device's
  /// api_key entirely, not just its settlement details.
  Future<void> _unregisterDevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unregister this device?'),
        content: const Text(
          'This device will need to register again. Settlement details live on the server, not this device, '
          'so re-registering into the same shop there picks them straight back up.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Unregister')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(paystackCredentialsServiceProvider).clearRegistration();
    ref.invalidate(currentPaymentCredentialsProvider);
  }

  String? _requiredValidator(String? value) => (value == null || value.trim().isEmpty) ? 'Required' : null;

  static const _settlementTimingNote =
      'Your share of each sale is paid out automatically to this account on the next business day '
      '(excluding weekends and public holidays) - not instantly.';

  @override
  Widget build(BuildContext context) {
    final credentialsAsync = ref.watch(currentPaymentCredentialsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Settings')),
      body: credentialsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load: $error')),
        data: (credentials) {
          if (!credentials.isConfigured) return _buildRegisterForm(credentials);

          final statusAsync = ref.watch(currentClientStatusProvider);
          return statusAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Failed to load: $error')),
            data: (status) {
              if (status == null) return _buildRegisterForm(credentials);
              // Gated before the settled/editing branch below on purpose -
              // a non-owner device (joined via invite code) can't change
              // settlement whether or not it's ever been set up yet, so
              // this must block the first-time setup form too, not just
              // the Edit button on an already-settled shop. The server
              // enforces this regardless (save_settlement_details 403s
              // either way) - this is just so a non-owner device sees why
              // up front instead of filling in a form that then fails.
              if (!status.isOwner) return _buildNonOwnerView(status);
              if (!status.isSettled || _editing) {
                _prefillFrom(status);
                return _buildSettlementForm(credentials, status.isSettled ? status : null);
              }
              return _buildActiveView(status, credentials);
            },
          );
        },
      ),
    );
  }

  Widget _buildRegisterForm(PaystackCredentials credentials) {
    return Form(
      key: _registerFormKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Register this device so it can accept Paystack payments without needing its own Paystack account.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _deviceLabelController,
            decoration: const InputDecoration(labelText: 'Label for this device (e.g. your shop name)'),
            validator: _requiredValidator,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : () => _register(credentials),
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Register this device'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementForm(PaystackCredentials credentials, ClientStatus? existing) {
    _loadBanks(credentials, existing);
    final filteredBanks =
        _settlementType == 'mpesa' ? _banks.where((bank) => bank.isMobileMoney).toList() : _banks.where((bank) => !bank.isMobileMoney).toList();

    return Form(
      key: _settlementFormKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Tell us where your sales should be paid out.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          TextFormField(
            controller: _businessNameController,
            decoration: const InputDecoration(labelText: 'Business name'),
            validator: _requiredValidator,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Bank'),
                selected: _settlementType == 'bank',
                onSelected: (_) => _selectSettlementType('bank'),
              ),
              ChoiceChip(
                label: const Text('Mobile Money'),
                selected: _settlementType == 'mpesa',
                onSelected: (_) => _selectSettlementType('mpesa'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _loadingBanks
              ? const LinearProgressIndicator()
              : DropdownButtonFormField<BankOption>(
                  initialValue: _selectedBank,
                  decoration: InputDecoration(labelText: _settlementType == 'mpesa' ? 'Provider' : 'Bank'),
                  items: filteredBanks.map((bank) => DropdownMenuItem(value: bank, child: Text(bank.name))).toList(),
                  onChanged: (bank) => setState(() => _selectedBank = bank),
                  validator: (value) => value == null ? 'Required' : null,
                ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _accountNumberController,
            decoration: InputDecoration(
              labelText: _settlementType == 'bank' ? 'Account number' : 'Phone or till number',
            ),
            keyboardType: _settlementType == 'bank' ? TextInputType.number : TextInputType.phone,
            validator: _requiredValidator,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : () => _saveSettlement(credentials),
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
          if (_editing) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => setState(() {
                        _editing = false;
                        _prefilledForStatus = null;
                      }),
              child: const Text('Cancel'),
            ),
          ],
          if (!_editing) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _submitting ? null : _unregisterDevice,
                child: const Text('Unregister this device'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// A device that joined this shop via invite code, rather than the
  /// one that originally set it up - can see the same status info the
  /// owner's device sees (useful for a cashier fielding a customer
  /// question), just never a way to change it. Shown whether or not
  /// settlement has ever been configured yet, matching the server-side
  /// gate which doesn't distinguish first-time setup from editing.
  Widget _buildNonOwnerView(ClientStatus status) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.outline, size: 48),
        const SizedBox(height: 12),
        Center(
          child: Text('Settlement details are locked on this device.', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Only the device that originally set up this shop can view or change where payments are sent.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (status.isSettled) ...[
          const SizedBox(height: 20),
          const Icon(Icons.check_circle, color: Colors.green, size: 32),
          const SizedBox(height: 8),
          Center(child: Text(status.businessName, style: Theme.of(context).textTheme.bodyMedium)),
          Center(
            child: Text(
              '${status.settlementType == 'mpesa' ? 'Mobile Money' : 'Bank'}: ${status.accountNumber}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActiveView(ClientStatus status, PaystackCredentials credentials) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.check_circle, color: Colors.green, size: 48),
        const SizedBox(height: 12),
        Center(child: Text('Payments are set up.', style: Theme.of(context).textTheme.titleMedium)),
        const SizedBox(height: 4),
        Center(child: Text(status.businessName, style: Theme.of(context).textTheme.bodyMedium)),
        Center(
          child: Text(
            '${status.settlementType == 'mpesa' ? 'Mobile Money' : 'Bank'}: ${status.accountNumber}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 16),
        Text(_settlementTimingNote, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 20),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => setState(() {
              _editing = true;
              _prefilledForStatus = null;
            }),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit settlement details'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => DeviceManagementScreen(credentials: credentials)),
            ),
            icon: const Icon(Icons.devices_outlined),
            label: const Text('Manage devices'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _unregisterDevice,
            child: const Text('Unregister this device'),
          ),
        ),
      ],
    );
  }
}
