import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../data/payments/paystack_gateway.dart' show PaystackException;
import '../../data/payments/platform_onboarding_gateway.dart';
import '../../data/sync/lan_discovery.dart';
import '../../domain/entities/paystack_credentials.dart';
import '../../domain/services/paystack_credentials_service.dart';
import '../../domain/services/sync_service.dart';
import 'payment_settings_screen.dart' show currentPaymentCredentialsProvider;

/// Reachable on its own from the dashboard's Settings menu - deliberately
/// NOT nested inside Payment Settings the way device sync used to be. A
/// shop that only wants multiple devices sharing sales/inventory/reports,
/// with no interest in Paystack at all, used to have to go find "Payment
/// Settings" and register through a form that only talked about accepting
/// payments to reach this. Registration itself (baseUrl + api_key from
/// register_device) is unchanged and still shared with Payment Settings -
/// this is a reachability/framing fix, not a new backend concept.
class DeviceSyncScreen extends ConsumerStatefulWidget {
  const DeviceSyncScreen({super.key});

  @override
  ConsumerState<DeviceSyncScreen> createState() => _DeviceSyncScreenState();
}

class _DeviceSyncScreenState extends ConsumerState<DeviceSyncScreen> {
  final _deviceLabelController = TextEditingController();
  final _newShopUrlController = TextEditingController(text: 'http://localhost/nexapos_platform/public/index.php');
  final _manualUrlController = TextEditingController();
  final _manualCodeController = TextEditingController();

  bool _joinExisting = false;
  bool _submitting = false;
  bool _scanning = false;
  List<DiscoveredHost> _discovered = const [];
  LanHostScanner? _scanner;
  StreamSubscription<List<DiscoveredHost>>? _scanSub;

  LanHostAdvertiser? _advertiser;
  InviteResult? _generatedInvite;
  Timer? _countdownTimer;
  Duration? _timeRemaining;
  bool _generating = false;

  bool _scanningOther = false;
  List<DiscoveredHost> _discoveredOther = const [];
  LanHostScanner? _scannerOther;
  StreamSubscription<List<DiscoveredHost>>? _scanSubOther;
  final _manualUrlOtherController = TextEditingController();
  final _manualCodeOtherController = TextEditingController();
  bool _submittingOther = false;

