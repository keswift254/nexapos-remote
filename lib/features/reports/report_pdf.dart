import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/money.dart';
import '../../data/printing/receipt_branding.dart';
import '../../domain/entities/business_settings.dart';
import '../../domain/services/reports_service.dart';

/// Builds a narrow, monochrome report for continuous-feed thermal printers.
Future<Uint8List> buildReportPdf({
  required ReportData data,
  required String reportTitle,
  required String periodLabel,
  required bool isMonthlyReport,
  required DateFormat timeFormat,
  required BusinessSettings settings,
  required String generatedByName,
}) async {
  final font = pw.Font.courier();
  final fontBold = pw.Font.courierBold();
  final currency = settings.currency;
  String money(int cents) => Money(cents).format(currency: currency);
  final reportBarcodeSource = [
    reportTitle,
    periodLabel,
    data.salesTotal.cents,
    data.expensesTotal.cents,
    data.transactionCount,
  ].join('|');
  final pageFormat = PdfPageFormat(
    settings.paperWidthMm * PdfPageFormat.mm,
    double.infinity,
    marginAll: 4 * PdfPageFormat.mm,
  );
  final timeColumnWidth = isMonthlyReport ? 58.0 : 42.0;

  pw.Widget divider({double thickness = 1.2}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5),
    child: pw.Divider(thickness: thickness, color: PdfColors.black),
  );

  pw.Widget sectionHeader(String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 4, bottom: 3),
    child: pw.Text(
      title.toUpperCase(),
      style: pw.TextStyle(font: fontBold, fontSize: 11),
    ),
  );

  pw.Widget line(String time, String label, String amount) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: timeColumnWidth,
          child: pw.Text(time, style: pw.TextStyle(font: font, fontSize: 8)),
        ),
        pw.Expanded(
          child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: 8)),
        ),
        pw.SizedBox(width: 5),
        pw.Text(amount, style: pw.TextStyle(font: fontBold, fontSize: 8)),
      ],
    ),
  );

  pw.Widget totalLine(String label, String amount, {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(font: bold ? fontBold : font, fontSize: 9),
            ),
            pw.Text(
              amount,
              style: pw.TextStyle(font: bold ? fontBold : font, fontSize: 9),
            ),
          ],
        ),
      );

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: pageFormat,
      build: (context) => pw.DefaultTextStyle(
        style: pw.TextStyle(font: font, fontSize: 9),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              settings.businessName.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontBold, fontSize: 20),
            ),
            pw.Text(
              'Powered by NEXAPOS',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
            divider(thickness: 1.4),
            pw.Text(
              reportTitle.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontBold, fontSize: 15),
            ),
            pw.Text(
              periodLabel.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontBold, fontSize: 9),
            ),
            divider(),
            sectionHeader('Sales'),
            if (data.sales.isEmpty) line('', 'No paid sales', money(0)),
            for (final sale in data.sales)
              line(
                timeFormat.format(DateTime.parse(sale.createdAt).toLocal()),
                sale.itemNames ?? sale.saleNumber,
                money(sale.totalCents),
              ),
            divider(),
            totalLine(
              'Total Paid Sales',
              money(data.salesTotal.cents),
              bold: true,
            ),
            pw.SizedBox(height: 5),
            sectionHeader('Expenses'),
            if (data.expenses.isEmpty) line('', 'No expenses', money(0)),
            for (final expense in data.expenses)
              line(
                timeFormat.format(DateTime.parse(expense.createdAt).toLocal()),
                expense.title,
                money(expense.amountCents),
              ),
            divider(),
            totalLine(
              'Total Expenses',
              money(data.expensesTotal.cents),
              bold: true,
            ),
            if (isMonthlyReport)
              totalLine('Gross Profit', money(data.grossProfitTotal.cents)),
            divider(thickness: 1.8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  isMonthlyReport ? 'NET PROFIT' : 'GRAND TOTAL',
                  style: pw.TextStyle(font: fontBold, fontSize: 14),
                ),
                pw.Text(
                  money(
                    (isMonthlyReport ? data.netProfit : data.grandTotal).cents,
                  ),
                  style: pw.TextStyle(font: fontBold, fontSize: 14),
                ),
              ],
            ),
            divider(thickness: 1.8),
            pw.Text(
              'Cashier/Admin: $generatedByName',
              style: pw.TextStyle(font: font, fontSize: 8),
            ),
            pw.Text(
              'Report Date: $periodLabel',
              style: pw.TextStyle(font: font, fontSize: 8),
            ),
            pw.Text(
              'Generated: ${DateFormat('d MMM yyyy HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(font: font, fontSize: 8),
            ),
            pw.SizedBox(height: 7),
            pw.Text(
              'Generated by NexaPOS',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontBold, fontSize: 9),
            ),
            pw.Text(
              'Thank you for using NexaPOS',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: font, fontSize: 8),
            ),
            pw.Text(
              supportFooter,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: font, fontSize: 8),
            ),
            divider(),
            pw.Image(
              pw.MemoryImage(
                img.encodePng(receiptBarcode(reportBarcodeSource)),
              ),
              width: pageFormat.availableWidth,
            ),
          ],
        ),
      ),
    ),
  );
  return doc.save();
}
