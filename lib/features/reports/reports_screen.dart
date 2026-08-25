import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/business_settings.dart';
import '../../domain/services/business_settings_service.dart';
import '../../domain/services/reports_service.dart';
import '../../domain/services/session_service.dart';
import 'report_pdf.dart';

part 'reports_screen.g.dart';

@riverpod
Future<ReportData> reportData(Ref ref, DateTime start, DateTime endExclusive) {
  return ref.watch(reportsServiceProvider).reportForRange(start, endExclusive);
}

@riverpod
Future<BusinessSettings> reportBusinessSettings(Ref ref) {
  return ref.watch(businessSettingsServiceProvider).get();
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _ordinal(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  switch (day % 10) {
    case 1:
      return '${day}st';
    case 2:
      return '${day}nd';
    case 3:
      return '${day}rd';
    default:
      return '${day}th';
  }
}

/// Port of PHP's Reports page (app/views/reports.php): 4 tabs sharing
/// the same underlying sales+expenses query, just different date
/// windows and which profit figure is emphasized. Unlike PHP's raw GET
/// form (which shows all 4 date fields at once and re-submits the
/// whole page), only the field(s) relevant to the active tab are
/// shown, and switching tabs applies immediately while editing a date
/// stays staged until "View Report" - matching the two different real
/// interactions PHP's link-tabs vs text-field-submit already implied.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _mode = 'day';
  DateTime _draftDate = _dateOnly(DateTime.now());
  DateTime _draftMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _draftRangeStart = _dateOnly(DateTime.now()).subtract(const Duration(days: 6));
  DateTime _draftRangeEnd = _dateOnly(DateTime.now());

  String _appliedMode = 'day';
  DateTime _appliedDate = _dateOnly(DateTime.now());
  DateTime _appliedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _appliedRangeStart = _dateOnly(DateTime.now()).subtract(const Duration(days: 6));
  DateTime _appliedRangeEnd = _dateOnly(DateTime.now());

  void _apply() {
    setState(() {
      _appliedMode = _mode;
      _appliedDate = _draftDate;
      _appliedMonth = _draftMonth;
      _appliedRangeStart = _draftRangeStart;
      _appliedRangeEnd = _draftRangeEnd;
    });
  }

  void _selectTab(String mode) {
    setState(() => _mode = mode);
    _apply();
  }

  (DateTime, DateTime) get _range {
    switch (_appliedMode) {
      case 'month':
        final start = DateTime(_appliedMonth.year, _appliedMonth.month, 1);
        return (start, DateTime(start.year, start.month + 1, 1));
      case 'range':
        final a = _dateOnly(_appliedRangeStart);
        final b = _dateOnly(_appliedRangeEnd);
        final start = a.isBefore(b) ? a : b;
        final end = a.isBefore(b) ? b : a;
        return (start, end.add(const Duration(days: 1)));
      default: // day, expenses
        final d = _dateOnly(_appliedDate);
        return (d, d.add(const Duration(days: 1)));
    }
  }

  bool get _isMonthly => _appliedMode == 'month';

  bool get _isMultiDay => _appliedMode == 'month' || _appliedMode == 'range';

  String get _reportTitle {
    switch (_appliedMode) {
      case 'month':
        return 'Monthly Sales Report';
      case 'range':
        return 'Selected Period Sales Report';
      case 'expenses':
        return 'Expenses Report';
      default:
        return 'Daily Sales Report';
    }
  }

  String get _periodLabel {
    switch (_appliedMode) {
      case 'month':
        return DateFormat('MMMM yyyy').format(_appliedMonth).toUpperCase();
      case 'range':
        final a = _dateOnly(_appliedRangeStart);
        final b = _dateOnly(_appliedRangeEnd);
        final start = a.isBefore(b) ? a : b;
        final end = a.isBefore(b) ? b : a;
        return '${_ordinal(start.day)} ${DateFormat('MMM yyyy').format(start)} - ${_ordinal(end.day)} ${DateFormat('MMM yyyy').format(end)}'
            .toUpperCase();
      default:
        return '${_ordinal(_appliedDate.day)} ${DateFormat('MMMM').format(_appliedDate)}'.toUpperCase();
    }
  }

  /// Short "22 AUG"-style label for the exported file's name - based on
  /// the report's own selected date/period, not the day it happens to
  /// be exported on, so exporting an old report doesn't get today's
  /// date stamped on it.
  String get _fileNameLabel {
    switch (_appliedMode) {
      case 'month':
        return DateFormat('MMM yyyy').format(_appliedMonth).toUpperCase();
      case 'range':
        final a = _dateOnly(_appliedRangeStart);
        final b = _dateOnly(_appliedRangeEnd);
        final start = a.isBefore(b) ? a : b;
        final end = a.isBefore(b) ? b : a;
        return '${DateFormat('d MMM').format(start)} - ${DateFormat('d MMM').format(end)}'.toUpperCase();
      default:
        return DateFormat('d MMM').format(_appliedDate).toUpperCase();
    }
  }

  Future<void> _pickDraftDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _draftDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _draftDate = picked);
  }

  Future<void> _pickDraftMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _draftMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _draftMonth = DateTime(picked.year, picked.month, 1));
  }

  Future<void> _pickDraftRangeStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _draftRangeStart,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _draftRangeStart = picked);
  }

  Future<void> _pickDraftRangeEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _draftRangeEnd,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _draftRangeEnd = picked);
  }

  Widget _dateField(String label, DateTime value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        child: Text(DateFormat('d MMM yyyy').format(value)),
      ),
    );
  }

  Future<Uint8List> _buildPdfBytes(ReportData data) async {
    final settings = await ref.read(businessSettingsServiceProvider).get();
    final userName = ref.read(sessionProvider)?.name ?? 'System Admin';
    final timeFormat = DateFormat(_isMultiDay ? 'd MMM HH:mm' : 'HH:mm');
    return buildReportPdf(
      data: data,
      reportTitle: _reportTitle,
      periodLabel: _periodLabel,
      isMonthlyReport: _isMonthly,
      timeFormat: timeFormat,
      settings: settings,
      generatedByName: userName,
    );
  }

  Future<void> _print(ReportData data) async {
    final bytes = await _buildPdfBytes(data);
    await Printing.layoutPdf(onLayout: (format) => bytes);
  }

  /// Distinct from _print: the OS print dialog only offers to save as
  /// PDF if a virtual PDF printer happens to be installed, which isn't
  /// guaranteed - this writes the file directly to wherever the user
  /// picks, independent of installed printers.
  Future<void> _exportPdf(ReportData data) async {
    final bytes = await _buildPdfBytes(data);
    final fileName = '$_fileNameLabel.pdf';
    final uri = await FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: 'application/pdf');
    if (!mounted || uri == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to ${uri.toFilePath()}')));
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    final dataAsync = ref.watch(reportDataProvider(range.$1, range.$2));
    final currency = ref.watch(reportBusinessSettingsProvider).maybeWhen(data: (s) => s.currency, orElse: () => 'KES');

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (_mode == 'day' || _mode == 'expenses')
                SizedBox(width: 180, child: _dateField('Report date', _draftDate, _pickDraftDate)),
              if (_mode == 'month')
                SizedBox(width: 180, child: _dateField('Report month', _draftMonth, _pickDraftMonth)),
              if (_mode == 'range') ...[
                SizedBox(width: 180, child: _dateField('Start date', _draftRangeStart, _pickDraftRangeStart)),
                SizedBox(width: 180, child: _dateField('End date', _draftRangeEnd, _pickDraftRangeEnd)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(label: const Text('Daily Sales'), selected: _mode == 'day', onSelected: (_) => _selectTab('day')),
              ChoiceChip(label: const Text('Monthly Sales'), selected: _mode == 'month', onSelected: (_) => _selectTab('month')),
              ChoiceChip(label: const Text('Expenses'), selected: _mode == 'expenses', onSelected: (_) => _selectTab('expenses')),
              ChoiceChip(label: const Text('Selected Period'), selected: _mode == 'range', onSelected: (_) => _selectTab('range')),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: _apply, child: const Text('View Report')),
              dataAsync.maybeWhen(
                data: (data) => OutlinedButton.icon(
                  onPressed: () => _print(data),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print'),
                ),
                orElse: () => OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.print_outlined), label: const Text('Print')),
              ),
              dataAsync.maybeWhen(
                data: (data) => OutlinedButton.icon(
                  onPressed: () => _exportPdf(data),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Export PDF'),
                ),
                orElse: () => OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Export PDF')),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(_reportTitle, style: Theme.of(context).textTheme.titleLarge),
          Text(_periodLabel, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          dataAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('Failed to load report: $error'),
            ),
            data: (data) => _ReportBody(data: data, isMonthly: _isMonthly, isMultiDay: _isMultiDay, currency: currency),
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final ReportData data;
  final bool isMonthly;
  final bool isMultiDay;
  final String currency;

  const _ReportBody({required this.data, required this.isMonthly, required this.isMultiDay, required this.currency});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat(isMultiDay ? 'd MMM HH:mm' : 'HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricTile(label: 'Paid Sales', value: data.salesTotal.format(currency: currency)),
            _MetricTile(label: 'Total Expenses', value: data.expensesTotal.format(currency: currency)),
            if (isMonthly) _MetricTile(label: 'Gross Profit', value: data.grossProfitTotal.format(currency: currency)),
            _MetricTile(
              label: isMonthly ? 'Net Profit' : 'Grand Total',
              value: (isMonthly ? data.netProfit : data.grandTotal).format(currency: currency),
            ),
            _MetricTile(label: 'Transactions', value: '${data.transactionCount}'),
          ],
        ),
        const SizedBox(height: 20),
        Text('Sales', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Item')),
              DataColumn(label: Text('Cashier')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Payment')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Total'), numeric: true),
              DataColumn(label: Text('Time')),
            ],
            rows: [
              for (final sale in data.sales)
                DataRow(cells: [
                  DataCell(Text(sale.itemNames ?? sale.saleNumber)),
                  DataCell(Text(sale.cashierName)),
                  DataCell(Text(sale.saleType)),
                  DataCell(Text(sale.paymentMethod)),
                  DataCell(Text(sale.status)),
                  DataCell(Text(Money(sale.totalCents).format(currency: currency))),
                  DataCell(Text(timeFormat.format(DateTime.parse(sale.createdAt).toLocal()))),
                ]),
              if (data.sales.isEmpty)
                const DataRow(cells: [
                  DataCell(Text('No paid sales for this period.')),
                  DataCell(Text('')),
                  DataCell(Text('')),
                  DataCell(Text('')),
                  DataCell(Text('')),
                  DataCell(Text('')),
                  DataCell(Text('')),
                ]),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Total Paid Sales: ${data.salesTotal.format(currency: currency)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Expenses', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Item')),
              DataColumn(label: Text('Entered by')),
              DataColumn(label: Text('Total'), numeric: true),
              DataColumn(label: Text('Time')),
            ],
            rows: [
              for (final expense in data.expenses)
                DataRow(cells: [
                  DataCell(Text(
                    (expense.note ?? '').isEmpty ? expense.title : '${expense.title} (${expense.note})',
                  )),
                  DataCell(Text(expense.enteredByName)),
                  DataCell(Text(Money(expense.amountCents).format(currency: currency))),
                  DataCell(Text(timeFormat.format(DateTime.parse(expense.createdAt).toLocal()))),
                ]),
              if (data.expenses.isEmpty)
                const DataRow(cells: [
                  DataCell(Text('No expenses for this period.')),
                  DataCell(Text('')),
                  DataCell(Text('')),
                  DataCell(Text('')),
                ]),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Total Expenses: ${data.expensesTotal.format(currency: currency)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const Divider(height: 32),
        if (isMonthly)
          _GrandTotalRow(label: 'Gross Profit', value: data.grossProfitTotal.format(currency: currency)),
        _GrandTotalRow(
          label: isMonthly ? 'Net Profit' : 'Grand Total',
          value: (isMonthly ? data.netProfit : data.grandTotal).format(currency: currency),
          bold: true,
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _GrandTotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _GrandTotalRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: bold ? FontWeight.bold : FontWeight.normal);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
