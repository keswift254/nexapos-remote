import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, KeyEvent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'core/providers.dart';
import 'domain/services/session_service.dart';
import 'domain/services/sync_service.dart';
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
import 'features/checkout/cart_screen.dart';
import 'features/checkout/receipt_screen.dart';
import 'features/checkout/pending_sales_screen.dart';
import 'domain/services/pending_sales_notifier.dart';
import 'features/settings/payment_settings_screen.dart';
import 'features/settings/business_settings_screen.dart';
import 'features/settings/device_sync_screen.dart';
import 'features/settings/update_screen.dart';
import 'features/expenses/expenses_screen.dart';
import 'features/reports/reports_screen.dart';
import 'domain/services/update_service.dart';

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
Future<String?> _redirect(Ref ref, String location) async {
  final hasLicense = await ref.read(hasCachedLicenseProvider.future);
  if (!hasLicense) {
    return location == '/activate' ? null : '/activate';
  }
  if (location == '/activate') {
    return '/';
  }

  final hasUsers = await ref.read(hasAnyUsersProvider.future);
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
  if (location == '/login') {
    return '/';
  }
  if (location == '/users' && user.role != UserRole.admin) {
    return '/';
  }
  const inventoryRoles = {UserRole.admin, UserRole.manager};
  if ((location == '/categories' || location == '/products' || location == '/expenses') &&
      !inventoryRoles.contains(user.role)) {
    return '/';
  }
  if ((location == '/payment-settings' ||
          location == '/business-settings' ||
          location == '/device-sync' ||
          location == '/update') &&
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
      GoRoute(path: '/activate', builder: (context, state) => const ActivationScreen()),
      GoRoute(path: '/setup', builder: (context, state) => const SetupScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
      GoRoute(path: '/users', builder: (context, state) => const UsersScreen()),
      GoRoute(path: '/categories', builder: (context, state) => const CategoriesScreen()),
      GoRoute(
        path: '/products',
        builder: (context, state) =>
            ProductsScreen(lowStockOnly: state.uri.queryParameters['lowStockOnly'] == 'true'),
      ),
      GoRoute(path: '/new-sale', builder: (context, state) => const NewSaleScreen()),
      GoRoute(path: '/checkout/cart', builder: (context, state) => const CartScreen()),
      GoRoute(
        path: '/receipt/:saleId',
        builder: (context, state) => ReceiptScreen(saleId: state.pathParameters['saleId']!),
      ),
      GoRoute(path: '/payment-settings', builder: (context, state) => const PaymentSettingsScreen()),
      GoRoute(path: '/business-settings', builder: (context, state) => const BusinessSettingsScreen()),
      GoRoute(path: '/device-sync', builder: (context, state) => const DeviceSyncScreen()),
      GoRoute(path: '/update', builder: (context, state) => const UpdateScreen()),
      GoRoute(path: '/expenses', builder: (context, state) => const ExpensesScreen()),
      GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
      GoRoute(path: '/pending-sales', builder: (context, state) => const PendingSalesScreen()),
    ],
  );
}

const _syncInterval = Duration(minutes: 2);
// A shared shop terminal left logged in indefinitely is a real handoff
// risk (one cashier's actions attributed to another, or anyone walking
// up gets a logged-in admin session) - checked on its own, more frequent
// cadence than _syncInterval since a 2-minute-granularity check could
// let this run up to 2 minutes over the real timeout. Deliberately does
// NOT touch CartNotifier (keepAlive, never cleared by logout - see its
// own class doc) - an in-progress sale survives this exactly like it
// survives a manual logout today, so the next person to log in (same
// cashier or not) picks up where the cart was left, not an empty one.
const _inactivityTimeout = Duration(minutes: 28);
const _inactivityCheckInterval = Duration(seconds: 30);

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
/// a shop yet, so it's always safe to call. The same timer also carries
/// LicenseService.backgroundVerify() and UpdateAvailabilityNotifier.check()
/// - piggybacking on this existing cadence rather than each running its
/// own timer, per the licensing design's "silently re-check whenever
/// internet happens to be available".
class _NexaPosAppState extends ConsumerState<NexaPosApp> with WidgetsBindingObserver {
  Timer? _timer;
  Timer? _inactivityTimer;
  DateTime? _lastActivity;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recordActivity();
    _runSync();
    ref.read(pendingPaystackSalesProvider.notifier).reconcile();
    _timer = Timer.periodic(_syncInterval, (_) => _runSync());
    _inactivityTimer = Timer.periodic(_inactivityCheckInterval, (_) => _checkInactivity());
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _timer?.cancel();
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Bringing the window back into focus is itself a deliberate
    // interaction - without this, a window left backgrounded past the
    // timeout would log the user out the instant they click back in,
    // rather than giving them the same 28 minutes from when they
    // actually returned.
    if (state == AppLifecycleState.resumed) {
      _recordActivity();
      _runSync();
    }
  }

  Future<void> _runSync() async {
    if (_syncing) return;
    _syncing = true;
    try {
      await ref.read(syncServiceProvider).runSyncCycle();
      await ref.read(licenseServiceProvider).backgroundVerify();
      await ref.read(updateAvailabilityProvider.notifier).check();
    } finally {
      _syncing = false;
    }
  }

  // Observes without consuming - returning false lets every key event
  // continue on to whatever field/shortcut normally handles it, exactly
  // as if this listener weren't here at all.
  bool _onKeyEvent(KeyEvent event) {
    _recordActivity();
    return false;
  }

  void _recordActivity([PointerEvent? _]) => _lastActivity = ref.read(clockProvider).now();

  void _checkInactivity() {
    if (ref.read(sessionProvider) == null) return;
    final lastActivity = _lastActivity;
    if (lastActivity == null) return;
    if (ref.read(clockProvider).now().difference(lastActivity) >= _inactivityTimeout) {
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
