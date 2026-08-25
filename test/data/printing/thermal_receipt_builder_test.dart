import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/printing/thermal_receipt_builder.dart';
import 'package:nexapos_mobile/domain/entities/business_settings.dart';
import 'package:nexapos_mobile/domain/entities/sale.dart';
import 'package:nexapos_mobile/domain/entities/sale_item.dart';
import 'package:nexapos_mobile/features/checkout/receipt_screen.dart';

/// Can't verify a real thermal printer's physical output without hardware,
/// but the ESC/POS byte stream itself is fully checkable: the plain-text
/// portions (business name, item names, totals) are ASCII-range bytes
/// sitting alongside the binary command bytes, so decoding loosely as
/// Latin-1 and checking for the expected substrings catches the class of
/// bug that matters here - a wrong field reference, a paper-size crash,
/// a value silently dropped - without needing a byte-for-byte ESC/POS
/// protocol decoder.
void main() {
  // CapabilityProfile.load() reads a bundled JSON asset via Flutter's
  // AssetBundle, which needs the test binding initialized - automatic in
  // the real app via runApp(), not automatic in a plain `flutter test`.
  TestWidgetsFlutterBinding.ensureInitialized();

  ReceiptData buildData({required int paperWidthMm}) {
    final settings = BusinessSettings(
      businessName: 'Nax General Store',
      address: '123 Market Street',
      phone: '0700000000',
      receiptFooter: 'Thank you for shopping with us',
      currency: 'KES',
      paperWidthMm: paperWidthMm,
    );
    final sale = Sale(
      id: 'sale-1',
      saleNumber: 'RCPT-0001',
      userId: 'user-1',
      customerName: '',
      saleType: 'retail',
      paymentMethod: 'cash',
      subtotal: const Money(50000),
      discount: const Money(0),
      total: const Money(50000),
      status: 'paid',
      createdAt: DateTime(2026, 8, 23, 10, 30),
    );
    final items = [
      const SaleItem(
        id: 'item-1',
        saleId: 'sale-1',
        itemName: 'Photocopy A4',
        quantity: 2,
        unitPrice: Money(25000),
        costPrice: Money(10000),
        lineTotal: Money(50000),
      ),
    ];
    return ReceiptData(sale: sale, items: items, settings: settings, cashierName: 'Felix');
  }

  group('buildThermalReceipt', () {
    for (final width in [58, 80]) {
      test('produces a ticket containing the sale\'s real content at ${width}mm', () async {
        final bytes = await buildThermalReceipt(buildData(paperWidthMm: width));
        final decoded = latin1.decode(bytes, allowInvalid: true);

        expect(decoded, contains('Nax General Store'));
        expect(decoded, contains('123 Market Street'));
        expect(decoded, contains('RCPT-0001'));
        expect(decoded, contains('Felix'));
        expect(decoded, contains('Photocopy A4'));
        expect(decoded, contains('CASH'));
        expect(decoded, contains('Thank you for shopping with us'));
      });
    }

    test('omits optional fields entirely when they are blank, rather than printing empty lines', () async {
      final data = buildData(paperWidthMm: 58);
      final noExtras = ReceiptData(
        sale: data.sale,
        items: data.items,
        settings: data.settings.copyWith(address: '', phone: '', receiptFooter: ''),
        cashierName: data.cashierName,
      );
      final bytes = await buildThermalReceipt(noExtras);
      final decoded = latin1.decode(bytes, allowInvalid: true);

      expect(decoded, isNot(contains('123 Market Street')));
      expect(decoded, isNot(contains('Thank you for shopping')));
    });
  });

  group('buildTestTicket', () {
    for (final width in [58, 80]) {
      test('produces a readable test page at ${width}mm without needing a real sale', () async {
        final bytes = await buildTestTicket(width);
        final decoded = latin1.decode(bytes, allowInvalid: true);

        expect(decoded, contains('NexaPOS'));
        expect(decoded, contains('Test print'));
      });
    }
  });
}
