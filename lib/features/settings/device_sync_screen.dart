import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../data/payments/paystack_gateway.dart' show PaystackException;
import '../../data/payments/platform_http_client.dart' show nexaposPlatformBaseUrl;
import '../../data/payments/platform_onboarding_gateway.dart';
import '../../data/sync/lan_discovery.dart';
import '../../domain/entities/paystack_credentials.dart';
import '../../domain/services/paystack_credentials_service.dart';
import '../../domain/services/sync_service.dart';
import '../../app.dart' show hasAnyUsersProvider;
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
  final _manualCodeOtherController = TextEditingController();
  bool _submittingOther = false;
  bool _leaving = false;

  RegistrationLookup? _existingRegistration;

  @override
  void initState() {
    super.initState();
    _checkExistingRegistration();
  }

  /// Fired unconditionally on open, whether or not this device already
  /// looks configured - if it's already connected the result is simply
  /// unused (_buildConnectedView shows instead), and if it's not, this
  /// is what lets a device that lost its local api_key (but kept its own
  /// registrationSecret, which survives independently - see
  /// device_meta_table.dart) see what it was already registered as
  /// instead of only finding out via a 409 after typing something and
  /// submitting. Silently falls back to a blank form on any failure -
  /// offline, or genuinely nothing registered yet look identical here,
  /// and both mean "just show the normal form".
  Future<void> _checkExistingRegistration() async {
    try {
      final deviceId = await ref.read(syncMetadataProvider).deviceId();
      final registrationSecret = await ref.read(syncMetadataProvider).registrationSecret();
      final lookup = await ref.read(platformOnboardingGatewayProvider).lookupRegistration(
            baseUrl: nexaposPlatformBaseUrl,
            deviceId: deviceId,
            registrationSecret: registrationSecret,
          );
      if (!mounted || lookup == null) return;
      setState(() {
        _existingRegistration = lookup;
        if (_deviceLabelController.text.isEmpty) {
          _deviceLabelController.text = lookup.deviceLabel;
        }
      });
    } catch (_) {
      // Offline right now - _register()'s own recovery path still works
      // once connectivity is back, this just means no pre-fill/banner.
    }
  }

  @override
  void dispose() {
    _deviceLabelController.dispose();
    _manualCodeController.dispose();
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
    await _register(baseUrl: nexaposPlatformBaseUrl, inviteCode: null);
  }

  // host.baseUrl is deliberately ignored - every device talks to the
  // same fixed nexaposPlatformBaseUrl now (see that constant's own
  // comment), LAN discovery only still matters for finding the invite
  // CODE nearby without having to type it.
  Future<void> _joinDiscovered(DiscoveredHost host) async {
    final label = _deviceLabelController.text.trim();
    if (label.isEmpty) return _showMessage('Enter a label for this device first.');
    await _register(baseUrl: nexaposPlatformBaseUrl, inviteCode: host.code);
  }

  Future<void> _joinManually() async {
    final label = _deviceLabelController.text.trim();
    if (label.isEmpty) return _showMessage('Enter a label for this device.');
    final code = _manualCodeController.text.trim();
    if (code.isEmpty) return _showMessage('Enter the invite code.');
    await _register(baseUrl: nexaposPlatformBaseUrl, inviteCode: code);
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
      // _register only ever runs from _buildRegisterView, i.e. while
      // this device wasn't configured yet - that's also exactly the
      // condition app.dart's mandatory /device-sync gate checks, so a
      // fresh registration needs an explicit nudge forward (to /setup,
      // in practice) rather than sitting on the connected view that now
      // renders here until something else happens to navigate.
      if (mounted) context.go('/');
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

  Future<void> _joinOther(PaystackCredentials credentials, {required String code}) async {
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

  /// leave_shop server-side hands this device a brand new, empty shop of
  /// its own (same api_key - no need to re-register), so the local half
  /// just has to match: wipe every business record and reset the sync
  /// cursors that belonged to the shop just left, then send the user
  /// through /setup again for the fresh shop (hasAnyUsersProvider is
  /// correctly false now, since users was part of the wipe) rather than
  /// leaving them sitting on this screen with a stale app state.
  Future<void> _leaveShop(PaystackCredentials credentials) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this shop?'),
        content: const Text(
          'This device will disconnect from its current shop. ALL local data on this device - products, sales, '
          'inventory, everything - will be permanently deleted so it can start fresh as a new, empty shop. '
          'This cannot be undone. Devices that stay in the current shop keep their data.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave and erase this device'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _leaving = true);
    try {
      await ref.read(platformOnboardingGatewayProvider).leaveShop(
            baseUrl: credentials.baseUrl,
            apiKey: credentials.apiKey,
          );
      await ref.read(appDatabaseProvider).resetForFreshStart();
      await ref.read(syncMetadataProvider).resetCursors();
      ref.invalidate(hasAnyUsersProvider);
      if (!mounted) return;
      _showMessage('Left that shop - this device is starting fresh.');
      context.go('/');
    } catch (e) {
      _showMessage(e is PaystackException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _leaving = false);
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

  // business_name is only set once a shop's owner fills in Payment
  // Settings (save_settlement_details) - a shop that hasn't gotten
  // there yet, or was never meant to (no interest in Paystack), leaves
  // this null/empty, so the recovery banner needs a sensible fallback
  // rather than showing an empty pair of quotes.
  String get _existingShopName {
    final name = _existingRegistration?.businessName ?? '';
    return name.isEmpty ? 'that shop' : '"$name"';
  }

  Widget _buildRegisterView() {
    final existing = _existingRegistration;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Connect this device so it shares the same sales, inventory, and reports as the rest of your shop.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        if (existing != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: existing.isDisabled
                  ? Theme.of(context).colorScheme.errorContainer
                  : Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              existing.isDisabled
                  ? 'This device was disabled by $_existingShopName and can\'t reconnect with its current identity. '
                      'Ask that shop\'s owner if this is a mistake, or reinstall the app to set this device up fresh.'
                  : 'This device was already registered as "${existing.deviceLabel}" for $_existingShopName. '
                      'Tap below to reconnect using that name, or change it first to update it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _deviceLabelController,
          enabled: existing?.isDisabled != true,
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
          FilledButton(
            onPressed: (_submitting || existing?.isDisabled == true) ? null : _registerNewShop,
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
                  trailing: FilledButton(
                    onPressed: (_submitting || existing?.isDisabled == true) ? null : () => _joinDiscovered(host),
                    child: const Text('Join'),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          Text('Or enter the invite code manually', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _manualCodeController,
            decoration: const InputDecoration(labelText: 'Invite code'),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: (_submitting || existing?.isDisabled == true) ? null : _joinManually,
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
                        trailing: FilledButton(
                          onPressed: _submittingOther ? null : () => _joinOther(credentials, code: host.code),
                          child: const Text('Join'),
                        ),
                      ),
                    ),
                ],
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
                          final code = _manualCodeOtherController.text.trim();
                          if (code.isEmpty) {
                            _showMessage('Enter the invite code.');
                            return;
                          }
                          _joinOther(credentials, code: code);
                        },
                  child: _submittingOther ? _smallSpinner() : const Text('Join'),
                ),
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
                Text('Leave this shop', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Disconnects this device and permanently erases every product, sale, and other record stored '
                  'on it, so it starts completely fresh - as its own new, empty shop. Data already synced to '
                  'other devices in the current shop is not affected.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _leaving ? null : () => _leaveShop(credentials),
                  icon: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                  label: _leaving
                      ? _smallSpinner()
                      : Text('Leave this shop', style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
