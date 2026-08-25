import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/utils/money.dart';

part 'expense.freezed.dart';

@freezed
abstract class Expense with _$Expense {
  const factory Expense({
    required String id,
    String? userId,
    required DateTime expenseDate,
    required String title,
    required Money amount,
    String? note,
    required DateTime createdAt,
  }) = _Expense;
}
