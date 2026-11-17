import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;

import '../../core/is_web.dart';
import '../../data/printing/receipt_branding.dart';
import '../../core/utils/money.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'browser_print.dart';
import '../../data/printing/thermal_printer_service.dart';
import '../../data/repositories/payment_record_repository_impl.dart';
import '../../data/repositories/sale_item_repository_impl.dart';
import '../../data/repositories/sale_repository_impl.dart';
import '../../data/repositories/business_settings_repository_impl.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/entities/business_settings.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/services/refund_service.dart' show refundRoles;
import '../../domain/services/session_service.dart';

part 'receipt_screen.g.dart';

class ReceiptData {
  final Sale sale;
  final List<SaleItem> items;
  final BusinessSettings settings;
  /// Whoever rang the sale up - or, on a refund, whoever gave the money back.
  final String cashierName;

  /// On a refund: the number of the sale it gives back (null when that sale has not reached this device).
  final String? originalSaleNumber;

  /// On an ordinary sale: how much of it has been refunded so far (a positive amount, zero when none).
  final Money refundedTotal;

  /// On an M-Pesa (Manual) sale - paid to the shop's own till or paybill - the customer's M-Pesa code, printed as
  /// "Reference" (null otherwise).
  final String? mpesaReference;

  const ReceiptData({
    required this.sale,
    required this.items,
    required this.settings,
    required this.cashierName,
    this.originalSaleNumber,
    this.refundedTotal = const Money.zero(),
    this.mpesaReference,
  });

  bool get isRefund => sale.isRefund;

  /// 'Cashier' on a sale, 'Refunded by' on a refund.
  String get personLabel => isRefund ? 'Refunded by' : 'Cashier';

  /// 'Payment' on a sale, 'Paid back via' on a refund.
  String get paymentLabel => isRefund ? 'Paid back via' : 'Payment';

  /// A refund of a split cash + M-Pesa sale: how much of it goes back as cash and how much as M-Pesa (positive).
  ({Money cash, Money mpesa})? get refundSplit {
    final cash = sale.cashReceived;
    if (!isRefund || sale.paymentMethod != 'paystack' || cash == null) return null;
    return (cash: Money(-cash.cents), mpesa: Money(-(sale.total.cents - cash.cents)));
  }
}

@riverpod
Future<ReceiptData> receiptData(Ref ref, String saleId) async {
  final sale = await ref.watch(saleRepositoryProvider).findById(saleId);
  if (sale == null) throw StateError('Sale not found.');
  final items = await ref.watch(saleItemRepositoryProvider).forSale(saleId);
  final settings = await ref.watch(businessSettingsRepositoryProvider).get();
  final cashier = await ref.watch(userRepositoryProvider).findById(sale.userId);
  String? originalNumber;
  var refunded = const Money.zero();
  if (sale.isRefund) {
    final of = sale.refundOfSaleId;
    if (of != null) originalNumber = (await ref.watch(saleRepositoryProvider).findById(of))?.saleNumber;
  } else if (sale.isPaid) {
    final refunds = await ref.watch(saleRepositoryProvider).refundsOf(saleId);
    refunded = Money(refunds.fold<int>(0, (sum, r) => sum - r.total.cents));
  }
  String? reference;
  if (!sale.isRefund && sale.paymentMethod == 'mpesa_manual') {
    final note = (await ref.watch(paymentRecordRepositoryProvider).forSale(saleId))?.referenceNote?.trim();
    if (note != null && note.isNotEmpty) reference = note;
  }
  return ReceiptData(
    sale: sale,
    items: items,
    settings: settings,
    cashierName: cashier?.name ?? 'Unknown',
    originalSaleNumber: originalNumber,
    refundedTotal: refunded,
    mpesaReference: reference,
  );
}

class ReceiptScreen extends ConsumerStatefulWidget {
  final String saleId;
  final String returnPath;

  const ReceiptScreen({super.key, required this.saleId, this.returnPath = '/'});

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  bool _thermalPrinting = false;

  /// An administrator or a manager can refund a paid sale that still has something left to give back.
  bool _canRefund(ReceiptData data) {
    final user = ref.watch(sessionProvider);
    if (user == null || !refundRoles.contains(user.role)) return false;
    final sale = data.sale;
    return sale.isPaid && !sale.isRefund && data.refundedTotal < sale.total;
  }

