import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/utils/money.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/entities/expense.dart';
import '../../domain/services/expense_service.dart';
import '../../domain/services/session_service.dart';

part 'expenses_screen.g.dart';

@riverpod
Future<List<Expense>> expensesForDate(Ref ref, DateTime date) {
  return ref.watch(expenseServiceProvider).forDate(date);
}

@riverpod
Future<String?> expenseEnteredByName(Ref ref, String? userId) async {
  if (userId == null) return null;
  final user = await ref.watch(userRepositoryProvider).findById(userId);
  return user?.name;
}

/// Port of PHP's Expenses page: a single calendar day's entries with a
/// running total, add, and delete - PHP never supported editing an
/// expense either, so that's not added here.
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  DateTime _selectedDate = DateTime.now();

  DateTime get _dateOnly => DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

  bool get _isToday {
    final now = DateTime.now();
    return _dateOnly == DateTime(now.year, now.month, now.day);
  }

  void _changeDay(int delta) {
    setState(() => _selectedDate = _dateOnly.add(Duration(days: delta)));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOnly,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _addExpense() async {
    final date = _dateOnly;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AddExpenseDialog(date: date),
    );
    if (saved == true) ref.invalidate(expensesForDateProvider(date));
  }

  Future<void> _confirmDelete(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('"${expense.title}" (${expense.amount.format()}) will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(foregroundColor: Theme.of(dialogContext).colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await ref.read(expenseServiceProvider).delete(expense.id);
    if (!mounted) return;
    result.when(
      ok: (_) => ref.invalidate(expensesForDateProvider(_dateOnly)),
      failure: (message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = _dateOnly;
    final expensesAsync = ref.watch(expensesForDateProvider(date));

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeDay(-1)),
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: Center(
                      child: Text(
                        _isToday ? 'Today, ${DateFormat('d MMM yyyy').format(date)}' : DateFormat('EEEE, d MMM yyyy').format(date),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _isToday ? null : () => _changeDay(1),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: expensesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Failed to load expenses: $error')),
              data: (expenses) {
                if (expenses.isEmpty) {
                  return const Center(child: Text('No expenses recorded for this day.'));
                }
                final total = expenses.fold<Money>(const Money.zero(), (sum, e) => sum + e.amount);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total', style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            total.format(),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        itemCount: expenses.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final expense = expenses[index];
                          return _ExpenseTile(expense: expense, onDelete: () => _confirmDelete(expense));
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }
}

class _ExpenseTile extends ConsumerWidget {
  final Expense expense;
  final VoidCallback onDelete;

  const _ExpenseTile({required this.expense, required this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enteredByAsync = ref.watch(expenseEnteredByNameProvider(expense.userId));
    final enteredBy = enteredByAsync.maybeWhen(data: (name) => name, orElse: () => null);
    final note = expense.note;
    final subtitleParts = [
      DateFormat('h:mm a').format(expense.createdAt.toLocal()),
      ?enteredBy,
      if (note != null && note.isNotEmpty) note,
    ];

    return ListTile(
      title: Text(expense.title),
      subtitle: Text(subtitleParts.join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(expense.amount.format(), style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
        ],
      ),
    );
  }
}

class _AddExpenseDialog extends ConsumerStatefulWidget {
  final DateTime date;

  const _AddExpenseDialog({required this.date});

  @override
  ConsumerState<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends ConsumerState<_AddExpenseDialog> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final amount = double.tryParse(_amountController.text.trim());
    final userId = ref.read(sessionProvider)?.id;
    final result = await ref.read(expenseServiceProvider).create(
          expenseDate: widget.date,
          title: _titleController.text,
          amount: amount == null ? const Money.zero() : Money.fromMajor(amount),
          note: _noteController.text,
          userId: userId,
        );

    if (!mounted) return;
    result.when(
      ok: (_) => Navigator.pop(context, true),
      failure: (message) => setState(() {
        _submitting = false;
        _error = message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add expense'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Expense name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
