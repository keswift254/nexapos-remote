import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../core/result.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/money.dart';
import '../../data/repositories/expense_repository_impl.dart';
import '../entities/expense.dart';
import '../repositories/expense_repository.dart';

part 'expense_service.g.dart';

@Riverpod(keepAlive: true)
ExpenseService expenseService(Ref ref) {
  return ExpenseService(
    ref.watch(expenseRepositoryProvider),
    ref.watch(idGeneratorProvider),
    ref.watch(clockProvider),
  );
}

/// Port of PHP's save_expense/delete_expense (page=expenses): a
/// single-day list, add, and delete - no edit exists in the PHP
/// reference either, so none is added here.
class ExpenseService {
  final ExpenseRepository _repository;
  final IdGenerator _idGenerator;
  final Clock _clock;

  ExpenseService(this._repository, this._idGenerator, this._clock);

  Future<List<Expense>> forDate(DateTime date) => _repository.forDate(date);

  Future<Result<Expense>> create({
    required DateTime expenseDate,
    required String title,
    required Money amount,
    String? note,
    String? userId,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return const Result.failure('Enter the expense name.');
    if (amount.cents <= 0) return const Result.failure('Enter an expense amount greater than zero.');

    final trimmedNote = note?.trim();
    final expense = Expense(
      id: _idGenerator.newId(),
      userId: userId,
      expenseDate: expenseDate,
      title: trimmedTitle,
      amount: amount,
      note: (trimmedNote == null || trimmedNote.isEmpty) ? null : trimmedNote,
      createdAt: _clock.now(),
    );
    final id = await _repository.create(expense);
    return Result.ok(expense.copyWith(id: id));
  }

  Future<Result<void>> delete(String id) async {
    final deleted = await _repository.delete(id);
    return deleted
        ? const Result.ok(null)
        : const Result.failure('Expense was not found.');
  }
}
