import '../entities/expense.dart';

abstract class ExpenseRepository {
  /// Matches PHP's expenses page: a single calendar day's entries,
  /// newest first.
  Future<List<Expense>> forDate(DateTime date);

  Future<String> create(Expense expense);

  /// Soft-deletes the row. Returns false if [id] didn't exist (or was
  /// already deleted) - mirrors PHP's `rowCount() > 0` check so the
  /// caller can show "Expense was not found." instead of a false
  /// success message.
  Future<bool> delete(String id);
}
