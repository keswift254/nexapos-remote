import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/services/pending_sales_notifier.dart';
import '../../domain/services/product_service.dart';
import '../../domain/services/reports_service.dart';
import '../../domain/services/session_service.dart';
import '../../domain/services/sync_service.dart';
import '../../domain/services/update_service.dart';
import 'product_search_dialog.dart';

part 'dashboard_screen.g.dart';

class DashboardData {
  final DailyStats today;
  final PercentChange salesChange;
  final PercentChange netProfitChange;
  final List<DailyPoint> last7Days;
  final int lowStockCount;
  final Money stockValue;

  const DashboardData({
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
Stream<void> dashboardChangeTicker(Ref ref) {
  return ref.watch(appDatabaseProvider).tableUpdates().map((_) {});
}

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
    today: todayStats,
    salesChange: PercentChange.compare(todayStats.salesTotal, yesterdayStats.salesTotal),
    netProfitChange: PercentChange.compare(todayStats.netProfit, yesterdayStats.netProfit),
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

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _manualSyncing = false;

  /// Desktop has no pull-to-refresh gesture, so Windows gets an explicit
  /// button for the same thing the periodic timer/app-resume already do
  /// automatically (see app.dart) - this doesn't change that auto sync
  /// logic at all, it just lets the cashier force an immediate round
  /// rather than waiting up to 2 minutes for the next tick. Android
  /// keeps its existing pull-to-refresh instead; no icon there.
  Future<void> _manualRefresh() async {
    if (_manualSyncing) return;
    setState(() => _manualSyncing = true);
    try {
      await ref.read(syncServiceProvider).runSyncCycle();
      await ref.read(pendingPaystackSalesProvider.notifier).reconcile();
    } finally {
      if (mounted) setState(() => _manualSyncing = false);
      ref.invalidate(dashboardDataProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);
    final canManageInventory =
        user != null && {UserRole.admin, UserRole.manager}.contains(user.role);
    final dataAsync = ref.watch(dashboardDataProvider);
    final pendingPaystackSales = ref.watch(pendingPaystackSalesProvider);
    final availableUpdate = ref.watch(updateAvailabilityProvider);
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.home),
              tooltip: 'Home',
              onPressed: () => context.go('/'),
            ),
            if (isWindows)
              IconButton(
                icon: _manualSyncing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                tooltip: 'Sync now',
                onPressed: _manualSyncing ? null : _manualRefresh,
              ),
            // Same admin-only gating as the banner below and the /update
            // route guard itself (app.dart) - a non-admin could never
            // reach the update screen this points at, so there's nothing
            // useful for this icon to do for them.
            if (availableUpdate != null && user?.role == UserRole.admin)
              IconButton(
                icon: Badge(
                  smallSize: 8,
                  child: Icon(Icons.notifications_active, color: Theme.of(context).colorScheme.error),
                ),
                tooltip: 'Update available: version ${availableUpdate.version}',
                onPressed: () => context.push('/update'),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: 'Reports',
            onPressed: () => context.push('/reports'),
          ),
          if (user?.role == UserRole.admin)
            PopupMenuButton<String>(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onSelected: (route) => context.push(route),
              itemBuilder: (context) => const [
                PopupMenuItem(value: '/business-settings', child: Text('Business Settings')),
                PopupMenuItem(value: '/payment-settings', child: Text('Payment Settings')),
                PopupMenuItem(value: '/device-sync', child: Text('Device Sync')),
                PopupMenuItem(value: '/update', child: Text('Check for Updates')),
              ],
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
              onRefresh: () async => ref.invalidate(dashboardDataProvider),
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
                          child: Text(user.name, style: Theme.of(context).textTheme.titleLarge),
                        ),
                      ),
                    ],
                  ),
                  if (pendingPaystackSales.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: ListTile(
                        leading: const Icon(Icons.warning_amber_outlined),
                        title: Text(
                          pendingPaystackSales.length == 1
                              ? '1 pending Paystack payment needs attention'
                              : '${pendingPaystackSales.length} pending Paystack payments need attention',
                        ),
                        subtitle: const Text('Tap to check status or cancel and restore stock.'),
                        onTap: () => context.push('/pending-sales'),
                      ),
                    ),
                  ],
                  if (availableUpdate != null && user.role == UserRole.admin) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.system_update_alt),
                        title: Text('Update available: version ${availableUpdate.version}'),
                        subtitle: const Text('Tap to download and install.'),
                        onTap: () => context.push('/update'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  dataAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text('Failed to load dashboard: $error'),
                    ),
                    data: (data) => _DashboardStats(data: data, canManageInventory: canManageInventory),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => context.push('/new-sale'),
                      icon: const Icon(Icons.point_of_sale),
                      label: const Text('New Sale'),
                    ),
                  ),
                  if (canManageInventory) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
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
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}

