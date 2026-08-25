import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product.dart';
import '../../domain/services/session_service.dart';
import '../../domain/services/stock_service.dart';

/// Port of PHP's "Adjust Stock" form: a free-form signed delta, always
/// logged as movement_type 'adjustment' (as opposed to the 'sale'/
/// 'purchase'/'return' types written by other flows).
class StockAdjustmentSheet extends ConsumerStatefulWidget {
  final Product product;

  const StockAdjustmentSheet({super.key, required this.product});

  @override
  ConsumerState<StockAdjustmentSheet> createState() => _StockAdjustmentSheetState();
}

class _StockAdjustmentSheetState extends ConsumerState<StockAdjustmentSheet> {
  final _deltaController = TextEditingController();
  final _noteController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _deltaController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final delta = int.tryParse(_deltaController.text.trim());
    if (delta == null || delta == 0) {
      setState(() => _error = 'Enter a nonzero whole number (use a minus sign to reduce stock).');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final userId = ref.read(sessionProvider)?.id;
    final result = await ref.read(stockServiceProvider).applyMovement(
          productId: widget.product.id,
          movementType: 'adjustment',
          delta: delta,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          userId: userId,
        );

    result.when(
      ok: (_) {
        if (mounted) Navigator.of(context).pop();
      },
      failure: (message) => setState(() {
        _submitting = false;
        _error = message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Adjust stock: ${widget.product.name}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Currently ${widget.product.stockQty} in stock'),
          const SizedBox(height: 16),
          TextField(
            controller: _deltaController,
            decoration: const InputDecoration(
              labelText: 'Change in quantity',
              helperText: 'Positive to add stock, negative to remove (e.g. -3)',
            ),
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Apply adjustment'),
          ),
        ],
      ),
    );
  }
}
