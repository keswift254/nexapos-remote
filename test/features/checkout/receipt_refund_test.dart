import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/domain/entities/business_settings.dart';
import 'package:nexapos_mobile/domain/entities/sale.dart';
import 'package:nexapos_mobile/domain/entities/sale_item.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/features/checkout/receipt_screen.dart';

class _Session extends SessionNotifier {
  static User? who;
  @override
  User? build() => who;
}

User _user(UserRole role) => User(
      id: 'u-${role.name}',
      role: role,
      name: role.name,
      username: role.name,
      passwordHash: 'x',
      status: 'active',
    );

const _settings = BusinessSettings(businessName: 'Mama Mboga', currency: 'KES', paperWidthMm: 58);

Sale _sale({
  String type = 'retail',
  String method = 'cash',
  String status = 'paid',
  int subtotal = 30000,
  int discount = 0,
  int? cash,
  String? refundOf,
  String? reason,
}) =>
    Sale(
      id: 'sale-1',
      saleNumber: type == 'refund' ? 'RFND-1' : 'SALE-1',
      userId: 'u-1',
      customerName: 'Mama Njeri',
      saleType: type,
      paymentMethod: method,
      subtotal: Money(subtotal),
      discount: Money(discount),
      total: Money(subtotal - discount),
      status: status,
      createdAt: DateTime(2026, 11, 16, 10, 30),
      cashReceived: cash == null ? null : Money(cash),
      refundOfSaleId: refundOf,
      refundReason: reason,
    );

SaleItem _item(int qty, {int price = 10000}) => SaleItem(
      id: 'i-1',
      saleId: 'sale-1',
      productId: 'p-1',
      itemName: 'Widget',
      quantity: qty,
      unitPrice: Money(price),
      costPrice: const Money(6000),
      lineTotal: Money(qty * price),
    );

