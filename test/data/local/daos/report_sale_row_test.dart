import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/data/local/daos/reports_dao.dart';

ReportSaleRow _row({
  required String paymentMethod,
  required int totalCents,
  int? cashReceivedCents,
}) {
  return ReportSaleRow(
    id: 'sale-1',
    saleNumber: 'SALE-1',
    cashierName: 'Cashier',
    saleType: 'retail',
    paymentMethod: paymentMethod,
    status: 'paid',
    totalCents: totalCents,
    createdAt: '2026-09-17T00:00:00.000Z',
    itemNames: null,
    cashReceivedCents: cashReceivedCents,
  );
}

void main() {
  group('ReportSaleRow.cashPortionCents / mpesaPortionCents', () {
    test('a plain cash sale counts entirely as cash', () {
      final row = _row(paymentMethod: 'cash', totalCents: 1000);
      expect(row.cashPortionCents, 1000);
      expect(row.mpesaPortionCents, 0);
    });

    test('a plain paystack sale with no cash received counts entirely as M-Pesa', () {
      final row = _row(paymentMethod: 'paystack', totalCents: 1500);
      expect(row.cashPortionCents, 0);
      expect(row.mpesaPortionCents, 1500);
    });

    test('a split cash+paystack sale divides between both totals', () {
      final row = _row(paymentMethod: 'paystack', totalCents: 1000, cashReceivedCents: 400);
      expect(row.cashPortionCents, 400);
      expect(row.mpesaPortionCents, 600);
    });

    test('legacy mpesa/mpesa_manual/intasend sales count fully as M-Pesa', () {
      for (final method in ['mpesa', 'mpesa_manual', 'intasend']) {
        final row = _row(paymentMethod: method, totalCents: 800);
        expect(row.cashPortionCents, 0, reason: method);
        expect(row.mpesaPortionCents, 800, reason: method);
      }
    });
  });
}
