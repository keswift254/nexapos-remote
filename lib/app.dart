import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, KeyEvent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'core/providers.dart';
import 'domain/services/session_service.dart';
import 'domain/services/sync_service.dart';
import 'domain/services/lan_sync_service.dart';
import 'domain/services/license_service.dart';
import 'domain/entities/user_role.dart';
import 'domain/repositories/user_repository.dart';
import 'data/repositories/user_repository_impl.dart';
import 'features/licensing/activation_screen.dart';
import 'features/auth/setup_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/users/users_screen.dart';
import 'features/categories/categories_screen.dart';
import 'features/products/products_screen.dart';
import 'features/checkout/new_sale_screen.dart';
import 'features/checkout/cart_notifier.dart';
import 'features/checkout/cart_screen.dart';
import 'features/checkout/receipt_screen.dart';
import 'features/checkout/pending_sales_screen.dart';
import 'domain/services/pending_sales_notifier.dart';
import 'features/settings/payment_settings_screen.dart'
    show currentPaymentCredentialsProvider, PaymentSettingsScreen;
import 'features/settings/business_settings_screen.dart';
import 'features/settings/device_management_screen.dart'
    show ConnectedDevicesEntryScreen;
import 'features/settings/device_sync_screen.dart';
import 'features/settings/license_screen.dart';
import 'features/settings/update_screen.dart';
import 'features/expenses/expenses_screen.dart';
import 'features/reports/reports_screen.dart';
import 'domain/services/update_service.dart';
import 'domain/services/automatic_backup_service.dart';
import 'domain/services/app_lock_settings.dart';
import 'features/settings/privacy_settings_screen.dart';
import 'features/settings/backup_screen.dart';
import 'domain/services/google_drive_backup_service.dart';

part 'app.g.dart';

@riverpod
Future<bool> hasAnyUsers(Ref ref) {
  final UserRepository repo = ref.watch(userRepositoryProvider);
  return repo.hasAnyUsers();
}

/// Bridges Riverpod's reactive session state into go_router's
/// Listenable-based refresh mechanism, so a login/logout re-runs
/// [_redirect] without needing a manual navigation call anywhere.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
    ref.listen(licenseChangeSignalProvider, (_, _) => notifyListeners());
  }
}

/// Mirrors PHP's Auth::requireLogin()/requireRole() per-route
/// whitelist: this is the single choke point for "who can see what",
/// the same check [SessionNotifier.can] exposes to use cases.
///
/// Never lets an exception escape - go_router awaits this on every
/// route change, starting with the very first one before anything has
/// painted yet. An unhandled throw here (confirmed possible on iOS
/// Safari specifically: the web database connection can fail to open -
/// see database_connection_web.dart's fallback chain - and every branch
/// below reads through it) left the whole app silently blank with no
/// error a user could ever see, not just this one navigation failing.
/// Staying on the current location is the least presumptuous fallback:
/// unlike guessing '/activate', it doesn't risk telling an already
/// licensed, already logged-in user their setup is missing just because
/// one read glitched.
Future<String?> _redirect(Ref ref, String location) async {
  try {
    return await _redirectOrThrow(ref, location);
  } catch (error, stack) {
    debugPrint('Redirect check failed, staying at $location: $error\n$stack');
    return null;
  }
}

