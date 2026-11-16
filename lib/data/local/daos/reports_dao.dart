import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/sales_table.dart';
import '../tables/sale_items_table.dart';
import '../tables/expenses_table.dart';
import '../tables/users_table.dart';

part 'reports_dao.g.dart';

class SalesStats {
  /// Net of refunds: a refund is a sale with negative amounts, so it simply comes off the total.
  final int totalCents;

  /// Real sales only - a refund is not a transaction.
  final int count;

  /// What was given back in the period (a positive amount).
  final int refundsCents;

  const SalesStats({required this.totalCents, required this.count, this.refundsCents = 0});
}

class ReportSaleRow {
  final String id;
  final String saleNumber;
  final String cashierName;
  final String saleType;
  final String paymentMethod;
  final String status;
  final int totalCents;
  final String createdAt;

  /// Comma-joined "name xQty" per line item, or null if (unexpectedly)
  /// the sale has none - mirrors PHP's GROUP_CONCAT, which the view
  /// falls back to the sale number for.
  final String? itemNames;

  /// Only ever set for paymentMethod=='cash' (the cashier's own tendered
  /// amount) or a split paymentMethod=='paystack' sale (the cash portion
  /// collected before the M-Pesa gateway charge covered the rest) - see
  /// Sale.isSplitPayment/gatewayPortion, which this mirrors for the
  /// report's cash-vs-M-Pesa split totals.
  final int? cashReceivedCents;

  /// How much of this sale has been given back so far (positive; 0 when nothing has).
  final int refundedCents;

  const ReportSaleRow({
    required this.id,
    required this.saleNumber,
    required this.cashierName,
    required this.saleType,
    required this.paymentMethod,
    required this.status,
    required this.totalCents,
    required this.createdAt,
    required this.itemNames,
    required this.cashReceivedCents,
    this.refundedCents = 0,
  });

  /// 'refunded' once all of it has gone back, 'part refunded' while only some has, else the status as stored.
  String get statusLabel {
    if (refundedCents <= 0) return status;
    return refundedCents >= totalCents ? 'refunded' : 'part refunded';
  }

  static const _mpesaFamily = {'paystack', 'mpesa', 'mpesa_manual', 'intasend'};

  /// The portion of this sale actually paid in cash - the whole total
  /// for a plain cash sale, or just the recorded cash-received amount
  /// for a split cash+M-Pesa sale, or zero for anything else.
  int get cashPortionCents {
    if (paymentMethod == 'cash') return totalCents;
    if (_mpesaFamily.contains(paymentMethod)) return cashReceivedCents ?? 0;
    return 0;
  }

  /// The portion of this sale settled via an M-Pesa-family gateway -
  /// the whole total for a plain paystack/mpesa/intasend sale, or just
  /// the gateway portion (total minus cash already collected) for a
  /// split sale.
  int get mpesaPortionCents {
    if (!_mpesaFamily.contains(paymentMethod)) return 0;
    return totalCents - (cashReceivedCents ?? 0);
  }
}

/// One refund in the Reports screen's Refunds table (all amounts positive: money that went back).
class ReportRefundRow {
  final String id;
  final String saleNumber;

  /// The sale this refund gives back (null only if that sale has not reached this device yet).
  final String? originalSaleNumber;
  final String processedByName;
  final String paymentMethod;
  final String? reason;
  final int totalCents;
  final String createdAt;
  final String? itemNames;

  const ReportRefundRow({
    required this.id,
    required this.saleNumber,
    required this.originalSaleNumber,
    required this.processedByName,
    required this.paymentMethod,
    required this.reason,
    required this.totalCents,
    required this.createdAt,
    required this.itemNames,
  });
}

class ReportExpenseRow {
  final String id;
  final String title;
  final String? note;
  final int amountCents;
  final String createdAt;
  final String enteredByName;

  const ReportExpenseRow({
    required this.id,
    required this.title,
    required this.note,
    required this.amountCents,
    required this.createdAt,
    required this.enteredByName,
  });
}

/// Reporting queries - both plain aggregates (used by the dashboard)
/// and the row-level listings behind the Reports screen. Kept as raw
/// SQL rather than Drift's query builder throughout, since both shapes
/// (a per-sale cost subquery, and a GROUP_CONCAT of line items) are
/// exactly what the builder makes awkward - ported directly from the
/// PHP dashboard/reports pages' own SQL, confirmed against their real
/// queries rather than re-derived from scratch.
@DriftAccessor(tables: [Sales, SaleItems, Expenses, Users])
class ReportsDao extends DatabaseAccessor<AppDatabase> with _$ReportsDaoMixin {
  ReportsDao(super.db);

