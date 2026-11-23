import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../core/secure_storage_provider.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers.dart';
import '../../data/support/support_gateway.dart';
import '../../core/adaptive_pair.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/services/home_screen_install_service.dart';
import '../../domain/services/pending_sales_notifier.dart';
import '../../domain/services/product_service.dart';
import '../../domain/services/reports_service.dart';
import '../../domain/services/paystack_credentials_service.dart';
import '../../domain/services/session_service.dart';
import '../../domain/services/update_service.dart';
import '../checkout/cart_notifier.dart';
import '../settings/biometric_setup_banner.dart';
import 'sync_health_banner.dart';
import '../settings/clock_health_banner.dart';
import 'ios_add_to_home_screen_dialog.dart';
import 'product_search_dialog.dart';

part 'dashboard_screen.g.dart';

class DashboardData {
  /// The local calendar day these figures were worked out for. When the day
  /// changes (midnight, or the date being changed) the dashboard recomputes -
  /// see _DashboardScreenState._refreshIfNewDay. Null only where a figure set is
  /// built by hand (tests).
  final DateTime? day;
  final DailyStats today;
  final PercentChange salesChange;
  final PercentChange netProfitChange;
  final List<DailyPoint> last7Days;
  final int lowStockCount;
  final Money stockValue;

  const DashboardData({
    this.day,
    required this.today,
    required this.salesChange,
    required this.netProfitChange,
    required this.last7Days,
    required this.lowStockCount,
    required this.stockValue,
  });
}

/// Deliberately narrower than the PHP dashboard's dashboardChartData:
/// today-vs-yesterday stats plus a 7-day trend, not its full daily/
/// weekly/monthly/yearly bucketed chart system (see ReportsService's
/// doc comment - that's a separate, heavier feature to add later if
/// wanted). Low-stock count and stock value mirror the PHP dashboard's
/// own SQL exactly (COUNT stock_qty<=reorder_level and
/// SUM(stock_qty*cost_price) across ALL products, no status filter) -
/// PHP computes a "change" for these two by comparing that same
/// point-in-time value to itself, which is always flat, so that part
/// is dropped rather than ported.
/// Fires on every write to any local table (inserts/updates/deletes, and
/// the raw-SQL stock_qty adjustment too - it declares `updates: {products}`)
/// regardless of which repository/service performed it. dashboardData
/// watches this so a sale, expense, or stock change anywhere in the app -
/// now or in any future code path - refreshes the dashboard on its own,
/// without every write site needing to remember to invalidate it.
/// keepAlive here (this used to be plain autodispose): a defensive
/// choice, not a distinctly-proven fix - a real report was "dashboard
/// doesn't update after a sale until I hit refresh," and this closes
/// the specific gap where autodispose would tear this subscription down
/// entirely while nothing was watching the dashboard (mid-sale, on the
/// cart/checkout/receipt screens), silently losing a write that
/// happened during that window. Belt-and-suspenders alongside this:
/// the actual sale-completion sites (cart_screen.dart,
/// paystack_waiting_screen.dart) now also call
/// `ref.invalidate(dashboardDataProvider)` explicitly right before
/// navigating back - THAT part is the unconditionally-correct fix,
/// verified for real; this keepAlive is the more theoretical half.
@Riverpod(keepAlive: true)
Stream<int> dashboardChangeTicker(Ref ref) {
  // Riverpod compares successive values. A void stream emits null every time,
  // suppressing all notifications after the first database change.
  var revision = 0;
  final db = ref.watch(appDatabaseProvider);
  // Only the shop's own data changes the figures. Sync bookkeeping (device_meta: the change counter and the upload
  // cursor) is written over and over while an upload is refused and retried, and every write used to recompute the
  // whole dashboard - on a busy shop's old PC, all the time, so the till could hardly be used.
  final updates = db.tableUpdates(TableUpdateQuery.onAllTables([
    db.sales,
    db.saleItems,
    db.paymentRecords,
    db.products,
    db.stockMovements,
    db.expenses,
    db.categories,
    db.users,
    db.businessSettings,
  ]));
  // And a burst of them (a sync applying hundreds of rows) is one refresh, at most one every [dashboardRefreshGap]. A
  // sale made here refreshes at once anyway: the cart invalidates the figures before it goes back to the dashboard.
  final controller = StreamController<int>();
  Timer? waiting;
  final subscription = updates.listen((_) {
    waiting ??= Timer(dashboardRefreshGap, () {
      waiting = null;
      if (!controller.isClosed) controller.add(++revision);
    });
  });
  ref.onDispose(() {
    waiting?.cancel();
    subscription.cancel();
    controller.close();
  });
  return controller.stream;
}

