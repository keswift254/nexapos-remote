import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';

import '../../features/checkout/receipt_screen.dart' show ReceiptData;
import 'receipt_branding.dart';

/// Mirrors receipt_pdf.dart's content/layout exactly (same fields, same
/// order) so a shop's printed paper receipt and its PDF/screen receipt
/// never disagree - only the output format differs (raw ESC/POS bytes
/// for a real thermal printer here, vs. a PDF document there).
Future<Uint8List> buildThermalReceipt(ReceiptData data) async {
  final profile = await CapabilityProfile.load();
  final paperSize = data.settings.paperWidthMm <= 58
      ? PaperSize.mm58
      : PaperSize.mm80;
  final generator = Generator(paperSize, profile);
  final sale = data.sale;
  final currency = data.settings.currency;
  final bytes = <int>[];

  bytes.addAll(
    generator.text(
      data.settings.businessName.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ),
  );
  bytes.addAll(
    generator.text(
      'Powered by NEXAPOS',
      styles: const PosStyles(align: PosAlign.center),
    ),
  );
  if (sale.isRefund) {
    bytes.addAll(
      generator.text(
        'REFUND',
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
      ),
    );
  }
  if ((data.settings.address ?? '').isNotEmpty) {
    bytes.addAll(
      generator.text(
        data.settings.address!,
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
  }
  if ((data.settings.phone ?? '').isNotEmpty) {
    bytes.addAll(
      generator.text(
        data.settings.phone!,
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
  }
  bytes.addAll(generator.hr());
  bytes.addAll(generator.text('Receipt #: ${sale.saleNumber}'));
  bytes.addAll(
    generator.text(
      'Date: ${DateFormat('d MMM yyyy HH:mm').format(sale.createdAt.toLocal())}',
    ),
  );
  if (sale.isRefund) {
    if (data.originalSaleNumber != null) bytes.addAll(generator.text('Refund of: ${data.originalSaleNumber}'));
    if ((sale.refundReason ?? '').isNotEmpty) bytes.addAll(generator.text('Reason: ${sale.refundReason}'));
  }
  bytes.addAll(generator.text('${data.personLabel}: ${data.cashierName}'));
  bytes.addAll(generator.hr());

  for (final item in data.items) {
    bytes.addAll(
      generator.row([
        PosColumn(
          text:
              '${item.itemName}  ${item.quantity} x ${item.unitPrice.format(currency: currency)}',
          width: 7,
        ),
        PosColumn(
          text: item.lineTotal.format(currency: currency),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]),
    );
  }
  bytes.addAll(generator.hr());

  bytes.addAll(
    _amountRow(generator, 'Subtotal', sale.subtotal.format(currency: currency)),
  );
  bytes.addAll(
    _amountRow(generator, 'Discount', sale.discount.format(currency: currency)),
  );
  bytes.addAll(
    _amountRow(
      generator,
      'TOTAL',
      sale.total.format(currency: currency),
      bold: true,
      doubleSize: true,
    ),
  );
  bytes.addAll(generator.hr());

  bytes.addAll(generator.text('${data.paymentLabel}: ${sale.paymentMethodLabel}'));
  final reference = data.mpesaReference;
  if (reference != null) bytes.addAll(generator.text('Reference: $reference'));
  if (sale.isRefund) {
    final split = data.refundSplit;
    if (split != null) {
      bytes.addAll(_amountRow(generator, 'Cash back', split.cash.format(currency: currency)));
      bytes.addAll(_amountRow(generator, 'M-Pesa back', split.mpesa.format(currency: currency)));
    }
  } else if (sale.isSplitPayment) {
    bytes.addAll(
      _amountRow(generator, 'Cash received', sale.cashReceived!.format(currency: currency)),
    );
    bytes.addAll(
      _amountRow(generator, 'Paid via M-Pesa', sale.gatewayPortion.format(currency: currency)),
    );
  } else if (sale.cashReceived != null) {
    bytes.addAll(
      _amountRow(
        generator,
        'Cash received',
        sale.cashReceived!.format(currency: currency),
      ),
    );
    bytes.addAll(
      _amountRow(
        generator,
        sale.cashWasShort ? 'Still owed' : 'Change due',
        sale.changeDueAbs!.format(currency: currency),
      ),
    );
  }
  if (!sale.isRefund) {
    bytes.addAll(
      generator.text(
        'Sale type: ${sale.saleType[0].toUpperCase()}${sale.saleType.substring(1)}',
      ),
    );
    bytes.addAll(generator.text('Status: ${sale.status.toUpperCase()}'));
    if (data.refundedTotal.cents > 0) {
      bytes.addAll(generator.text('Refunded: ${data.refundedTotal.format(currency: currency)}'));
    }
  }
  bytes.addAll(generator.hr());
  bytes.addAll(
    generator.text(
      'Thank you for shopping with us!',
      styles: const PosStyles(align: PosAlign.center),
    ),
  );
  bytes.addAll(
    generator.text(
      supportFooter,
      styles: const PosStyles(align: PosAlign.center),
    ),
  );

  if ((data.settings.receiptFooter ?? '').isNotEmpty) {
    bytes.addAll(generator.feed(1));
    bytes.addAll(
      generator.text(
        data.settings.receiptFooter!,
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
  }

  bytes.addAll(generator.feed(1));
  bytes.addAll(generator.imageRaster(receiptBarcode(sale.saleNumber)));
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
  bytes.addAll(
    generator.text(
      'NexaPOS',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ),
  );
  bytes.addAll(
    generator.text(
      'Test print',
      styles: const PosStyles(align: PosAlign.center),
    ),
  );
  bytes.addAll(generator.hr());
  bytes.addAll(
    generator.text(
      'If you can read this, the printer\nis connected and set up correctly.',
    ),
  );
  bytes.addAll(generator.feed(2));
  bytes.addAll(generator.cut());
  return Uint8List.fromList(bytes);
}

List<int> _amountRow(
  Generator generator,
  String label,
  String value, {
  bool bold = false,
  bool doubleSize = false,
}) {
  final styles = PosStyles(
    bold: bold,
    height: doubleSize ? PosTextSize.size2 : PosTextSize.size1,
    width: doubleSize ? PosTextSize.size2 : PosTextSize.size1,
  );
  return generator.row([
    PosColumn(text: label, width: 7, styles: styles),
    PosColumn(
      text: value,
      width: 5,
      styles: styles.copyWith(align: PosAlign.right),
    ),
  ]);
}