  Future<void> _printThermal(ReceiptData data) async {
    setState(() => _thermalPrinting = true);
    try {
      await ref.read(thermalPrinterServiceProvider).printReceipt(data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _thermalPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(receiptDataProvider(widget.saleId));

    // Deterministic back-navigation regardless of whatever's actually
    // sitting beneath this screen on the stack, rather than trusting
    // that go('/') + push('/receipt/...') always leaves a clean
    // ['/', receipt] stack for a plain pop to unwind correctly.
    // Concretely: the Paystack path backgrounds the app to an external
    // browser for checkout and resumes it afterward, a real edge case
    // for how the OS/engine can restore navigation state - forcing back
    // to '/' here means it doesn't matter what (if anything) got left
    // behind. Same PopScope pattern PaystackWaitingScreen already uses.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(widget.returnPath);
      },
      child: Scaffold(
        // The back arrow and the Dashboard button are always there: a receipt reached with go() (the refund screen
        // does that) has nothing underneath it, so the automatic back arrow would not be drawn and the only way out
        // would have been "New Sale".
        appBar: AppBar(
          leading: BackButton(
            key: const Key('receipt-back'),
            onPressed: () => context.go(widget.returnPath),
          ),
          title: const Text('Receipt'),
          actions: [
            IconButton(
              key: const Key('receipt-dashboard'),
              icon: const Icon(Icons.home),
              tooltip: 'Dashboard (Alt+Home)',
              onPressed: () => context.go('/'),
            ),
          ],
        ),
        body: dataAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Failed to load receipt: $error')),
          data: (data) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _ReceiptBody(data: data),
                  ),
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: dataAsync.maybeWhen(
          data: (data) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_canRefund(data))
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: const Key('receipt-refund-button'),
                        onPressed: () => context.push('/refund/${data.sale.id}'),
                        icon: const Icon(Icons.undo),
                        label: const Text('Refund'),
                      ),
                    ),
                  Row(
                children: [
                  Expanded(
                    // A browser tab can't open the raw TCP socket a
                    // network thermal printer needs - offering that
                    // button on web would only ever fail. The plan's
                    // own design for web is the browser's own print
                    // dialog instead, printing whatever's currently
                    // on screen (the receipt card above) rather than
                    // a second ESC/POS-formatted path.
                    child: isWeb
                        ? OutlinedButton.icon(
                            onPressed: printCurrentPage,
                            icon: const Icon(Icons.print_outlined),
                            label: const Text('Print'),
                          )
                        : OutlinedButton.icon(
                            onPressed: _thermalPrinting
                                ? null
                                : () => _printThermal(data),
                            icon: _thermalPrinting
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.receipt_long_outlined),
                            label: const Text('Print to thermal printer'),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Tooltip(
                      message: 'New sale (F2)',
                      child: FilledButton.icon(
                        onPressed: () {
                          // Same reasoning as the checkout success handlers:
                          // collapse to the dashboard first so New Sale
                          // isn't left as the only thing on the stack.
                          context.go('/');
                          context.push('/new-sale');
                        },
                        icon: const Icon(Icons.point_of_sale),
                        label: const Text('New Sale'),
                      ),
                    ),
                  ),
                ],
              ),
                ],
              ),
            ),
          ),
          orElse: () => null,
        ),
      ),
    );
  }
}

class _ReceiptBody extends StatelessWidget {
  final ReceiptData data;