class _DashboardStats extends StatelessWidget {
  final DashboardData data;
  final bool canManageInventory;

  const _DashboardStats({required this.data, required this.canManageInventory});

  @override
  Widget build(BuildContext context) {
    final today = data.today;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Sales Today',
                  value: today.salesTotal.format(),
                  subtitle: today.salesCount == 1 ? '1 transaction' : '${today.salesCount} transactions',
                  change: data.salesChange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Net Profit Today',
                  value: today.netProfit.format(),
                  subtitle: 'Gross ${today.grossProfit.format()}',
                  change: data.netProfitChange,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Low Stock',
                  value: '${data.lowStockCount}',
                  subtitle: data.lowStockCount == 1 ? 'product at/below reorder level' : 'products at/below reorder level',
                  onTap: canManageInventory ? () => context.push('/products?lowStockOnly=true') : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Stock Value',
                  value: data.stockValue.format(),
                  subtitle: 'at cost price',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SalesTrendCard(points: data.last7Days),
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

  const _StatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    this.change,
    this.onTap,
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
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(subtitle, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
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
        Text('${change.percent.abs()}%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SalesTrendCard extends StatelessWidget {
  final List<DailyPoint> points;

  const _SalesTrendCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final salesColor = theme.colorScheme.primary;
    const expensesColor = Colors.red;
    const profitColor = Colors.green;

    final maxVal = points.fold<double>(
      0,
      (m, p) => [m, p.salesTotal.toMajorDouble, p.expensesTotal.toMajorDouble, p.netProfit.toMajorDouble]
          .reduce(math.max),
    );
    final minVal = points.fold<double>(0, (m, p) => math.min(m, p.netProfit.toMajorDouble));
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
            Text('Tap a bar for the exact total', style: theme.textTheme.bodySmall),
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
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final point = points[group.x];
                        const labels = ['Sales', 'Expenses', 'Net Profit'];
                        final values = [point.salesTotal, point.expensesTotal, point.netProfit];
                        return BarTooltipItem(
                          '${DateFormat('EEE, d MMM').format(point.date)}\n${labels[rodIndex]}: ${values[rodIndex].format()}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: gridInterval == 0 ? null : gridInterval,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: value == 0 ? theme.colorScheme.outline : theme.colorScheme.outlineVariant,
                      strokeWidth: value == 0 ? 1.5 : 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: gridInterval == 0 ? null : gridInterval,
                        getTitlesWidget: (value, meta) => Text(compactNumber.format(value), style: theme.textTheme.bodySmall),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= points.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(DateFormat('E').format(points[index].date), style: theme.textTheme.bodySmall),
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
                          BarChartRodData(
                            toY: points[i].salesTotal.toMajorDouble,
                            color: salesColor,
                            width: 7,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                          ),
                          BarChartRodData(
                            toY: points[i].expensesTotal.toMajorDouble,
                            color: expensesColor,
                            width: 7,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                          ),
                          BarChartRodData(
                            toY: points[i].netProfit.toMajorDouble,
                            color: profitColor,
                            width: 7,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(points[i].netProfit.cents >= 0 ? 2 : 0),
                              bottom: Radius.circular(points[i].netProfit.cents < 0 ? 2 : 0),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
