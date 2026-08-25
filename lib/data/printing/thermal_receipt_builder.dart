import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import '../../features/checkout/receipt_screen.dart' show ReceiptData;

/// Mirrors receipt_pdf.dart's content/layout exactly (same fields, same
/// order) so a shop's printed paper receipt and its PDF/screen receipt
/// never disagree - only the output format differs (raw ESC/POS bytes
/// for a real thermal printer here, vs. a PDF document there).
Future<Uint8List> buildThermalReceipt(ReceiptData data) async {
  final profile = await CapabilityProfile.load();
  final paperSize = data.settings.paperWidthMm <= 58 ? PaperSize.mm58 : PaperSize.mm80;
  final generator = Generator(paperSize, profile);
  final sale = data.sale;
  final currency = data.settings.currency;
  final bytes = <int>[];

  bytes.addAll(generator.text(
    data.settings.businessName,
    styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
  ));
  if ((data.settings.address ?? '').isNotEmpty) {
    bytes.addAll(generator.text(data.settings.address!, styles: const PosStyles(align: PosAlign.center)));
  }
  if ((data.settings.phone ?? '').isNotEmpty) {
    bytes.addAll(generator.text(data.settings.phone!, styles: const PosStyles(align: PosAlign.center)));
  }
  bytes.addAll(generator.feed(1));
  bytes.addAll(generator.text('Receipt: ${sale.saleNumber}'));
  bytes.addAll(generator.text('Date: ${DateFormat('d MMM yyyy HH:mm').format(sale.createdAt.toLocal())}'));
  bytes.addAll(generator.text('Cashier: ${data.cashierName}'));
  bytes.addAll(generator.hr());

  for (final item in data.items) {
    bytes.addAll(generator.text(item.itemName));
    bytes.addAll(generator.row([
      PosColumn(text: '${item.quantity} x ${item.unitPrice.format(currency: currency)}', width: 7),
      PosColumn(text: item.lineTotal.format(currency: currency), width: 5, styles: const PosStyles(align: PosAlign.right)),
    ]));
  }
  bytes.addAll(generator.hr());

  bytes.addAll(_amountRow(generator, 'Subtotal', sale.subtotal.format(currency: currency)));
  bytes.addAll(_amountRow(generator, 'Discount', sale.discount.format(currency: currency)));
  bytes.addAll(_amountRow(generator, 'Total', sale.total.format(currency: currency), bold: true));
  bytes.addAll(generator.hr());

  bytes.addAll(generator.text('Payment: ${sale.paymentMethod.toUpperCase()}'));
  bytes.addAll(generator.text('Sale type: ${sale.saleType[0].toUpperCase()}${sale.saleType.substring(1)}'));
  bytes.addAll(generator.text('Status: ${sale.status.toUpperCase()}'));

  if ((data.settings.receiptFooter ?? '').isNotEmpty) {
    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text(data.settings.receiptFooter!, styles: const PosStyles(align: PosAlign.center)));
  }

  bytes.addAll(generator.feed(2));
  bytes.addAll(generator.cut());
  return Uint8List.fromList(bytes);
}

/// A fixed, sale-independent ticket so "Test print" can confirm the
/// printer is reachable and the paper width looks right before the first
/// real sale ever needs to go through it.
Future<Uint8List> buildTestTicket(int paperWidthMm) async {
  final profile = await CapabilityProfile.load();
  final paperSize = paperWidthMm <= 58 ? PaperSize.mm58 : PaperSize.mm80;
  final generator = Generator(paperSize, profile);
  final bytes = <int>[];
  bytes.addAll(generator.text('NexaPOS', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2)));
  bytes.addAll(generator.text('Test print', styles: const PosStyles(align: PosAlign.center)));
  bytes.addAll(generator.hr());
  bytes.addAll(generator.text('If you can read this, the printer\nis connected and set up correctly.'));
  bytes.addAll(generator.feed(2));
  bytes.addAll(generator.cut());
  return Uint8List.fromList(bytes);
}

List<int> _amountRow(Generator generator, String label, String value, {bool bold = false}) {
  final styles = PosStyles(bold: bold);
  return generator.row([
    PosColumn(text: label, width: 7, styles: styles),
    PosColumn(text: value, width: 5, styles: styles.copyWith(align: PosAlign.right)),
  ]);
}