  @override
  void dispose() {
    _deviceLabelController.dispose();
    _newShopUrlController.dispose();
    _manualUrlController.dispose();
    _manualCodeController.dispose();
    _manualUrlOtherController.dispose();
    _manualCodeOtherController.dispose();
    _scanSub?.cancel();
    _scanner?.dispose();
    _scanSubOther?.cancel();
    _scannerOther?.dispose();
    _advertiser?.stop();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // --- First-time registration (not yet connected to any server) ---

  Future<void> _startScanning() async {
    setState(() => _scanning = true);
    final scanner = LanHostScanner();
    _scanner = scanner;
    _scanSub = scanner.hosts.listen((hosts) => setState(() => _discovered = hosts));
    await scanner.start();
  }

  Future<void> _stopScanning() async {
    await _scanSub?.cancel();
    await _scanner?.stop();
    _scanner = null;
    if (mounted) setState(() { _scanning = false; _discovered = const []; });
  }

  Future<void> _registerNewShop() async {
    final label = _deviceLabelController.text.trim();
    if (label.isEmpty) return _showMessage('Enter a label for this device.');
    await _register(baseUrl: _newShopUrlController.text.trim(), inviteCode: null);
  }

  Future<void> _joinDiscovered(DiscoveredHost host) async {
    final label = _deviceLabelController.text.trim();
    if (label.isEmpty) return _showMessage('Enter a label for this device first.');
    await _register(baseUrl: host.baseUrl, inviteCode: host.code);
  }

  Future<void> _joinManually() async {
    final label = _deviceLabelController.text.trim();
    if (label.isEmpty) return _showMessage('Enter a label for this device.');
    final baseUrl = _manualUrlController.text.trim();
    final code = _manualCodeController.text.trim();
    if (baseUrl.isEmpty) return _showMessage('Enter the shop server address.');
    if (code.isEmpty) return _showMessage('Enter the invite code.');
    await _register(baseUrl: baseUrl, inviteCode: code);
  }

  Future<void> _register({required String baseUrl, required String? inviteCode}) async {
    setState(() => _submitting = true);
    try {
      final deviceId = await ref.read(syncMetadataProvider).deviceId();
      final registrationSecret = await ref.read(syncMetadataProvider).registrationSecret();
      final registration = await ref.read(platformOnboardingGatewayProvider).registerDevice(
            baseUrl: baseUrl,
            deviceId: deviceId,
            deviceLabel: _deviceLabelController.text.trim(),
            registrationSecret: registrationSecret,
          );
      if (inviteCode != null) {
        await ref.read(platformOnboardingGatewayProvider).joinShop(
              baseUrl: baseUrl,
              apiKey: registration.apiKey,
              inviteCode: inviteCode,
            );
        await ref.read(syncMetadataProvider).resetCursors();
      }
      await ref
          .read(paystackCredentialsServiceProvider)
          .save(PaystackCredentials(baseUrl: baseUrl, apiKey: registration.apiKey, currency: 'KES', defaultEmail: ''));
      await ref.read(paystackCredentialsServiceProvider).saveDeviceLabel(_deviceLabelController.text.trim());
      ref.invalidate(currentPaymentCredentialsProvider);
      _showMessage(inviteCode != null
          ? 'Connected - your data will sync with the rest of that shop shortly.'
          : 'This device is now set up as its own shop.');
      unawaited(_safeSyncNow());
    } catch (e) {
      _showMessage(e is PaystackException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // --- Already connected: add another device, or join a different shop ---

  Future<void> _generateInvite(PaystackCredentials credentials) async {
    setState(() => _generating = true);
    try {
      final invite = await ref
          .read(platformOnboardingGatewayProvider)
          .generateInvite(baseUrl: credentials.baseUrl, apiKey: credentials.apiKey);
      if (!mounted) return;
      setState(() => _generatedInvite = invite);
      _startCountdown(invite.expiresAt);
      final label = await ref.read(paystackCredentialsServiceProvider).loadDeviceLabel();
      final advertiser = LanHostAdvertiser();
      _advertiser = advertiser;
      await advertiser.start(
        deviceLabel: label.isEmpty ? 'NexaPOS shop' : label,
        baseUrl: credentials.baseUrl,
        code: invite.code,
      );
    } catch (e) {
      _showMessage(e is PaystackException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _startCountdown(String expiresAt) {
    _countdownTimer?.cancel();
    // expires_at comes back as a MySQL UTC datetime string ("2026-08-22
    // 11:18:28"), not ISO8601 - space instead of 'T', no zone suffix.
    final expiry = DateTime.tryParse('${expiresAt.replaceFirst(' ', 'T')}Z');
    if (expiry == null) return;
    void tick() {
      final remaining = expiry.difference(DateTime.now().toUtc());
      if (!mounted) return;
      setState(() => _timeRemaining = remaining.isNegative ? Duration.zero : remaining);
      if (remaining.isNegative) {
        _countdownTimer?.cancel();
        _advertiser?.stop();
      }
    }

    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> _startScanningOther() async {
    setState(() => _scanningOther = true);
    final scanner = LanHostScanner();
    _scannerOther = scanner;
    _scanSubOther = scanner.hosts.listen((hosts) => setState(() => _discoveredOther = hosts));
    await scanner.start();
  }

  Future<void> _stopScanningOther() async {
    await _scanSubOther?.cancel();
    await _scannerOther?.stop();
    _scannerOther = null;
    if (mounted) setState(() { _scanningOther = false; _discoveredOther = const []; });
  }

  Future<void> _joinOther(PaystackCredentials credentials, {required String baseUrl, required String code}) async {
    // join_shop authenticates the caller via its existing api_key, which
    // only the server this device is already registered against
    // recognizes - a code from a shop hosted on a different server would
    // just fail there with a confusing "invalid code" rather than actually
    // reaching it, so catch that case with a clearer message instead.
    if (baseUrl != credentials.baseUrl) {
      _showMessage('That shop is on a different server than this device - switching servers isn\'t supported.');
      return;
    }
    setState(() => _submittingOther = true);
    try {
      await ref.read(platformOnboardingGatewayProvider).joinShop(
            baseUrl: credentials.baseUrl,
            apiKey: credentials.apiKey,
            inviteCode: code,
          );
      await ref.read(syncMetadataProvider).resetCursors();
      _showMessage('Joined - your data will sync with the rest of that shop shortly.');
      unawaited(_safeSyncNow());
    } catch (e) {
      _showMessage(e is PaystackException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _submittingOther = false);
    }
  }

  /// A background sync failing right after a fresh join/register must
  /// never crash the screen that just successfully completed - matches
  /// how [SyncService.runSyncCycle] already swallows offline/network
  /// failures everywhere else it's called unawaited.
  Future<void> _safeSyncNow() async {
    try {
      await ref.read(syncServiceProvider).runSyncCycle();
    } catch (_) {
      // Next scheduled sync cycle (app resume / periodic timer) will retry.
    }
  }

  @override
  Widget build(BuildContext context) {
    final credentialsAsync = ref.watch(currentPaymentCredentialsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Device Sync')),
      body: credentialsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load: $error')),
        data: (credentials) =>
            credentials.isConfigured ? _buildConnectedView(credentials) : _buildRegisterView(),
      ),
    );
  }

  Widget _buildRegisterView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Connect this device so it shares the same sales, inventory, and reports as the rest of your shop.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _deviceLabelController,
          decoration: const InputDecoration(labelText: 'Label for this device (e.g. your shop name or counter)'),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Set up a new shop'),
              selected: !_joinExisting,
              onSelected: (_) => setState(() => _joinExisting = false),
            ),
            ChoiceChip(
              label: const Text('Join an existing shop'),
              selected: _joinExisting,
              onSelected: (_) => setState(() => _joinExisting = true),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!_joinExisting) ...[
          TextField(
            controller: _newShopUrlController,
            decoration: const InputDecoration(labelText: 'Shop server address'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submitting ? null : _registerNewShop,
            child: _submitting ? _smallSpinner() : const Text('Set up this device'),
          ),
        ] else ...[
          Text(
            'Make sure this device is connected to the same Wi-Fi network as the shop\'s other device.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (!_scanning)
            OutlinedButton.icon(
              onPressed: _startScanning,
              icon: const Icon(Icons.wifi_find_outlined),
              label: const Text('Scan for nearby devices'),
            )
          else ...[
            Row(
              children: [
                const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text(
                  _discovered.isEmpty ? 'Scanning...' : '${_discovered.length} found',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
                TextButton(onPressed: _stopScanning, child: const Text('Stop')),
              ],
            ),
            const SizedBox(height: 8),
            for (final host in _discovered)
              Card(
                child: ListTile(
                  title: Text(host.deviceLabel.isEmpty ? 'Nearby shop' : host.deviceLabel),
                  subtitle: Text(host.baseUrl),
                  trailing: FilledButton(
                    onPressed: _submitting ? null : () => _joinDiscovered(host),
                    child: const Text('Join'),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          Text('Or enter the details manually', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _manualUrlController,
            decoration: const InputDecoration(labelText: 'Shop server address'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _manualCodeController,
            decoration: const InputDecoration(labelText: 'Invite code'),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submitting ? null : _joinManually,
            child: _submitting ? _smallSpinner() : const Text('Join'),
          ),
        ],
      ],
    );
  }

  Widget _buildConnectedView(PaystackCredentials credentials) {
    final invite = _generatedInvite;
    final remaining = _timeRemaining;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add another device', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Generate a code so another device on the same Wi-Fi network can find and join this shop automatically.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _generating ? null : () => _generateInvite(credentials),
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Generate code'),
                ),
                if (invite != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        SelectableText(
                          invite.code,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          remaining == null
                              ? 'Broadcasting on this network - the other device should find it automatically.'
                              : remaining == Duration.zero
                                  ? 'Expired - generate a new one.'
                                  : 'Broadcasting - expires in ${remaining.inMinutes}m ${remaining.inSeconds.remainder(60)}s',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Join a different shop instead', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Only do this if this device should stop syncing with its current shop and switch to another one.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (!_scanningOther)
                  OutlinedButton.icon(
                    onPressed: _startScanningOther,
                    icon: const Icon(Icons.wifi_find_outlined),
                    label: const Text('Scan for nearby shops'),
                  )
                else ...[
                  Row(
                    children: [
                      const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Text(_discoveredOther.isEmpty ? 'Scanning...' : '${_discoveredOther.length} found'),
                      const Spacer(),
                      TextButton(onPressed: _stopScanningOther, child: const Text('Stop')),
                    ],
                  ),
                  for (final host in _discoveredOther)
                    Card(
                      child: ListTile(
                        title: Text(host.deviceLabel.isEmpty ? 'Nearby shop' : host.deviceLabel),
                        subtitle: Text(host.baseUrl),
                        trailing: FilledButton(
                          onPressed: _submittingOther
                              ? null
                              : () => _joinOther(credentials, baseUrl: host.baseUrl, code: host.code),
                          child: const Text('Join'),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _manualUrlOtherController,
                  decoration: const InputDecoration(labelText: 'Shop server address'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _manualCodeOtherController,
                  decoration: const InputDecoration(labelText: 'Invite code'),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _submittingOther
                      ? null
                      : () {
                          final baseUrl = _manualUrlOtherController.text.trim();
                          final code = _manualCodeOtherController.text.trim();
                          if (baseUrl.isEmpty || code.isEmpty) {
                            _showMessage('Enter both the server address and the invite code.');
                            return;
                          }
                          _joinOther(credentials, baseUrl: baseUrl, code: code);
                        },
                  child: _submittingOther ? _smallSpinner() : const Text('Join'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _smallSpinner() =>
      const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2));
}
