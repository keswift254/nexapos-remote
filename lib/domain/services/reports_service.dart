import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/money.dart';
import '../../data/local/daos/reports_dao.dart';

part 'reports_service.g.dart';

@Riverpod(keepAlive: true)
ReportsService reportsService(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return ReportsService(db.reportsDao, ref.watch(clockProvider));
}

class DailyStats {
  final Money salesTotal;
  final int salesCount;
  final Money expensesTotal;
  final Money grossProfit;
  final Money netProfit;

  const DailyStats({
    required this.salesTotal,
    required this.salesCount,
    required this.expensesTotal,
    required this.grossProfit,
    required this.netProfit,
  });
}

class DailyPoint {
  final DateTime date;
  final Money salesTotal;
  final Money expensesTotal;
  final Money netProfit;

  const DailyPoint({
    required this.date,
    required this.salesTotal,
    required this.expensesTotal,
    required this.netProfit,
  });
}

/// direction/percent mirror PHP's dashboardPercentChange() exactly,
/// including its "previous is ~zero" special case (current>0 -> +100%,
/// both zero -> flat) - integers make the epsilon PHP needed for float
/// comparison unnecessary, an exact zero check is enough here.
class PercentChange {
  final int percent;
  final String direction;

  const PercentChange({required this.percent, required this.direction});

  factory PercentChange.compare(Money current, Money previous) {
    if (previous.cents == 0) {
      if (current.cents == 0) return const PercentChange(percent: 0, direction: 'flat');
      return const PercentChange(percent: 100, direction: 'up');
    }
    final percent = ((current.cents - previous.cents) / previous.cents.abs() * 100).round();
    final direction = percent > 0 ? 'up' : (percent < 0 ? 'down' : 'flat');
    return PercentChange(percent: percent, direction: direction);
  }
}

/// Date-range aggregation for the dashboard - ported from the PHP
/// reference's salesStatsForDate/grossProfitTotalForDate/
/// expensesTotalForDate (see ReportsDao for the exact SQL each mirrors).
/// Deliberately narrower than PHP's full dashboardChartData: that also
/// builds weekly/monthly/yearly bucketed history views, which is a
/// separate, heavier feature to add later if wanted - this covers
/// "today vs yesterday" plus a simple daily trend.
class ReportsService {
  final ReportsDao _dao;
  final Clock _clock;

  ReportsService(this._dao, this._clock);

  /// "Today" in the shop's own local time, not the injected UTC clock's
  /// raw value - a sale at 1am local time in a UTC+3 shop must count as
  /// today, not still-yesterday-in-UTC.
  DateTime get today {
    final now = _clock.now().toLocal();
    return DateTime(now.year, now.month, now.day);
  }

  Future<DailyStats> statsForLocalDate(DateTime localDate) async {
    final startLocal = DateTime(localDate.year, localDate.month, localDate.day);
    final endLocal = startLocal.add(const Duration(days: 1));
    final startUtc = startLocal.toUtc().toIso8601String();
    final endUtc = endLocal.toUtc().toIso8601String();
    final dateFormat = DateFormat('yyyy-MM-dd');

    final salesStats = await _dao.salesStatsForRange(startUtc, endUtc);
    final grossProfitCents = await _dao.grossProfitCentsForRange(startUtc, endUtc);
    final expensesCents = await _dao.expensesCentsForDateRange(
      dateFormat.format(startLocal),
      dateFormat.format(endLocal),
    );

    final grossProfit = Money(grossProfitCents);
    final expensesTotal = Money(expensesCents);
    return DailyStats(
      salesTotal: Money(salesStats.totalCents),
      salesCount: salesStats.count,
      expensesTotal: expensesTotal,
      grossProfit: grossProfit,
      netProfit: grossProfit - expensesTotal,
    );
  }

  Future<List<DailyPoint>> lastNDays(int days) async {
    final points = <DailyPoint>[];
    for (var i = days - 1; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final stats = await statsForLocalDate(date);
      points.add(DailyPoint(
        date: date,
        salesTotal: stats.salesTotal,
        expensesTotal: stats.expensesTotal,
        netProfit: stats.netProfit,
      ));
    }
    return points;
  }

  /// General date-range report backing the Reports screen - unlike
  /// statsForLocalDate/lastNDays (a single day at a time, for the
  /// dashboard), this takes an arbitrary [startLocal, endLocalExclusive)
  /// window so it can serve the daily/monthly/custom-range tabs alike.
  /// grandTotal mirrors PHP's reports.php exactly: salesTotal minus
  /// expensesTotal, NOT cost-adjusted - only the Monthly tab additionally
  /// shows the cost-adjusted netProfit figure; both are computed here so
  /// the screen can pick per tab without a second query.
  Future<ReportData> reportForRange(DateTime startLocal, DateTime endLocalExclusive) async {
    final startUtc = startLocal.toUtc().toIso8601String();
    final endUtc = endLocalExclusive.toUtc().toIso8601String();
    final dateFormat = DateFormat('yyyy-MM-dd');

    final sales = await _dao.salesForRange(startUtc, endUtc);
    final expenses = await _dao.expensesForRange(
      dateFormat.format(startLocal),
      dateFormat.format(endLocalExclusive),
    );
    final grossProfitTotal = Money(await _dao.grossProfitCentsForRange(startUtc, endUtc));

    final salesTotal = Money(sales.fold<int>(0, (sum, s) => sum + s.totalCents));
    final expensesTotal = Money(expenses.fold<int>(0, (sum, e) => sum + e.amountCents));

    return ReportData(
      sales: sales,
      expenses: expenses,
      salesTotal: salesTotal,
      expensesTotal: expensesTotal,
      grossProfitTotal: grossProfitTotal,
      netProfit: grossProfitTotal - expensesTotal,
      grandTotal: salesTotal - expensesTotal,
      transactionCount: sales.length,
    );
  }
}

class ReportData {
  final List<ReportSaleRow> sales;
  final List<ReportExpenseRow> expenses;
  final Money salesTotal;
  final Money expensesTotal;
  final Money grossProfitTotal;
  final Money netProfit;
  final Money grandTotal;
  final int transactionCount;

  const ReportData({
    required this.sales,
    required this.expenses,
    required this.salesTotal,
    required this.expensesTotal,
    required this.grossProfitTotal,
    required this.netProfit,
    required this.grandTotal,
    required this.transactionCount,
  });
}