Future<String?> _redirectOrThrow(Ref ref, String location) async {
  final hasLicense = await ref.read(hasCachedLicenseProvider.future);
  if (!hasLicense) {
    return location == '/activate' || location == '/join-shop'
        ? null
        : '/activate';
  }
  if (location == '/join-shop') return null;
  if (location == '/activate') {
    return '/';
  }

  // Registration is started in the background after paid activation so
  // first-time account setup is never held behind a network round trip.
  // Joined-only devices are different: their hydration marker keeps them
  // on the join screen until the invited shop users and settings arrive.
  final credentials = await ref.read(currentPaymentCredentialsProvider.future);
  final hasUsers = await ref.read(hasAnyUsersProvider.future);
  if (credentials.isConfigured &&
      await ref.read(syncServiceProvider).needsInitialPull) {
    return '/join-shop';
  }
  final user = ref.read(sessionProvider);
  final loggedIn = user != null;

  if (!hasUsers) {
    return location == '/setup' ? null : '/setup';
  }
  if (location == '/setup') {
    return loggedIn ? '/' : '/login';
  }
  if (!loggedIn) {
    return location == '/login' ? null : '/login';
  }
  if (await ref.read(syncServiceProvider).hasPendingShopChange) {
    final destination = user.role == UserRole.admin ? '/device-sync' : '/login';
    return location == destination ? null : destination;
  }
  if (location == '/login') {
    return '/';
  }
  if (location == '/users' && user.role != UserRole.admin) {
    return '/';
  }
  const inventoryRoles = {UserRole.admin, UserRole.manager};
  if ((location == '/categories' ||
          location == '/products' ||
          location == '/expenses') &&
      !inventoryRoles.contains(user.role)) {
    return '/';
  }
  if ((location == '/payment-settings' ||
          location == '/business-settings' ||
          location == '/device-sync' ||
          location == '/connected-devices' ||
          location == '/backup') &&
      user.role != UserRole.admin) {
    return '/';
  }
  return null;
}

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _RouterRefreshNotifier(ref),
    redirect: (context, state) => _redirect(ref, state.matchedLocation),
    routes: [
      GoRoute(
        path: '/activate',
        builder: (context, state) => const ActivationScreen(),
      ),
      GoRoute(
        path: '/join-shop',
        builder: (context, state) => const DeviceSyncScreen(joinOnly: true),
      ),
      GoRoute(path: '/setup', builder: (context, state) => const SetupScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
      GoRoute(path: '/users', builder: (context, state) => const UsersScreen()),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/products',
        builder: (context, state) => ProductsScreen(
          lowStockOnly: state.uri.queryParameters['lowStockOnly'] == 'true',
        ),
      ),
      GoRoute(
        path: '/new-sale',
        builder: (context, state) => const NewSaleScreen(),
      ),
      GoRoute(
        path: '/checkout/cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/receipt/:saleId',
        builder: (context, state) => ReceiptScreen(
          saleId: state.pathParameters['saleId']!,
          returnPath: state.uri.queryParameters['from'] == 'reports'
              ? '/reports'
              : '/',
        ),
      ),
      GoRoute(
        path: '/payment-settings',
        builder: (context, state) => const PaymentSettingsScreen(),
      ),
      GoRoute(
        path: '/business-settings',
        builder: (context, state) => const BusinessSettingsScreen(),
      ),
      GoRoute(
        path: '/device-sync',
        builder: (context, state) => const DeviceSyncScreen(),
      ),
      GoRoute(
        path: '/connected-devices',
        builder: (context, state) => const ConnectedDevicesEntryScreen(),
      ),
      GoRoute(
        path: '/license',
        builder: (context, state) => const LicenseScreen(),
      ),
      GoRoute(
        path: '/update',
        builder: (context, state) => const UpdateScreen(),
      ),
      GoRoute(
        path: '/privacy-settings',
        builder: (context, state) => const PrivacySettingsScreen(),
      ),
      GoRoute(
        path: '/backup',
        builder: (context, state) => const BackupScreen(),
      ),
      GoRoute(
        path: '/expenses',
        builder: (context, state) => const ExpensesScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/pending-sales',
        builder: (context, state) => const PendingSalesScreen(),
      ),
    ],
  );
}

const _syncInterval = Duration(seconds: 15);
const _maintenanceInterval = Duration(minutes: 2);
// A shared shop terminal left logged in indefinitely is a real handoff
// risk (one cashier's actions attributed to another, or anyone walking
// up gets a logged-in admin session) - checked on its own, more frequent
// cadence than _syncInterval since a 2-minute-granularity check could
// let this run up to 2 minutes over the real timeout. Deliberately does
// NOT touch CartNotifier (keepAlive, never cleared by logout - see its
// own class doc) - an in-progress sale survives this exactly like it
// survives a manual logout today, so the next person to log in (same
// cashier or not) picks up where the cart was left, not an empty one.
const _inactivityCheckInterval = Duration(seconds: 5);

class NexaPosApp extends ConsumerStatefulWidget {
  const NexaPosApp({super.key});

  @override
  ConsumerState<NexaPosApp> createState() => _NexaPosAppState();
}

