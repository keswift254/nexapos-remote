import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/daos/reports_dao.dart';
import 'package:nexapos_mobile/domain/entities/business_settings.dart';
import 'package:nexapos_mobile/domain/entities/sale.dart';
import 'package:nexapos_mobile/domain/entities/sale_item.dart';
import 'package:nexapos_mobile/domain/services/reports_service.dart';
import 'package:nexapos_mobile/features/checkout/receipt_pdf.dart';
import 'package:nexapos_mobile/features/checkout/receipt_screen.dart';
import 'package:nexapos_mobile/features/reports/report_pdf.dart';
import 'package:pdf/pdf.dart';

void main() {
  test(
    'writes receipt PDF previews when requested',
    () async {
      final outPath = Platform.environment['NEXAPOS_RECEIPT_PREVIEW_DIR']!;
      final outDir = Directory(outPath);
      await outDir.create(recursive: true);

      final settings = BusinessSettings(
        businessName: 'Pentcyber',
        address: null,
        phone: null,
        receiptFooter: null,
        currency: 'KES',
        paperWidthMm: 80,
      );
      final sale = Sale(
        id: 'sale-1',
        saleNumber: '112284-20260907193315-KSRQ',
        userId: 'user-1',
        customerName: '',
        saleType: 'retail',
        paymentMethod: 'cash',
        subtotal: const Money(100),
        discount: const Money(0),
        total: const Money(100),
        status: 'paid',
        createdAt: DateTime(2026, 9, 7, 22, 33),
      );
      final receipt = ReceiptData(
        sale: sale,
        items: const [
          SaleItem(
            id: 'item-1',
            saleId: 'sale-1',
            itemName: 'Test56',
            quantity: 1,
            unitPrice: Money(100),
            costPrice: Money(0),
            lineTotal: Money(100),
          ),
        ],
        settings: settings,
        cashierName: 'Pilot_test',
      );
      await File('${outDir.path}/sale-receipt.pdf')
          .writeAsBytes(await buildReceiptPdf(receipt, PdfPageFormat.roll80));

      final reportData = ReportData(
        sales: const [
          ReportSaleRow(
            id: 'sale-1',
            saleNumber: '112284-20260907180402-DMPY',
            cashierName: 'Pilot_test',
            saleType: 'retail',
            paymentMethod: 'cash',
            status: 'paid',
            totalCents: 100,
            createdAt: '2026-09-07T18:04:00.000',
            itemNames: 'test9 x1',
          ),
          ReportSaleRow(
            id: 'sale-2',
            saleNumber: '112284-20260907182900-MUSC',
            cashierName: 'Pilot_test',
            saleType: 'retail',
            paymentMethod: 'cash',
            status: 'paid',
            totalCents: 2000,
            createdAt: '2026-09-07T18:29:00.000',
            itemNames: 'Music x1',
          ),
        ],
        expenses: const [],
        salesTotal: Money(2100),
        expensesTotal: Money(0),
        grossProfitTotal: Money(2100),
        netProfit: Money(2100),
        grandTotal: Money(2100),
        transactionCount: 2,
      );
      await File('${outDir.path}/daily-sales-report.pdf').writeAsBytes(
        await buildReportPdf(
          data: reportData,
          reportTitle: 'Daily Sales Report',
          periodLabel: '7TH SEPTEMBER',
          isMonthlyReport: false,
          timeFormat: DateFormat('HH:mm'),
          settings: settings,
          generatedByName: 'Pilot_test',
        ),
      );
      await File('${outDir.path}/monthly-sales-report.pdf').writeAsBytes(
        await buildReportPdf(
          data: reportData,
          reportTitle: 'Monthly Sales Report',
          periodLabel: 'SEPTEMBER 2026',
          isMonthlyReport: true,
          timeFormat: DateFormat('d MMM HH:mm'),
          settings: settings,
          generatedByName: 'Pilot_test',
        ),
      );
    },
    skip: Platform.environment['NEXAPOS_RECEIPT_PREVIEW_DIR'] == null
        ? 'Set NEXAPOS_RECEIPT_PREVIEW_DIR to write visual PDF previews.'
        : false,
  );
}