  const _ReceiptBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final mono = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(fontFamily: 'monospace');
    final sale = data.sale;
    return DefaultTextStyle(
      style: mono ?? const TextStyle(fontFamily: 'monospace'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            data.settings.businessName.toUpperCase(),
            key: const Key('receipt-business-name'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const Text(
            'Powered by NEXAPOS',
            key: Key('receipt-powered-by'),
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'monospace', fontSize: 14),
          ),
          if (sale.isRefund)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'REFUND',
                key: Key('receipt-refund-title'),
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 22),
              ),
            ),
          if ((data.settings.address ?? '').isNotEmpty)
            Text(data.settings.address!, textAlign: TextAlign.center),
          if ((data.settings.phone ?? '').isNotEmpty)
            Text(data.settings.phone!, textAlign: TextAlign.center),
          const _SolidDivider(),
          const SizedBox(height: 12),
          Text('Receipt #: ${sale.saleNumber}'),
          Text(
            'Date: ${DateFormat('d MMM yyyy HH:mm').format(sale.createdAt.toLocal())}',
          ),
          if (sale.isRefund) ...[
            if (data.originalSaleNumber != null) Text('Refund of: ${data.originalSaleNumber}'),
            if ((sale.refundReason ?? '').isNotEmpty) Text('Reason: ${sale.refundReason}'),
          ],
          Text('${data.personLabel}: ${data.cashierName}'),
          const _SolidDivider(),
          for (final item in data.items) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${item.itemName}      ${item.quantity} x ${item.unitPrice.format(currency: data.settings.currency)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(item.lineTotal.format(currency: data.settings.currency)),
              ],
            ),
          ],
          const _DashedDivider(),
          _AmountRow(
            'Subtotal',
            sale.subtotal.format(currency: data.settings.currency),
          ),
          _AmountRow(
            'Discount',
            sale.discount.format(currency: data.settings.currency),
          ),
          _AmountRow(
            'Total',
            sale.total.format(currency: data.settings.currency),
            bold: true,
            prominent: true,
          ),
          const _SolidDivider(),
          Text('${data.paymentLabel}: ${sale.paymentMethodLabel}'),
          if (data.mpesaReference case final reference?) Text('Reference: $reference'),
          if (sale.isRefund) ...[
            if (data.refundSplit case final split?) ...[
              _AmountRow('Cash back', split.cash.format(currency: data.settings.currency)),
              _AmountRow('M-Pesa back', split.mpesa.format(currency: data.settings.currency)),
            ],
          ] else if (sale.isSplitPayment) ...[
            _AmountRow(
              'Cash received',
              sale.cashReceived!.format(currency: data.settings.currency),
            ),
            _AmountRow(
              'Paid via M-Pesa',
              sale.gatewayPortion.format(currency: data.settings.currency),
            ),
          ] else if (sale.cashReceived != null) ...[
            _AmountRow(
              'Cash received',
              sale.cashReceived!.format(currency: data.settings.currency),
            ),
            _AmountRow(
              sale.cashWasShort ? 'Still owed' : 'Change due',
              sale.changeDueAbs!.format(currency: data.settings.currency),
            ),
          ],
          if (!sale.isRefund) ...[
            Text(
              'Sale type: ${sale.saleType[0].toUpperCase()}${sale.saleType.substring(1)}',
            ),
            Text('Status: ${sale.status.toUpperCase()}'),
            if (data.refundedTotal.cents > 0)
              Text(
                'Refunded: ${data.refundedTotal.format(currency: data.settings.currency)}',
                key: const Key('receipt-refunded-total'),
              ),
          ],
          const SizedBox(height: 12),
          const _SolidDivider(),
          const Text(
            'Thank you for shopping with us!',
            textAlign: TextAlign.center,
          ),
          const Text(supportFooter, textAlign: TextAlign.center),
          if ((data.settings.receiptFooter ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              data.settings.receiptFooter!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 12),
          Image.memory(
            img.encodePng(receiptBarcode(sale.saleNumber)),
            semanticLabel:
                'Receipt barcode ${receiptBarcodeValue(sale.saleNumber)}',
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool prominent;

  const _AmountRow(
    this.label,
    this.value, {
    this.bold = false,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = bold || prominent
        ? const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)
        : null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          prominent ? label.toUpperCase() : label,
          style: prominent ? style?.copyWith(fontSize: 20) : style,
        ),
        Text(value, style: prominent ? style?.copyWith(fontSize: 20) : style),
      ],
    );
  }
}

class _SolidDivider extends StatelessWidget {
  const _SolidDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, thickness: 1.4, color: Colors.black87),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        '-' * 40,
        style: const TextStyle(fontFamily: 'monospace'),
        maxLines: 1,
        overflow: TextOverflow.clip,
      ),
    );
  }
}