/// Runs Phase 2 sync automatically - on app resume and on a periodic
/// timer while open - with no manual "sync now" affordance, matching
/// the same app-resume-triggers-an-immediate-check pattern already used
/// for Paystack payment polling (paystack_waiting_screen.dart). Lives
/// at the app root, not the dashboard, since sync must keep running
/// regardless of which screen happens to be open; SyncService itself
/// already no-ops silently when this device isn't registered/joined to
/// a shop yet, so it's always safe to call. Lightweight cloud/LAN change
/// exchange AND license/membership verification run every 15 seconds -
/// the latter moved here from the slower maintenance cadence after a
/// real report that a revoked device took up to two minutes to actually
/// lock out; update checks and backups stay on the separate two-minute
/// maintenance cadence, since those aren't security-sensitive the same
/// way and don't need to multiply heavier background work.
class _NexaPosAppState extends ConsumerState<NexaPosApp>
    with WidgetsBindingObserver {
  Timer? _syncTimer;
  Timer? _maintenanceTimer;
  Timer? _inactivityTimer;
  DateTime? _lastActivity;
  DateTime? _backgroundedAt;
  bool _syncing = false;
  bool _maintaining = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recordActivity();
    _runSync();
    _runMaintenance();
    ref.read(pendingPaystackSalesProvider.notifier).reconcile();
    ref.read(cartProvider.notifier).restore();
    _scheduleNextSync();
    _maintenanceTimer = Timer.periodic(
      _maintenanceInterval,
      (_) => _runMaintenance(),
    );
    _inactivityTimer = Timer.periodic(
      _inactivityCheckInterval,
      (_) => _checkInactivity(),
    );
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _syncTimer?.cancel();
    _maintenanceTimer?.cancel();
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final backgroundedAt = _backgroundedAt;
      final minutes = ref.read(appLockSettingsProvider);
      if (ref.read(sessionProvider) != null &&
          minutes > 0 &&
          backgroundedAt != null &&
          ref.read(clockProvider).now().difference(backgroundedAt) >=
              Duration(minutes: minutes)) {
        ref.read(sessionProvider.notifier).logout();
      }
      _backgroundedAt = null;
      _recordActivity();
      _runSync();
      _runMaintenance();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt = ref.read(clockProvider).now();
      if (ref.read(sessionProvider) != null &&
          ref.read(appLockSettingsProvider) == 0) {
        ref.read(sessionProvider.notifier).logout();
      }
    }
  }

  // A one-shot Timer that reschedules itself (rather than Timer.periodic)
  // so each wait picks the current interval fresh - needsInitialPull can
  // flip from true to false partway through, and the very next wait
  // should reflect that immediately, not on whatever cadence a periodic
  // timer happened to already be running on. While a device is still
  // waiting on its very first shop snapshot, this uses
  // hydratingSyncRetryInterval instead of _syncInterval - a fresh join has
  // real, one-time catching-up to do (see
  // SyncService.pullInitialSnapshot/pullRemoteChanges), and any single
  // attempt that stops early (a transient timeout, the server's own
  // per-request page cap) would otherwise sit idle for up to two full
  // minutes before the next try, even though there's known, immediate work
  // left. Confirmed via real production logs during the browser-POS
  // verification: catch-up happens in ~14s bursts of several thousand
  // records, then nothing until the next periodic tick - this just makes
  // "the next tick" arrive in seconds instead of minutes while that
  // initial backlog is still being worked through.
  void _scheduleNextSync() {
    _syncTimer?.cancel();
    ref.read(syncServiceProvider).needsInitialPull.then((needsPull) {
      if (!mounted) return;
      _syncTimer = Timer(
        needsPull ? hydratingSyncRetryInterval : _syncInterval,
        () {
          _runSync().whenComplete(_scheduleNextSync);
        },
      );
    });
  }

  Future<void> _runSync() async {
    if (_syncing) return;
    _syncing = true;
    try {
      // Runs every sync tick, not just the slower maintenance cadence -
      // real report: revoking a device from Connected Devices (or a
      // license simply expiring) took up to two minutes to actually
      // lock that device back to the activation screen, since this used
      // to only run on the maintenance timer. hasAppAccess() below reads
      // whatever this just refreshed, so a revoke is now noticed within
      // about the same ~15s window sales already sync in.
      await ref.read(licenseServiceProvider).backgroundVerify();
      if (await ref.read(licenseServiceProvider).hasAppAccess()) {
        await Future.wait([
          ref.read(syncServiceProvider).runSyncCycle(),
          ref.read(lanSyncServiceProvider).syncNow(),
        ]);
      } else if (await ref.read(licenseServiceProvider).isJoinedMember) {
        // A joined device locked because its shop's license ran out must still
        // be reachable on the shop's network: that is how the shop's main
        // device hands it the renewal, with no internet involved. (Cloud sync
        // stays off - there is nothing to sync while the device is locked.)
        await ref.read(lanSyncServiceProvider).syncNow();
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _runMaintenance() async {
    if (_maintaining) return;
    _maintaining = true;
    try {
      await ref.read(updateAvailabilityProvider.notifier).check();
      if (ref.read(sessionProvider) != null) {
        final newBackup = await ref
            .read(automaticBackupServiceProvider)
            .runIfDue();
        if (newBackup != null) {
          // Best-effort mirror: a flaky Drive connection must not break the
          // sync cycle that runs this. The local backup above already
          // succeeded regardless of what happens here.
          try {
            await ref
                .read(googleDriveBackupServiceProvider)
                .uploadLatestBackupIfConnected();
          } catch (_) {}
        }
      }
    } finally {
      _maintaining = false;
    }
  }

  // Observes without consuming - returning false lets every key event
  // continue on to whatever field/shortcut normally handles it, exactly
  // as if this listener weren't here at all.
  bool _onKeyEvent(KeyEvent event) {
    _recordActivity();
    return false;
  }

  void _recordActivity([PointerEvent? _]) =>
      _lastActivity = ref.read(clockProvider).now();

  void _checkInactivity() {
    if (ref.read(sessionProvider) == null) return;
    final lastActivity = _lastActivity;
    if (lastActivity == null) return;
    final minutes = ref.read(appLockSettingsProvider);
    if (minutes == 0) return;
    if (ref.read(clockProvider).now().difference(lastActivity) >=
        Duration(minutes: minutes)) {
      ref.read(sessionProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return Listener(
      onPointerDown: _recordActivity,
      onPointerSignal: _recordActivity,
      behavior: HitTestBehavior.translucent,
      child: MaterialApp.router(
        title: 'NexaPOS',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        routerConfig: router,
      ),
    );
  }
}
