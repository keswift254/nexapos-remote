import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/domain/entities/sale.dart';
import 'package:nexapos_mobile/domain/services/intasend_payment_service.dart';
import 'package:nexapos_mobile/domain/services/paystack_payment_service.dart';
import 'package:nexapos_mobile/domain/services/pending_sales_notifier.dart';

class _PaystackReport implements PaystackPaymentService {
  _PaystackReport(this.report);

  final PaystackReconcileReport report;

  @override
  Future<PaystackReconcileReport> reconcileAndReport() async => report;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _IntaSendPending implements IntaSendPaymentService {
  _IntaSendPending(this.stillPending);

  final List<Sale> stillPending;

  @override
  Future<List<Sale>> reconcilePendingSales() async => stillPending;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Sale _sale(String id, String method, String status) => Sale(
  id: id,
  saleNumber: 'S-$id',
  userId: 'cashier-1',
  customerName: 'Walk-in',
  saleType: 'retail',
  paymentMethod: method,
  subtotal: const Money(10000),
  discount: const Money.zero(),
  total: const Money(10000),
  status: status,
  createdAt: DateTime(2026, 11, 3, 12),
);

void main() {
  ProviderContainer containerWith(
    PaystackReconcileReport paystack,
    List<Sale> intaSendPending,
  ) {
    final container = ProviderContainer(
      overrides: [
        paystackPaymentServiceProvider.overrideWithValue(_PaystackReport(paystack)),
        intaSendPaymentServiceProvider.overrideWithValue(_IntaSendPending(intaSendPending)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a payment found paid is announced, and what is still unpaid stays on the pending list', () async {
    final container = containerWith(
      (
        stillPending: [_sale('1', 'paystack', 'pending')],
        nowPaid: [_sale('2', 'paystack', 'paid')],
      ),
      [_sale('3', 'intasend', 'pending')],
    );

    await container.read(pendingPaystackSalesProvider.notifier).reconcile();

    expect(
      container.read(pendingPaystackSalesProvider).map((sale) => sale.id),
      ['1', '3'],
    );
    expect(
      container.read(confirmedOnlineSalesProvider).map((sale) => sale.id),
      ['2'],
    );
  });

  test('asking again does not announce the same payment twice', () async {
    final container = containerWith(
      (stillPending: const [], nowPaid: [_sale('2', 'paystack', 'paid')]),
      const [],
    );
    final notifier = container.read(pendingPaystackSalesProvider.notifier);

    await notifier.reconcile();
    await notifier.reconcile();

    expect(container.read(confirmedOnlineSalesProvider), hasLength(1));
  });

  test('nothing is announced when nothing was found paid', () async {
    final container = containerWith(
      (stillPending: [_sale('1', 'paystack', 'pending')], nowPaid: const []),
      const [],
    );

    await container.read(pendingPaystackSalesProvider.notifier).reconcile();

    expect(container.read(confirmedOnlineSalesProvider), isEmpty);
  });
}
