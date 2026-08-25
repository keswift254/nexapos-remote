import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'receipt_screen.dart';

/// Mirrors the on-screen receipt layout (receipt_screen.dart's
/// _ReceiptBody) using the pdf package's own widget tree - a separate
/// set of widget classes from Flutter's, so the two can't share a
/// single widget implementation, only the same content/structure.
Future<Uint8List> buildReceiptPdf(ReceiptData data, PdfPageFormat _) async {
  final sale = data.sale;
  const marginMm = 4.0;
  const fontSize = 9.0;
  final pageFormat = PdfPageFormat(
    data.settings.paperWidthMm * PdfPageFormat.mm,
    double.infinity,
    marginAll: marginMm * PdfPageFormat.mm,
  );
  // Courier is one of the PDF spec's built-in base14 fonts - bundled in
  // the pdf package, not downloaded, so printing a receipt never needs
  // internet. PdfGoogleFonts would fetch a font file over the network
  // on first use, which defeats the point on an offline-first POS.
  final font = pw.Font.courier();
  final fontBold = pw.Font.courierBold();
  // Courier's fixed advance width is 0.6em - sized to the actual
  // printable width so a 58mm receipt doesn't wrap this onto two lines
  // the way a width hardcoded for 80mm did.
  final printableWidthPt = (data.settings.paperWidthMm - marginMm * 2) * PdfPageFormat.mm;
  final dividerLength = (printableWidthPt / (fontSize * 0.6)).floor().clamp(8, 200);
  final divider = '-' * dividerLength;

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
              data.settings.businessName,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontBold, fontSize: 12),
            ),
            if ((data.settings.address ?? '').isNotEmpty)
              pw.Text(data.settings.address!, textAlign: pw.TextAlign.center),
            if ((data.settings.phone ?? '').isNotEmpty)
              pw.Text(data.settings.phone!, textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 8),
            pw.Text('Receipt: ${sale.saleNumber}'),
            pw.Text('Date: ${DateFormat('d MMM yyyy HH:mm').format(sale.createdAt.toLocal())}'),
            pw.Text('Cashier: ${data.cashierName}'),
            pw.Text(divider),
            for (final item in data.items) ...[
              pw.Text(item.itemName),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${item.quantity} x ${item.unitPrice.format(currency: data.settings.currency)}'),
                  pw.Text(item.lineTotal.format(currency: data.settings.currency)),
                ],
              ),
            ],
            pw.Text(divider),
            _amountRow('Subtotal', sale.subtotal.format(currency: data.settings.currency), font),
            _amountRow('Discount', sale.discount.format(currency: data.settings.currency), font),
            _amountRow('Total', sale.total.format(currency: data.settings.currency), fontBold),
            pw.Text(divider),
            pw.Text('Payment: ${sale.paymentMethod.toUpperCase()}'),
            pw.Text('Sale type: ${sale.saleType[0].toUpperCase()}${sale.saleType.substring(1)}'),
            pw.Text('Status: ${sale.status.toUpperCase()}'),
            if ((data.settings.receiptFooter ?? '').isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                data.settings.receiptFooter!,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: font, fontStyle: pw.FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  return doc.save();
}

pw.Widget _amountRow(String label, String value, pw.Font font) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(label, style: pw.TextStyle(font: font)),
      pw.Text(value, style: pw.TextStyle(font: font)),
    ],
  );
}
