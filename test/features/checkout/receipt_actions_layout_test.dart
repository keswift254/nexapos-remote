import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/domain/entities/business_settings.dart';
import 'package:nexapos_mobile/domain/entities/sale.dart';
import 'package:nexapos_mobile/features/checkout/receipt_screen.dart';

void main() {
  testWidgets('receipt actions share one row in equal-width halves', (
    tester,
  ) async {
    final data = ReceiptData(
      sale: Sale(
        id: 'sale-1',
        saleNumber: 'R-1',
        userId: 'user-1',
        customerName: '',
        saleType: 'retail',
        paymentMethod: 'cash',
        subtotal: const Money(100),
        discount: const Money.zero(),
        total: const Money(100),
        status: 'paid',
        createdAt: DateTime(2026, 9, 7),
      ),
      items: const [],
      settings: const BusinessSettings(
        businessName: 'Shop',
        currency: 'KES',
        paperWidthMm: 58,
      ),
      cashierName: 'Cashier',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          receiptDataProvider('sale-1').overrideWith((ref) async => data),
        ],
        child: const MaterialApp(home: ReceiptScreen(saleId: 'sale-1')),
      ),
    );
    await tester.pumpAndSettle();

    final printButton = find.widgetWithText(
      OutlinedButton,
      'Print to thermal printer',
    );
    final newSaleButton = find.widgetWithText(FilledButton, 'New Sale');
    final printRect = tester.getRect(printButton);
    final newSaleRect = tester.getRect(newSaleButton);

    expect(printRect.top, newSaleRect.top);
    expect(printRect.width, closeTo(newSaleRect.width, 0.01));
    expect(printRect.right, lessThan(newSaleRect.left));
  });
}