Future<void> _show(WidgetTester tester, ReceiptData data, {UserRole? as}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  _Session.who = as == null ? null : _user(as);
  await tester.pumpWidget(const SizedBox()); // a fresh tree each time: the session is read once per scope
  String? pushed;
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => ReceiptScreen(saleId: data.sale.id)),
      GoRoute(
        path: '/refund/:saleId',
        builder: (context, state) {
          pushed = state.pathParameters['saleId'];
          return Scaffold(body: Text('REFUND PAGE ${pushed ?? ''}'));
        },
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        receiptDataProvider(data.sale.id).overrideWith((ref) async => data),
        sessionProvider.overrideWith(_Session.new),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the receipt of a refund', () {
    ReceiptData refundData({int? cash, String method = 'cash'}) => ReceiptData(
          sale: _sale(type: 'refund', method: method, subtotal: -20000, discount: -2000, cash: cash, refundOf: 'orig', reason: 'Wrong goods'),
          items: [_item(-2)],
          settings: _settings,
          cashierName: 'Otieno',
          originalSaleNumber: 'SALE-1',
        );

    testWidgets('says REFUND, what it refunds and why, who gave the money back, and shows the amounts as negative', (tester) async {
      await _show(tester, refundData());
      expect(find.byKey(const Key('receipt-refund-title')), findsOneWidget);
      expect(find.text('REFUND'), findsOneWidget);
      expect(find.text('Refund of: SALE-1'), findsOneWidget);
      expect(find.text('Reason: Wrong goods'), findsOneWidget);
      expect(find.text('Refunded by: Otieno'), findsOneWidget);
      expect(find.text('Cashier: Otieno'), findsNothing);
      expect(find.text('Paid back via: Cash'), findsOneWidget);
      expect(find.textContaining('-2 x KES 100.00'), findsOneWidget);
      expect(find.text('-KES 200.00'), findsWidgets);
      expect(find.text('-KES 180.00'), findsOneWidget, reason: 'the total, after the discount share');
    });

    testWidgets('has none of the lines that only make sense for a sale: status, sale type, cash received, change', (tester) async {
      await _show(tester, refundData());
      expect(find.textContaining('Status:'), findsNothing);
      expect(find.textContaining('Sale type:'), findsNothing);
      expect(find.textContaining('Cash received'), findsNothing);
      expect(find.textContaining('Change due'), findsNothing);
      expect(find.byKey(const Key('receipt-refund-button')), findsNothing, reason: 'a refund cannot be refunded');
    });

    testWidgets('a refund of a split sale says how much went back in cash and how much by M-Pesa', (tester) async {
      await _show(tester, refundData(method: 'paystack', cash: -5000));
      expect(find.text('Cash back'), findsOneWidget);
      expect(find.text('M-Pesa back'), findsOneWidget);
      expect(find.text('KES 50.00'), findsOneWidget);
      expect(find.text('KES 130.00'), findsOneWidget);
    });

    testWidgets('an M-Pesa refund says it was paid back via M-Pesa', (tester) async {
      await _show(tester, refundData(method: 'mpesa_manual'));
      expect(find.text('Paid back via: M-Pesa (Manual)'), findsOneWidget);
    });
  });

  group('the receipt of a sale that has been refunded', () {
    ReceiptData saleData({int refunded = 0, String status = 'paid'}) => ReceiptData(
          sale: _sale(status: status),
          items: [_item(3)],
          settings: _settings,
          cashierName: 'Wanjiru',
          refundedTotal: Money(refunded),
        );

    testWidgets('an ordinary sale looks as it always did', (tester) async {
      await _show(tester, saleData());
      expect(find.text('Cashier: Wanjiru'), findsOneWidget);
      expect(find.text('Status: PAID'), findsOneWidget);
      expect(find.text('Sale type: Retail'), findsOneWidget);
      expect(find.text('Payment: Cash'), findsOneWidget);
      expect(find.text('REFUND'), findsNothing);
      expect(find.byKey(const Key('receipt-refunded-total')), findsNothing);
    });

    testWidgets('shows how much has been given back', (tester) async {
      await _show(tester, saleData(refunded: 10000));
      expect(find.text('Refunded: KES 100.00'), findsOneWidget);
      expect(find.text('Status: PAID'), findsOneWidget);
    });

    testWidgets('a manager and an administrator get a Refund button; a cashier does not; nobody logged in does not', (tester) async {
      await _show(tester, saleData(), as: UserRole.manager);
      expect(find.byKey(const Key('receipt-refund-button')), findsOneWidget);
      await _show(tester, saleData(), as: UserRole.admin);
      expect(find.byKey(const Key('receipt-refund-button')), findsOneWidget);
      await _show(tester, saleData(), as: UserRole.cashier);
      expect(find.byKey(const Key('receipt-refund-button')), findsNothing);
      await _show(tester, saleData());
      expect(find.byKey(const Key('receipt-refund-button')), findsNothing);
    });

    testWidgets('the button opens the refund screen for that sale', (tester) async {
      await _show(tester, saleData(), as: UserRole.manager);
      await tester.tap(find.byKey(const Key('receipt-refund-button')));
      await tester.pumpAndSettle();
      expect(find.text('REFUND PAGE sale-1'), findsOneWidget);
    });

    testWidgets('no button once the whole sale has been refunded, nor for a sale that was never paid', (tester) async {
      await _show(tester, saleData(refunded: 30000), as: UserRole.manager);
      expect(find.byKey(const Key('receipt-refund-button')), findsNothing);
      await _show(tester, saleData(status: 'pending'), as: UserRole.manager);
      expect(find.byKey(const Key('receipt-refund-button')), findsNothing);
      await _show(tester, saleData(status: 'cancelled'), as: UserRole.manager);
      expect(find.byKey(const Key('receipt-refund-button')), findsNothing);
    });

    testWidgets('the print and new sale buttons are still there beside it', (tester) async {
      await _show(tester, saleData(), as: UserRole.manager);
      expect(find.widgetWithText(FilledButton, 'New Sale'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Print to thermal printer'), findsOneWidget);
    });
  });
}
