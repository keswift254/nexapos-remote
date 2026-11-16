import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/daos/reports_dao.dart';
import 'package:nexapos_mobile/data/printing/thermal_receipt_builder.dart';
import 'package:nexapos_mobile/data/printing/thermal_report_builder.dart';
import 'package:nexapos_mobile/domain/entities/business_settings.dart';
import 'package:nexapos_mobile/domain/entities/sale.dart';
import 'package:nexapos_mobile/domain/entities/sale_item.dart';
import 'package:nexapos_mobile/domain/services/reports_service.dart';
import 'package:nexapos_mobile/features/checkout/receipt_pdf.dart';
import 'package:nexapos_mobile/features/checkout/receipt_screen.dart';
import 'package:nexapos_mobile/features/reports/report_pdf.dart';
import 'package:pdf/pdf.dart';

/// What a refund looks like on paper: the thermal ticket, the PDF receipt, and the day's report.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const settings = BusinessSettings(
    businessName: 'Nax General Store',
    currency: 'KES',
    paperWidthMm: 58,
  );

  ReceiptData refundData({String method = 'cash', int? cash}) => ReceiptData(
        sale: Sale(
          id: 'refund-1',
          saleNumber: 'RFND-0001',
          userId: 'user-1',
          customerName: '',
          saleType: 'refund',
          paymentMethod: method,
          subtotal: const Money(-20000),
          discount: const Money(-2000),
          total: const Money(-18000),
          status: 'paid',
          createdAt: DateTime(2026, 11, 16, 10, 30),
          cashReceived: cash == null ? null : Money(cash),
          refundOfSaleId: 'sale-1',
          refundReason: 'Wrong goods',
        ),
        items: const [
          SaleItem(
            id: 'item-1',
            saleId: 'refund-1',
            itemName: 'Photocopy A4',
            quantity: -2,
            unitPrice: Money(10000),
            costPrice: Money(6000),
            lineTotal: Money(-20000),
            refundOfItemId: 'orig-1',
          ),
        ],
        settings: settings,
        cashierName: 'Otieno',
        originalSaleNumber: 'SALE-0001',
      );

  ReceiptData saleData({int refunded = 0}) => ReceiptData(
        sale: Sale(
          id: 'sale-1',
          saleNumber: 'SALE-0001',
          userId: 'user-1',
          customerName: '',
          saleType: 'retail',
          paymentMethod: 'cash',
          subtotal: const Money(30000),
          discount: const Money.zero(),
          total: const Money(30000),
          status: 'paid',
          createdAt: DateTime(2026, 11, 16, 9, 0),
        ),
        items: const [
          SaleItem(
            id: 'orig-1',
            saleId: 'sale-1',
            itemName: 'Photocopy A4',
            quantity: 3,
            unitPrice: Money(10000),
            costPrice: Money(6000),
            lineTotal: Money(30000),
          ),
        ],
        settings: settings,
        cashierName: 'Wanjiru',
        refundedTotal: Money(refunded),
      );

  group('the thermal ticket', () {
    test('a refund says REFUND, what it refunds, why and who, with negative amounts, and no sale-only lines', () async {
      final decoded = latin1.decode(await buildThermalReceipt(refundData()), allowInvalid: true);
      expect(decoded, contains('REFUND'));
      expect(decoded, contains('RFND-0001'));
      expect(decoded, contains('Refund of: SALE-0001'));
      expect(decoded, contains('Reason: Wrong goods'));
      expect(decoded, contains('Refunded by: Otieno'));
      expect(decoded, isNot(contains('Cashier:')));
      expect(decoded, contains('Paid back via: Cash'));
      expect(decoded, contains('-KES 200.00'), reason: 'the subtotal');
      expect(decoded, contains('-KES 20.00'), reason: 'the discount share');
      expect(decoded, isNot(contains('Status:')));
      expect(decoded, isNot(contains('Sale type:')));
      expect(decoded, isNot(contains('Change due')));
    });

    test('a refund of a split sale lists cash back and M-Pesa back', () async {
      final decoded = latin1.decode(await buildThermalReceipt(refundData(method: 'paystack', cash: -5000)), allowInvalid: true);
      expect(decoded, contains('Cash back'));
      expect(decoded, contains('M-Pesa back'));
      expect(decoded, contains('KES 50.00'));
      expect(decoded, contains('KES 130.00'));
    });

    test('a sale with refunds says how much went back; one without is unchanged', () async {
      final refunded = latin1.decode(await buildThermalReceipt(saleData(refunded: 10000)), allowInvalid: true);
      expect(refunded, contains('Refunded: KES 100.00'));
      expect(refunded, contains('Status: PAID'));
      final plain = latin1.decode(await buildThermalReceipt(saleData()), allowInvalid: true);
      expect(plain, isNot(contains('Refunded:')));
      expect(plain, isNot(contains('REFUND')));
      expect(plain, contains('Cashier: Wanjiru'));
    });
  });

  group('the PDF receipt', () {
    test('a refund and a refunded sale both produce a document', () async {
      final refund = await buildReceiptPdf(refundData(), PdfPageFormat.roll57);
      final sale = await buildReceiptPdf(saleData(refunded: 10000), PdfPageFormat.roll57);
      expect(refund.length, greaterThan(1000));
      expect(sale.length, greaterThan(1000));
      expect(latin1.decode(refund, allowInvalid: true), startsWith('%PDF'));
    });
  });

  group('the day\'s report on paper', () {
    ReportData report({bool withRefund = true}) => ReportData(
          sales: const [
            ReportSaleRow(
              id: 's1',
              saleNumber: 'SALE-0001',
              cashierName: 'Wanjiru',
              saleType: 'retail',
              paymentMethod: 'cash',
              status: 'paid',
              totalCents: 30000,
              createdAt: '2026-11-16T07:00:00.000Z',
              itemNames: 'Photocopy A4 x3',
              cashReceivedCents: null,
              refundedCents: 18000,
            ),
          ],
          refunds: withRefund
              ? const [
                  ReportRefundRow(
                    id: 'r1',
                    saleNumber: 'RFND-0001',
                    originalSaleNumber: 'SALE-0001',
                    processedByName: 'Otieno',
                    paymentMethod: 'cash',
                    reason: 'Wrong goods',
                    totalCents: 18000,
                    createdAt: '2026-11-16T08:00:00.000Z',
                    itemNames: 'Photocopy A4 x2',
                  ),
                ]
              : const [],
          expenses: const [],
          salesTotal: const Money(30000),
          refundsTotal: Money(withRefund ? 18000 : 0),
          expensesTotal: const Money.zero(),
          grossProfitTotal: const Money(2400),
          netProfit: const Money(2400),
          grandTotal: Money(withRefund ? 12000 : 30000),
          transactionCount: 1,
          cashReceivedTotal: const Money(30000),
          mpesaTotal: const Money.zero(),
        );

    test('the thermal report lists the refunds, their total, and keeps the grand total', () async {
      final bytes = await buildThermalReport(
        data: report(),
        reportTitle: 'Daily Sales Report',
        periodLabel: '16TH NOVEMBER',
        isMonthlyReport: false,
        timeFormat: DateFormat('HH:mm'),
        settings: settings,
        generatedByName: 'Otieno',
      );
      final decoded = latin1.decode(bytes, allowInvalid: true);
      expect(decoded, contains('REFUNDS'));
      expect(decoded, contains('Photocopy A4 x2'));
      expect(decoded, contains('Reason: Wrong goods'));
      expect(decoded, contains('Total Refunds'));
      expect(decoded, contains('-KES 180.00'));
      expect(decoded, contains('GRAND TOTAL'));
      expect(decoded, contains('KES 120.00'));
    });

    test('a report with no refunds has no refunds section', () async {
      final bytes = await buildThermalReport(
        data: report(withRefund: false),
        reportTitle: 'Daily Sales Report',
        periodLabel: '16TH NOVEMBER',
        isMonthlyReport: false,
        timeFormat: DateFormat('HH:mm'),
        settings: settings,
        generatedByName: 'Otieno',
      );
      final decoded = latin1.decode(bytes, allowInvalid: true);
      expect(decoded, isNot(contains('REFUNDS')));
      expect(decoded, isNot(contains('Total Refunds')));
    });

    test('the PDF report builds with and without refunds', () async {
      for (final withRefund in [true, false]) {
        final pdf = await buildReportPdf(
          data: report(withRefund: withRefund),
          reportTitle: 'Daily Sales Report',
          periodLabel: '16TH NOVEMBER',
          isMonthlyReport: false,
          timeFormat: DateFormat('HH:mm'),
          settings: settings,
          generatedByName: 'Otieno',
        );
        expect(pdf.length, greaterThan(1000));
      }
    });

    test('the sale row shows part refunded / refunded', () {
      const part = ReportSaleRow(
        id: 's', saleNumber: 'n', cashierName: 'c', saleType: 'retail', paymentMethod: 'cash', status: 'paid',
        totalCents: 30000, createdAt: 'x', itemNames: null, cashReceivedCents: null, refundedCents: 10000,
      );
      expect(part.statusLabel, 'part refunded');
      expect(ReportSaleRow(id: 's', saleNumber: 'n', cashierName: 'c', saleType: 'retail', paymentMethod: 'cash', status: 'paid', totalCents: 30000, createdAt: 'x', itemNames: null, cashReceivedCents: null, refundedCents: 30000).statusLabel, 'refunded');
      expect(ReportSaleRow(id: 's', saleNumber: 'n', cashierName: 'c', saleType: 'retail', paymentMethod: 'cash', status: 'paid', totalCents: 30000, createdAt: 'x', itemNames: null, cashReceivedCents: null).statusLabel, 'paid');
    });
  });
}