  Future<SalesStats> salesStatsForRange(String startIsoUtc, String endIsoUtc) async {
    final row = await customSelect(
      '''
      SELECT COALESCE(SUM(total_cents), 0) AS total_cents,
             COUNT(CASE WHEN sale_type <> 'refund' THEN 1 END) AS count,
             COALESCE(SUM(CASE WHEN sale_type = 'refund' THEN -total_cents ELSE 0 END), 0) AS refunds_cents
      FROM sales
      WHERE status = 'paid' AND created_at >= ?1 AND created_at < ?2 AND deleted_at IS NULL
      ''',
      variables: [Variable.withString(startIsoUtc), Variable.withString(endIsoUtc)],
      readsFrom: {sales},
    ).getSingle();
    return SalesStats(
      totalCents: row.read<int>('total_cents'),
      count: row.read<int>('count'),
      refundsCents: row.read<int>('refunds_cents'),
    );
  }

  /// Mirrors PHP's grossProfitTotalForDate: per-sale cost is summed
  /// first, then subtracted from that sale's (already discount-applied)
  /// total, THEN summed across sales - not a flat
  /// sum(unit_price - cost_price) across every item, which would double
  /// count discounts against the margin.
  Future<int> grossProfitCentsForRange(String startIsoUtc, String endIsoUtc) async {
    final row = await customSelect(
      '''
      SELECT COALESCE(SUM(s.total_cents - COALESCE(sc.cost_total_cents, 0)), 0) AS gross_profit_cents
      FROM sales s
      LEFT JOIN (
        SELECT sale_id, SUM(quantity * cost_price_cents) AS cost_total_cents
        FROM sale_items
        WHERE deleted_at IS NULL
        GROUP BY sale_id
      ) sc ON sc.sale_id = s.id
      WHERE s.status = 'paid' AND s.created_at >= ?1 AND s.created_at < ?2 AND s.deleted_at IS NULL
      ''',
      variables: [Variable.withString(startIsoUtc), Variable.withString(endIsoUtc)],
      readsFrom: {sales, saleItems},
    ).getSingle();
    return row.read<int>('gross_profit_cents');
  }

  /// expense_date is a plain calendar date (no time-of-day), unlike
  /// created_at - so this takes local yyyy-MM-dd boundaries directly,
  /// not UTC instants.
  Future<int> expensesCentsForDateRange(String startDateLocal, String endDateLocal) async {
    final row = await customSelect(
      '''
      SELECT COALESCE(SUM(amount_cents), 0) AS total_cents
      FROM expenses
      WHERE expense_date >= ?1 AND expense_date < ?2 AND deleted_at IS NULL
      ''',
      variables: [Variable.withString(startDateLocal), Variable.withString(endDateLocal)],
      readsFrom: {expenses},
    ).getSingle();
    return row.read<int>('total_cents');
  }

  /// Powers the Reports screen's Sales table - newest first, matching
  /// PHP's `ORDER BY sales.created_at DESC`.
  Future<List<ReportSaleRow>> salesForRange(String startIsoUtc, String endIsoUtc) async {
    final rows = await customSelect(
      '''
      SELECT
        s.id AS id,
        s.sale_number AS sale_number,
        u.name AS cashier_name,
        s.sale_type AS sale_type,
        s.payment_method AS payment_method,
        s.status AS status,
        s.total_cents AS total_cents,
        s.created_at AS created_at,
        s.cash_received_cents AS cash_received_cents,
        COALESCE((SELECT SUM(-r.total_cents) FROM sales r
                  WHERE r.refund_of_sale_id = s.id AND r.sale_type = 'refund' AND r.status = 'paid'
                    AND r.deleted_at IS NULL), 0) AS refunded_cents,
        GROUP_CONCAT(si.item_name || ' x' || si.quantity, ', ') AS item_names
      FROM sales s
      JOIN users u ON u.id = s.user_id
      LEFT JOIN sale_items si ON si.sale_id = s.id AND si.deleted_at IS NULL
      WHERE s.status = 'paid' AND s.sale_type <> 'refund' AND s.created_at >= ?1 AND s.created_at < ?2 AND s.deleted_at IS NULL
      GROUP BY s.id
      ORDER BY s.created_at DESC
      ''',
      variables: [Variable.withString(startIsoUtc), Variable.withString(endIsoUtc)],
      readsFrom: {sales, saleItems, users},
    ).get();
    return rows
        .map((row) => ReportSaleRow(
              id: row.read<String>('id'),
              saleNumber: row.read<String>('sale_number'),
              cashierName: row.read<String>('cashier_name'),
              saleType: row.read<String>('sale_type'),
              paymentMethod: row.read<String>('payment_method'),
              status: row.read<String>('status'),
              totalCents: row.read<int>('total_cents'),
              createdAt: row.read<String>('created_at'),
              itemNames: row.readNullable<String>('item_names'),
              cashReceivedCents: row.readNullable<int>('cash_received_cents'),
              refundedCents: row.read<int>('refunded_cents'),
            ))
        .toList();
  }

