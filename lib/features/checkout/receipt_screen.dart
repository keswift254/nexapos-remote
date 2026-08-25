import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/printing/thermal_printer_service.dart';
import '../../data/repositories/sale_item_repository_impl.dart';
import '../../data/repositories/sale_repository_impl.dart';
import '../../data/repositories/business_settings_repository_impl.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/entities/business_settings.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import 'receipt_pdf.dart';

part 'receipt_screen.g.dart';

class ReceiptData {
  final Sale sale;
  final List<SaleItem> items;
  final BusinessSettings settings;
  final String cashierName;

  const ReceiptData({required this.sale, required this.items, required this.settings, required this.cashierName});
}

@riverpod
Future<ReceiptData> receiptData(Ref ref, String saleId) async {
  final sale = await ref.watch(saleRepositoryProvider).findById(saleId);
  if (sale == null) throw StateError('Sale not found.');
  final items = await ref.watch(saleItemRepositoryProvider).forSale(saleId);
  final settings = await ref.watch(businessSettingsRepositoryProvider).get();
  final cashier = await ref.watch(userRepositoryProvider).findById(sale.userId);
  return ReceiptData(sale: sale, items: items, settings: settings, cashierName: cashier?.name ?? 'Unknown');
}

/// Shown after a sale completes, from every payment method alike (cash/
/// mpesa/mpesa_manual land here straight from CheckoutService.checkout,
/// paystack lands here once PaystackPaymentService.poll confirms
/// payment) - one shared destination so "what happens after a sale" is
/// consistent regardless of how it was paid for. "New Sale" is the way
/// back into another sale, matching the paper-receipt mockup this was
/// ported from.
/// The OS print dialog (used by "Print Receipt") only offers to save as
/// PDF if a virtual PDF printer happens to be installed on this machine
/// - not guaranteed, and not obvious to look for even when it is. This
/// writes the PDF directly to a location the user picks, independent of
/// whatever printers are configured.
Future<void> _savePdf(BuildContext context, ReceiptData data) async {
  final bytes = await buildReceiptPdf(data, PdfPageFormat.a4);
  final uri = await FilePicker.saveFile(
    fileName: '${data.sale.saleNumber}.pdf',
    bytes: bytes,
    mimeType: 'application/pdf',
  );
  if (!context.mounted || uri == null) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to ${uri.toFilePath()}')));
}

class ReceiptScreen extends ConsumerStatefulWidget {
  final String saleId;

  const ReceiptScreen({super.key, required this.saleId});

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  bool _thermalPrinting = false;

  Future<void> _printThermal(ReceiptData data) async {
    setState(() => _thermalPrinting = true);
    try {
      await ref.read(thermalPrinterServiceProvider).printReceipt(data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
        context.go('/');
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Receipt')),
        body: dataAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load receipt: $error')),
          data: (data) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Card(
                  child: Padding(padding: const EdgeInsets.all(20), child: _ReceiptBody(data: data)),
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
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _thermalPrinting ? null : () => _printThermal(data),
                      icon: _thermalPrinting
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.receipt_long_outlined),
                      label: const Text('Print to thermal printer'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Printing.layoutPdf(onLayout: (format) => buildReceiptPdf(data, format)),
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Print Receipt'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _savePdf(context, data),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Save PDF'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
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
    final mono = Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace');
    final sale = data.sale;
    return DefaultTextStyle(
      style: mono ?? const TextStyle(fontFamily: 'monospace'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            data.settings.businessName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 18),
          ),
          if ((data.settings.address ?? '').isNotEmpty) Text(data.settings.address!, textAlign: TextAlign.center),
          if ((data.settings.phone ?? '').isNotEmpty) Text(data.settings.phone!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text('Receipt: ${sale.saleNumber}'),
          Text('Date: ${DateFormat('d MMM yyyy HH:mm').format(sale.createdAt.toLocal())}'),
          Text('Cashier: ${data.cashierName}'),
          const _DashedDivider(),
          for (final item in data.items) ...[
            Text(item.itemName),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${item.quantity} x ${item.unitPrice.format(currency: data.settings.currency)}'),
                Text(item.lineTotal.format(currency: data.settings.currency)),
              ],
            ),
          ],
          const _DashedDivider(),
          _AmountRow('Subtotal', sale.subtotal.format(currency: data.settings.currency)),
          _AmountRow('Discount', sale.discount.format(currency: data.settings.currency)),
          _AmountRow('Total', sale.total.format(currency: data.settings.currency), bold: true),
          const _DashedDivider(),
          Text('Payment: ${sale.paymentMethod.toUpperCase()}'),
          Text('Sale type: ${sale.saleType[0].toUpperCase()}${sale.saleType.substring(1)}'),
          Text('Status: ${sale.status.toUpperCase()}'),
          if ((data.settings.receiptFooter ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(data.settings.receiptFooter!, textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _AmountRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold ? const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold) : null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(value, style: style)],
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text('-' * 40, style: const TextStyle(fontFamily: 'monospace'), maxLines: 1, overflow: TextOverflow.clip),
    );
  }
}