/// From this window width up the dashboard is laid out for a PC: everything on one screen (see DashboardScreen).
const wideDashboardWidth = 900.0;

/// The height of the dashboard's New Sale button: well above an ordinary button (40), so it stands out and is easy to hit.
const newSaleButtonHeight = 64.0;

/// The shortest time between two dashboard refreshes caused by changes to the shop's data in the background.
const dashboardRefreshGap = Duration(seconds: 2);

@Riverpod(keepAlive: true)
Future<DashboardData> dashboardData(Ref ref) async {
  ref.watch(dashboardChangeTickerProvider);
  final reports = ref.watch(reportsServiceProvider);
  final products = await ref.watch(productServiceProvider).getAll();

  final today = reports.today;
  final yesterday = today.subtract(const Duration(days: 1));
  final todayStats = await reports.statsForLocalDate(today);
  final yesterdayStats = await reports.statsForLocalDate(yesterday);
  final last7Days = await reports.lastNDays(7);

  final lowStockCount = products.where((p) => p.isLowStock).length;
  final stockValue = products.fold<Money>(
    const Money.zero(),
    (sum, p) => sum + p.costPrice * p.stockQty,
  );

  return DashboardData(
    day: today,
    today: todayStats,
    salesChange: PercentChange.compare(
      todayStats.salesTotal,
      yesterdayStats.salesTotal,
    ),
    netProfitChange: PercentChange.compare(
      todayStats.netProfit,
      yesterdayStats.netProfit,
    ),
    last7Days: last7Days,
    lowStockCount: lowStockCount,
    stockValue: stockValue,
  );
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  /// How often the day is compared with the one the figures were computed for.
  /// Cheap (one date comparison); short so the figures turn over within moments
  /// of midnight.
  static const _dayCheckEvery = Duration(seconds: 15);
  Timer? _dayTimer;
  Timer? _supportTimer;
  List<SupportTicket> _supportReplies = const [];
  bool _checkingSupport = false;
  Set<String> _dismissedSupportReplies = {};
  String? _supportBannerKey;
  List<SupportTicket> get _supportBannerReplies => _supportReplies
      .where((ticket) => !_dismissedSupportReplies.contains(ticket.replyToken)).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dayTimer = Timer.periodic(_dayCheckEvery, (_) => _refreshIfNewDay());
    _supportTimer = Timer.periodic(const Duration(minutes: 1),
        (_) => unawaited(_checkSupportReplies()));
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_checkSupportReplies()));
    // Coming back to the dashboard after midnight (it keeps its figures while
    // other screens are open) must show the new day at once.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshIfNewDay());
    // Landing on the dashboard - app cold start, or navigating back to
    // it - is the moment an admin actually looks for "did my
    // generator.html publish show up yet", so it gets its own check
    // instead of waiting on app.dart's periodic timer (up to 2 minutes)
    // or a background/resume cycle. Unawaited: this must never block
    // first paint, and UpdateAvailabilityNotifier.check() already
    // swallows its own errors, so a slow/cold platform host just means
    // the banner updates a little later, not a stuck spinner anywhere.
    unawaited(ref.read(updateAvailabilityProvider.notifier).check());
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    _supportTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A PC that slept through midnight fires no timers meanwhile.
    if (state == AppLifecycleState.resumed) {
      _refreshIfNewDay();
      unawaited(_checkSupportReplies());
    }
  }

  Future<void> _checkSupportReplies() async {
    if (!mounted || _checkingSupport || ref.read(sessionProvider) == null) return;
    _checkingSupport = true;
    try {
      final credentials = await ref.read(paystackCredentialsServiceProvider).load();
      if (!credentials.isConfigured) {
        if (mounted) setState(() { _supportReplies = []; _dismissedSupportReplies = {}; _supportBannerKey = null; });
        return;
      }
      final bannerKey = 'nexapos.support.banner.${sha256.convert(utf8.encode('${credentials.baseUrl}|${credentials.apiKey}'))}';
      if (_supportBannerKey != bannerKey) {
        final stored = await ref.read(secureStorageProvider).read(key: bannerKey);
        if (!mounted) return;
        Set<String> dismissed = {};
        try { dismissed = (jsonDecode(stored ?? '[]') as List).cast<String>().toSet(); } catch (_) {}
        setState(() { _supportBannerKey = bannerKey; _dismissedSupportReplies = dismissed; _supportReplies = []; });
      }
      final tickets = await ref.read(supportGatewayProvider).list(
        baseUrl: credentials.baseUrl,
        apiKey: credentials.apiKey,
      );
      if (!mounted) return;
      setState(() => _supportReplies =
          tickets.where((ticket) => ticket.status == 'pending').toList());
    } catch (_) {
      // Support is optional when offline; retain the last known replies.
    } finally {
      _checkingSupport = false;
    }
  }

  Future<void> _openSupport({SupportTicket? ticket}) async {
    final key = _supportBannerKey;
    final dismissed = {
      ..._dismissedSupportReplies,
      ..._supportReplies.map((ticket) => ticket.replyToken),
    };
    setState(() => _dismissedSupportReplies = dismissed);
    if (key != null) {
      // Best effort persistence; an unavailable store must never block Support.
      unawaited(ref
          .read(secureStorageProvider)
          .write(
            key: key,
            value: jsonEncode(dismissed.toList().reversed.take(200).toList()),
          )
          .catchError((Object _) {}));
    }
    final path = ticket == null ? '/support' : '/support?ticket=${ticket.id}';
    await context.push(path);
    if (mounted) await _checkSupportReplies();
  }

  /// The dashboard's figures are kept (and refreshed on every write), so nothing
  /// used to make them notice that the DAY changed: after midnight "today" still
  /// showed yesterday's sales until something happened to be written. Recompute
  /// as soon as the local date is no longer the one the figures are for.
  void _refreshIfNewDay() {
    if (!mounted) return;
    final shown = ref
        .read(dashboardDataProvider)
        .maybeWhen(data: (data) => data.day, orElse: () => null);
    if (shown == null) return;
    if (shown != ref.read(reportsServiceProvider).today) {
      ref.invalidate(dashboardDataProvider);
    }
  }

  /// Desktop has no pull-to-refresh gesture, so Windows gets an explicit
  /// button for the same thing Android's pull-to-refresh does below
  /// (`onRefresh: () async => ref.invalidate(dashboardDataProvider)`) -
  /// recompute the figures from the local database right now, on demand.
  /// Deliberately local-only for the figures themselves: pulling/pushing
  /// against the remote platform is the periodic timer/app-resume
  /// sync's job (see app.dart), not this button's - conflating the two
  /// made this feel broken whenever the platform API's free-tier host
  /// happened to be cold, for a button whose actual job never needed
  /// the network at all. The update check piggybacks here anyway
  /// (unawaited, same reasoning as initState above) since a manual
  /// refresh is also exactly when someone is checking "is this working
  /// now" - it just doesn't get to slow this button down while it runs.
  void _refreshLocalFigures() {
    ref.invalidate(dashboardDataProvider);
    unawaited(ref.read(updateAvailabilityProvider.notifier).check());
    unawaited(_checkSupportReplies());
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);
    final canManageInventory =
        user != null && {UserRole.admin, UserRole.manager}.contains(user.role);
    final seesShopFigures = user != null && canSeeShopFigures(user.role);
    final dataAsync = ref.watch(dashboardDataProvider);
    final pendingPaystackSales = ref.watch(pendingPaystackSalesProvider);
    final confirmedOnlineSales = ref.watch(confirmedOnlineSalesProvider);
    final availableUpdate = ref.watch(updateAvailabilityProvider);
    final cartState = ref.watch(cartProvider);
    final homeScreenInstall = ref.watch(homeScreenInstallProvider);
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    // A wide window (a PC or a laptop, or the web POS on one) shows everything on one screen: the buttons at the top,
    // the four figures in one row. The owner, 2026-11-22: "show all its contents at a glance - I don't have to scroll
    // down to access New Sale or Inventory". A phone or a narrow window has the figures two by two.
    final wide = MediaQuery.sizeOf(context).width >= wideDashboardWidth;
    // New Sale is the till's main job: a big raised button at the top of every dashboard, standing apart from the rest.
    // The owner, 2026-11-23: "I want the new sale button to be outstanding from the others and easily reachable".
    final newSaleButton = Tooltip(
      message: 'New sale (F2)',
      child: FilledButton.icon(
        key: const Key('dashboard-new-sale'),
        onPressed: () => context.push('/new-sale'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(260, newSaleButtonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
          // the theme's own large title (so the shop's font), made bold
          textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.point_of_sale, size: 28),
        label: const Text('New Sale'),
      ),
    );
    final managementButtons = <Widget>[
      FilledButton.tonalIcon(
        onPressed: () => context.push('/products'),
        icon: const Icon(Icons.inventory_2),
        label: const Text('Inventory'),
      ),
      FilledButton.tonalIcon(
        onPressed: () => context.push('/categories'),
        icon: const Icon(Icons.category),
        label: const Text('Categories'),
      ),
      FilledButton.tonalIcon(
        onPressed: () => context.push('/expenses'),
        icon: const Icon(Icons.receipt_long),
        label: const Text('Expenses'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.home),
              tooltip: 'Home (Alt+Home)',
              onPressed: () => context.go('/'),
            ),
            if (isWindows)
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _refreshLocalFigures,
              ),
            if (availableUpdate != null && user != null)
              IconButton(
                icon: Badge(
                  smallSize: 8,
                  child: Icon(
                    Icons.notifications_active,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                tooltip: 'Update available: version ${availableUpdate.version}',
                onPressed: () => context.push('/update'),
              ),
          ],
        ),
        actions: [
          // Reports are for the owner and managers only; a cashier has no way in (see canSeeShopFigures).
          if (seesShopFigures)
            IconButton(
              icon: const Icon(Icons.bar_chart_outlined),
              tooltip: 'Reports',
              onPressed: () => context.push('/reports'),
            ),
          if (user != null)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => context.push('/settings'),
            ),
          // Support sits exactly between Settings and Users & Roles so it is
          // reachable by every logged-in cashier/manager/admin without hiding
          // inside administrator-only settings.
          IconButton(
            icon: Badge(
              isLabelVisible: _supportReplies.isNotEmpty,
              label: Text('${_supportReplies.length}'),
              child: const Icon(Icons.support_agent_outlined),
            ),
            tooltip: _supportReplies.isEmpty
                ? 'Support'
                : '${_supportReplies.length} support ${_supportReplies.length == 1 ? 'reply' : 'replies'} waiting',
            onPressed: () => _openSupport(
              ticket: _supportBannerReplies.length == 1
                  ? _supportBannerReplies.first
                  : null,
            ),
          ),
          if (user?.role == UserRole.admin)
            IconButton(
              icon: const Icon(Icons.manage_accounts),
              tooltip: 'Users & Roles',
              onPressed: () => context.push('/users'),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _refreshLocalFigures(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.search),
                        tooltip: 'Search Inventory',
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => const ProductSearchDialog(),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            user.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // The actions come first on every screen. On a PC New Sale stands on its own at the left and the
                  // management buttons, smaller, sit at the right; on a phone New Sale is full width with them under it.
                  KeyedSubtree(
                    key: const Key('dashboard-actions-top'),
                    child: wide
                        ? Row(
                            children: [
                              newSaleButton,
                              const SizedBox(width: 24),
                              if (canManageInventory)
                                Expanded(
                                  child: Wrap(
                                    alignment: WrapAlignment.end,
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: managementButtons,
                                  ),
                                ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              newSaleButton,
                              if (canManageInventory) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: managementButtons,
                                ),
                              ],
                            ],
                          ),
                  ),
                  if (cartState.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      child: Tooltip(
                        message: 'Cart (F4)',
                        child: ListTile(
                        leading: const Icon(Icons.shopping_cart_outlined),
                        title: Text(
                          cartState.itemCount == 1
                              ? '1 item waiting in cart'
                              : '${cartState.itemCount} items waiting in cart',
                        ),
                        subtitle: const Text('Go to cart to complete sale.'),
                        onTap: () => context.push('/checkout/cart'),
                      )),
                    ),
                  ],
                  if (_supportBannerReplies.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.mark_chat_unread_outlined),
                        title: Text(_supportBannerReplies.length == 1
                            ? 'NexaPOS Support replied to your ticket'
                            : 'NexaPOS Support replied to ${_supportBannerReplies.length} tickets'),
                        subtitle: Text(_supportBannerReplies.length == 1
                            ? _supportBannerReplies.first.subject
                            : 'Open Support to read the replies.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openSupport(
                          ticket: _supportBannerReplies.length == 1
                              ? _supportBannerReplies.first
                              : null,
                        ),
                      ),
                    ),
                  ],
                  // Paid while the cashier was away (the page was reloaded on
                  // the way back from the payment page, or the app locked
                  // itself mid-payment): say so instead of leaving a sale that
                  // quietly turned paid.
                  for (final sale in confirmedOnlineSales) ...[
                    const SizedBox(height: 12),
                    Card(
                      key: Key('confirmed-online-payment-${sale.id}'),
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text('Payment received for ${sale.saleNumber}'),
                        subtitle: Text(
                          '${sale.gatewayPortion.format()} confirmed. '
                          'Tap to view the receipt.',
                        ),
                        trailing: IconButton(
                          tooltip: 'Dismiss',
                          icon: const Icon(Icons.close),
                          onPressed: () => ref
                              .read(confirmedOnlineSalesProvider.notifier)
                              .dismiss(sale.id),
                        ),
                        onTap: () {
                          ref
                              .read(confirmedOnlineSalesProvider.notifier)
                              .dismiss(sale.id);
                          context.push('/receipt/${sale.id}');
                        },
                      ),
                    ),
                  ],
                  if (pendingPaystackSales.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: ListTile(
                        leading: const Icon(Icons.warning_amber_outlined),
                        title: Text(
                          pendingPaystackSales.length == 1
                              ? '1 pending online payment needs attention'
                              : '${pendingPaystackSales.length} pending online payments need attention',
                        ),
                        subtitle: const Text(
                          'Tap to check status or cancel and restore stock.',
                        ),
                        onTap: () => context.push('/pending-sales'),
                      ),
                    ),
                  ],
                  if (availableUpdate != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.system_update_alt),
                        title: Text(
                          'Update available: version ${availableUpdate.version}',
                        ),
                        subtitle: const Text('Tap to download and install.'),
                        onTap: () => context.push('/update'),
                      ),
                    ),
                  ],
                  const ClockHealthBanner(),
                  const SyncHealthBanner(),
                  const BiometricSetupBanner(),
                  if (homeScreenInstall.shouldOffer) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.add_to_home_screen),
                        title: const Text('Add NexaPOS to your home screen'),
                        subtitle: const Text(
                          'Get one-tap access without opening a browser.',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Dismiss',
                          onPressed: () => ref
                              .read(homeScreenInstallProvider.notifier)
                              .dismiss(),
                        ),
                        onTap: () => _handleAddToHomeScreen(
                          context,
                          ref,
                          homeScreenInstall,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  dataAsync.when(
                    // While new figures are worked out the ones on screen stay (with the buttons among them):
                    // swapping them for a spinner on every refresh made the dashboard flicker and the buttons
                    // vanish under a person's finger.
                    skipLoadingOnReload: true,
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text('Failed to load dashboard: $error'),
                    ),
                    data: (data) => _DashboardStats(
                      // one per person signed in: amounts someone showed with the eye are hidden again for the next
                      key: ValueKey('dashboard-stats-${user.id}'),
                      data: data,
                      canManageInventory: canManageInventory,
                      showShopFigures: seesShopFigures,
                      wide: wide,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}

/// Android Chrome/Edge can show a real native install dialog via the
/// stashed beforeinstallprompt event; iOS Safari has never shipped that
/// event at all, so the only thing to offer there is the manual
/// Share > Add to Home Screen steps.
Future<void> _handleAddToHomeScreen(
  BuildContext context,
  WidgetRef ref,
  HomeScreenInstallState state,
) async {
  if (state.canPromptInstall) {
    await ref.read(homeScreenInstallProvider.notifier).promptInstall();
    return;
  }
  if (!state.isIosSafari) return;
  await showDialog<void>(
    context: context,
    builder: (context) => const IosAddToHomeScreenDialog(),
  );
}

class _DashboardStats extends StatefulWidget {
  final DashboardData data;
  final bool canManageInventory;

  /// Sales, profit, stock value and the Last 7 Days chart (see [canSeeShopFigures]). Without them only Low Stock is shown.
  final bool showShopFigures;

  /// A wide window: the four figures in one row (see [wideDashboardWidth]).
  final bool wide;

  const _DashboardStats({
    super.key,
    required this.data,
    required this.canManageInventory,
    required this.showShopFigures,
    this.wide = false,
  });

  @override
  State<_DashboardStats> createState() => _DashboardStatsState();
}

class _DashboardStatsState extends State<_DashboardStats> {
  static const _visibilityDuration = Duration(seconds: 60);
  bool _financialsVisible = false;
  Timer? _hideTimer;

  @override
  void didUpdateWidget(covariant _DashboardStats oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) _hideFinancials();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _toggleFinancials() {
    if (_financialsVisible) {
      _hideFinancials();
      return;
    }
    _hideTimer?.cancel();
    setState(() => _financialsVisible = true);
    _hideTimer = Timer(_visibilityDuration, _hideFinancials);
  }

  void _hideFinancials() {
    _hideTimer?.cancel();
    if (mounted && _financialsVisible) {
      setState(() => _financialsVisible = false);
    }
  }

  Widget _visibilityButton() => IconButton(
    tooltip: _financialsVisible
        ? 'Hide financial values'
        : 'Show financial values',
    onPressed: _toggleFinancials,
    icon: Icon(
      _financialsVisible
          ? Icons.visibility_off_outlined
          : Icons.visibility_outlined,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final today = data.today;
    const hiddenValue = '******';
    final lowStockCard = _StatCard(
      label: 'Low Stock',
      value: '${data.lowStockCount}',
      subtitle: data.lowStockCount == 1
          ? 'product at/below reorder level'
          : 'products at/below reorder level',
      onTap: widget.canManageInventory
          ? () => context.push('/products?lowStockOnly=true')
          : null,
    );
    if (!widget.showShopFigures) {
      // A cashier: no sales, profit, stock value or chart - not even as stars - only how many products are running low.
      return Align(
        key: const Key('dashboard-cashier-figures'),
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: lowStockCard,
        ),
      );
    }
    final todayRow = Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Sales Today',
                  value: _financialsVisible
                      ? today.salesTotal.format()
                      : hiddenValue,
                  subtitle:
                      '${today.salesCount == 1 ? '1 transaction' : '${today.salesCount} transactions'}'
                      '${_financialsVisible && today.refundsTotal.cents > 0 ? ' · refunds ${today.refundsTotal.format()}' : ''}',
                  change: _financialsVisible ? data.salesChange : null,
                  trailing: _visibilityButton(),
                  valueKey: const Key('sales-today-value'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Net Profit Today',
                  value: _financialsVisible
                      ? today.netProfit.format()
                      : hiddenValue,
                  subtitle: _financialsVisible
                      ? 'Gross ${today.grossProfit.format()}'
                      : 'Gross $hiddenValue',
                  change: _financialsVisible ? data.netProfitChange : null,
                  trailing: _visibilityButton(),
                  valueKey: const Key('net-profit-today-value'),
                ),
              ),
            ],
    );
    final stockRow = Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: lowStockCard),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Stock Value',
                  value: _financialsVisible
                      ? data.stockValue.format()
                      : hiddenValue,
                  trailing: _visibilityButton(),
                  valueKey: const Key('stock-value'),
                  subtitle: 'at cost price',
                ),
              ),
            ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.wide)
          // A wide window: the four figures in one row, so the whole dashboard fits on one screen.
          IntrinsicHeight(
            key: const Key('dashboard-figures-one-row'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [...todayRow.children, const SizedBox(width: 12), ...stockRow.children],
            ),
          )
        else ...[
          AdaptivePair(child: todayRow),
          const SizedBox(height: 12),
          AdaptivePair(child: stockRow),
        ],
        const SizedBox(height: 12),
        SalesTrendCard(points: data.last7Days, financialsVisible: _financialsVisible),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final PercentChange? change;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Key? valueKey;

  const _StatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    this.change,
    this.onTap,
    this.trailing,
    this.valueKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                key: valueKey,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (change != null) ...[
                    const SizedBox(width: 6),
                    _PercentBadge(change: change!),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PercentBadge extends StatelessWidget {
  final PercentChange change;

  const _PercentBadge({required this.change});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    switch (change.direction) {
      case 'up':
        color = Colors.green.shade700;
        icon = Icons.arrow_upward;
      case 'down':
        color = Colors.red.shade700;
        icon = Icons.arrow_downward;
      default:
        color = Colors.grey.shade600;
        icon = Icons.remove;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        Text(
          '${change.percent.abs()}%',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// "Last 7 Days": three bars a day (Sales, Expenses, Net Profit). Tap a day - anywhere in its column - and that day's exact
/// figures are written under the chart; the other days fade so the tapped one stands out (the same as the Lite till).
@visibleForTesting
class SalesTrendCard extends StatefulWidget {
  final List<DailyPoint> points;

  /// False while the dashboard hides its money figures: the tapped day's amounts are then stars, as on the stat cards.
  final bool financialsVisible;

  const SalesTrendCard({required this.points, this.financialsVisible = true});

  @override
  State<SalesTrendCard> createState() => SalesTrendCardState();
}

@visibleForTesting
class SalesTrendCardState extends State<SalesTrendCard> {
  int? _selected;

  @override
  void didUpdateWidget(SalesTrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New figures (a new day, a refresh): the old selection no longer means the same day.
    if (!identical(oldWidget.points, widget.points)) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final selected = _selected != null && _selected! < points.length ? _selected : null;
    final theme = Theme.of(context);
    final salesColor = theme.colorScheme.primary;
    const expensesColor = Colors.red;
    const profitColor = Colors.green;

    final maxVal = points.fold<double>(
      0,
      (m, p) => [
        m,
        p.salesTotal.toMajorDouble,
        p.expensesTotal.toMajorDouble,
        p.netProfit.toMajorDouble,
      ].reduce(math.max),
    );
    final minVal = points.fold<double>(
      0,
      (m, p) => math.min(m, p.netProfit.toMajorDouble),
    );
    final maxY = maxVal <= 0 ? 100.0 : maxVal * 1.2;
    final minY = minVal >= 0 ? 0.0 : minVal * 1.2;
    final gridInterval = (maxY - minY) / 4;
    final compactNumber = NumberFormat.compact();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last 7 Days', style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              'Tap a day for the exact figures',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              children: [
                _LegendDot(color: salesColor, label: 'Sales'),
                const _LegendDot(color: expensesColor, label: 'Expenses'),
                const _LegendDot(color: profitColor, label: 'Net Profit'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  minY: minY,
                  barTouchData: BarTouchData(
                    // The day's figures are written under the chart (below), not in a pop-up over the bars.
                    handleBuiltInTouches: false,
                    // A day is picked by touching anywhere in its column: the invisible full-height bar behind each rod counts too.
                    allowTouchBarBackDraw: true,
                    touchExtraThreshold: const EdgeInsets.symmetric(horizontal: 12, vertical: 2000),
                    touchCallback: (event, response) {
                      if (event is! FlTapUpEvent) return;
                      final index = response?.spot?.touchedBarGroupIndex;
                      if (index != null && index >= 0 && index < points.length) {
                        setState(() => _selected = index);
                      }
                    },
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: gridInterval == 0 ? null : gridInterval,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: value == 0
                          ? theme.colorScheme.outline
                          : theme.colorScheme.outlineVariant,
                      strokeWidth: value == 0 ? 1.5 : 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: gridInterval == 0 ? null : gridInterval,
                        getTitlesWidget: (value, meta) => Text(
                          compactNumber.format(value),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              DateFormat('E').format(points[index].date),
                              style: theme.textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < points.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 3,
                        barRods: [
                          for (final rod in [
                            (points[i].salesTotal.toMajorDouble, salesColor, 2.0, 0.0),
                            (points[i].expensesTotal.toMajorDouble, expensesColor, 2.0, 0.0),
                            (
                              points[i].netProfit.toMajorDouble,
                              profitColor,
                              points[i].netProfit.cents >= 0 ? 2.0 : 0.0,
                              points[i].netProfit.cents < 0 ? 2.0 : 0.0,
                            ),
                          ])
                            BarChartRodData(
                              toY: rod.$1,
                              color: selected == null || selected == i
                                  ? rod.$2
                                  : rod.$2.withValues(alpha: 0.3),
                              width: 7,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(rod.$3),
                                bottom: Radius.circular(rod.$4),
                              ),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                fromY: minY,
                                toY: maxY,
                                color: Colors.transparent,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              selected == null
                  ? 'Tap a day for the exact figures'
                  : _dayFigures(points[selected], widget.financialsVisible),
              key: const Key('trend-detail'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// "Sun, 15 Nov  \u00b7  Sales KES 770.00  \u00b7  Expenses KES 150.00  \u00b7  Net Profit KES 30.00"
  static String _dayFigures(DailyPoint point, bool visible) {
    String money(Money value) => visible ? value.format() : '******';
    return '${DateFormat('EEE, d MMM').format(point.date)}  \u00b7  Sales ${money(point.salesTotal)}  \u00b7  Expenses ${money(point.expensesTotal)}  \u00b7  Net Profit ${money(point.netProfit)}';
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
