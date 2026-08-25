import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/utils/money.dart';
import '../../domain/entities/business_settings.dart';
import '../../domain/services/reports_service.dart';

const _brandColor = PdfColors.indigo700;

/// Mirrors PHP's reports.php `report-print-receipt` section, including
/// its exact quirk of branding the header "NexaPOS" (the software)
/// rather than the shop's own business name - that's a real, deliberate
/// choice in the reference template, not an oversight: this is an
/// internally-generated report, not a customer-facing receipt, and
/// business_name never appears anywhere in PHP's own print block.
///
/// Same thermal-receipt page shape as receipt_pdf.dart (narrow width
/// from business_settings.paperWidthMm, height left as double.infinity
/// so the page auto-sizes to content) rather than a fixed A4 page - a
/// fixed page size sent to a continuous-feed thermal printer makes it
/// feed blank paper trying to fill out the rest of that phantom page
/// after the real content ends. Helvetica rather than Courier - still
/// one of the PDF spec's bundled base14 fonts (zero network dependency,
/// matching receipt_pdf.dart's reasoning), just a more report-
/// appropriate face than a receipt's monospace look. Section markers
/// are plain colored circles rather than real icon glyphs - matching
/// Material icons exactly would mean bundling an icon font, which isn't
/// worth the added risk for a cosmetic accent.
Future<Uint8List> buildReportPdf({
  required ReportData data,
  required String reportTitle,
  required String periodLabel,
  required bool isMonthlyReport,
  required DateFormat timeFormat,
  required BusinessSettings settings,
  required String generatedByName,
}) async {
  final font = pw.Font.helvetica();
  final fontBold = pw.Font.helveticaBold();
  final currency = settings.currency;
  String money(int cents) => Money(cents).format(currency: currency);
  final pageFormat = PdfPageFormat(
    settings.paperWidthMm * PdfPageFormat.mm,
    double.infinity,
    marginAll: 4 * PdfPageFormat.mm,
  );

  pw.Widget sectionHeader(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          children: [
            pw.Container(width: 7, height: 7, decoration: const pw.BoxDecoration(color: _brandColor, shape: pw.BoxShape.circle)),
            pw.SizedBox(width: 5),
            pw.Text(title.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 10, color: _brandColor)),
          ],
        ),
      );

  pw.Widget line(String time, String label, String amount) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          children: [
            pw.SizedBox(width: 40, child: pw.Text(time, style: pw.TextStyle(font: font, fontSize: 8))),
            pw.Expanded(child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: 8))),
            pw.Text(amount, style: pw.TextStyle(font: fontBold, fontSize: 8)),
          ],
        ),
      );

  pw.Widget totalLine(String label, String amount, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: pw.TextStyle(font: fontBold, fontSize: 9)),
            pw.Text(amount, style: pw.TextStyle(font: bold ? fontBold : font, fontSize: 9)),
          ],
        ),
      );

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: pageFormat,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 18,
                    height: 18,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(color: _brandColor, borderRadius: pw.BorderRadius.circular(5)),
                    child: pw.Text('N', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white)),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Text('NexaPOS', style: pw.TextStyle(font: fontBold, fontSize: 13)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text(reportTitle.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 11, color: _brandColor), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 2),
              pw.Text(periodLabel, style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(thickness: 1.2),
          pw.SizedBox(height: 10),
          sectionHeader('Sales'),
          pw.Divider(borderStyle: pw.BorderStyle.dashed),
          if (data.sales.isEmpty) line('', 'No paid sales', money(0)),
          for (final sale in data.sales)
            line(timeFormat.format(DateTime.parse(sale.createdAt).toLocal()), sale.itemNames ?? sale.saleNumber, money(sale.totalCents)),
          pw.Divider(),
          totalLine('Total Paid Sales', money(data.salesTotal.cents)),
          pw.SizedBox(height: 12),
          sectionHeader('Expenses'),
          pw.Divider(borderStyle: pw.BorderStyle.dashed),
          if (data.expenses.isEmpty) line('', 'No expenses', money(0)),
          for (final expense in data.expenses)
            line(timeFormat.format(DateTime.parse(expense.createdAt).toLocal()), '${expense.title} x1', money(expense.amountCents)),
          pw.Divider(),
          totalLine('Total Expenses', money(data.expensesTotal.cents)),
          pw.SizedBox(height: 12),
          sectionHeader('Grand Total'),
          pw.Divider(),
          if (isMonthlyReport) totalLine('Gross Profit', money(data.grossProfitTotal.cents)),
          pw.SizedBox(height: 3),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(isMonthlyReport ? 'Net Profit' : 'Grand Total', style: pw.TextStyle(font: fontBold, fontSize: 12)),
              pw.Text(
                money((isMonthlyReport ? data.netProfit : data.grandTotal).cents),
                style: pw.TextStyle(font: fontBold, fontSize: 12),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Divider(thickness: 1.2),
          pw.SizedBox(height: 6),
          pw.Text('Cashier/Admin: $generatedByName', style: pw.TextStyle(font: font, fontSize: 8, color: _brandColor)),
          pw.Text('Report Date: $periodLabel', style: pw.TextStyle(font: font, fontSize: 8, color: _brandColor)),
          pw.Text(
            'Generated Time: ${DateFormat('d MMM yyyy HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(font: font, fontSize: 8, color: _brandColor),
          ),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.Text('Generated by NexaPOS', style: pw.TextStyle(font: fontBold, fontSize: 9))),
          pw.Center(child: pw.Text('Thank you for using NexaPOS', style: pw.TextStyle(font: font, fontSize: 8))),
        ],
      ),
    ),
  );
  return doc.save();
}
