import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/daos/reports_dao.dart';
import 'package:nexapos_mobile/data/printing/thermal_report_builder.dart';
import 'package:nexapos_mobile/domain/entities/business_settings.dart';
import 'package:nexapos_mobile/domain/services/reports_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wraps text within 58mm and 80mm widths', () {
    for (final columns in [32, 48]) {
      final lines = wrapThermalLine(
        'Extra long product name that should not be cut at the paper edge',
        columns,
      );
      expect(lines.length, greaterThan(1));
      expect(lines.every((line) => line.length <= columns), isTrue);
    }
  });

  for (final width in [58, 80]) {
    test(
      'prints the full daily report directly as ESC/POS at ${width}mm',
      () async {
        final data = ReportData(
          sales: const [
            ReportSaleRow(
              id: 'sale-1',
              saleNumber: 'S-1',
              cashierName: 'Cashier',
              saleType: 'retail',
              paymentMethod: 'cash',
              status: 'paid',
              totalCents: 701500,
              createdAt: '2026-10-23T10:30:00.000',
              itemNames: 'A very long product name that must wrap instead of being cut x1',
              cashReceivedCents: null,
            ),
          ],
          expenses: const [],
          salesTotal: Money(701500),
          expensesTotal: Money(195000),
          grossProfitTotal: Money(652500),
          netProfit: Money(457500),
          grandTotal: Money(506500),
          transactionCount: 1,
          cashReceivedTotal: Money(701500),
          mpesaTotal: Money(0),
        );
        final bytes = await buildThermalReport(
          data: data,
          reportTitle: 'Daily Sales Report',
          periodLabel: '23 OCTOBER 2026',
          isMonthlyReport: false,
          timeFormat: DateFormat('HH:mm'),
          settings: BusinessSettings(
            businessName: 'REDKEM SHOP',
            currency: 'KES',
            paperWidthMm: width,
          ),
          generatedByName: 'Admin',
        );
        final printed = latin1.decode(bytes, allowInvalid: true);
        expect(printed, contains('DAILY SALES REPORT'));
        expect(printed, contains('Total Paid Sales'));
        expect(printed, contains('Total Expenses'));
        expect(printed, contains('GRAND TOTAL'));
        expect(printed, contains('A very long product name'));
        expect(bytes, isNotEmpty);
      },
    );
  }
}