  /// Powers the Reports screen's Refunds table - newest first, like the Sales table.
  Future<List<ReportRefundRow>> refundsForRange(String startIsoUtc, String endIsoUtc) async {
    final rows = await customSelect(
      '''
      SELECT
        r.id AS id,
        r.sale_number AS sale_number,
        o.sale_number AS original_sale_number,
        u.name AS processed_by,
        r.payment_method AS payment_method,
        r.refund_reason AS refund_reason,
        -r.total_cents AS total_cents,
        r.created_at AS created_at,
        GROUP_CONCAT(si.item_name || ' x' || (-si.quantity), ', ') AS item_names
      FROM sales r
      JOIN users u ON u.id = r.user_id
      LEFT JOIN sales o ON o.id = r.refund_of_sale_id
      LEFT JOIN sale_items si ON si.sale_id = r.id AND si.deleted_at IS NULL
      WHERE r.sale_type = 'refund' AND r.status = 'paid' AND r.created_at >= ?1 AND r.created_at < ?2 AND r.deleted_at IS NULL
      GROUP BY r.id
      ORDER BY r.created_at DESC
      ''',
      variables: [Variable.withString(startIsoUtc), Variable.withString(endIsoUtc)],
      readsFrom: {sales, saleItems, users},
    ).get();
    return rows
        .map((row) => ReportRefundRow(
              id: row.read<String>('id'),
              saleNumber: row.read<String>('sale_number'),
              originalSaleNumber: row.readNullable<String>('original_sale_number'),
              processedByName: row.read<String>('processed_by'),
              paymentMethod: row.read<String>('payment_method'),
              reason: row.readNullable<String>('refund_reason'),
              totalCents: row.read<int>('total_cents'),
              createdAt: row.read<String>('created_at'),
              itemNames: row.readNullable<String>('item_names'),
            ))
        .toList();
  }

  /// Powers the Reports screen's Expenses table - oldest first, matching
  /// PHP's `ORDER BY expense_date ASC, created_at ASC, id ASC` (the
  /// opposite order from the single-day Expenses management screen,
  /// which shows newest first - two different views of the same table).
  Future<List<ReportExpenseRow>> expensesForRange(String startDateLocal, String endDateLocal) async {
    final rows = await customSelect(
      '''
      SELECT
        e.id AS id,
        e.title AS title,
        e.note AS note,
        e.amount_cents AS amount_cents,
        e.created_at AS created_at,
        COALESCE(u.name, 'System Admin') AS entered_by_name
      FROM expenses e
      LEFT JOIN users u ON u.id = e.user_id
      WHERE e.expense_date >= ?1 AND e.expense_date < ?2 AND e.deleted_at IS NULL
      ORDER BY e.expense_date ASC, e.created_at ASC, e.id ASC
      ''',
      variables: [Variable.withString(startDateLocal), Variable.withString(endDateLocal)],
      readsFrom: {expenses, users},
    ).get();
    return rows
        .map((row) => ReportExpenseRow(
              id: row.read<String>('id'),
              title: row.read<String>('title'),
              note: row.readNullable<String>('note'),
              amountCents: row.read<int>('amount_cents'),
              createdAt: row.read<String>('created_at'),
              enteredByName: row.read<String>('entered_by_name'),
            ))
        .toList();
  }
}
