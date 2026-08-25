import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/expenses_table.dart';

part 'expenses_dao.g.dart';

@DriftAccessor(tables: [Expenses])
class ExpensesDao extends DatabaseAccessor<AppDatabase> with _$ExpensesDaoMixin {
  ExpensesDao(super.db);

  Future<List<Expense>> forDate(String isoDate) {
    return (select(expenses)
          ..where((e) => e.expenseDate.equals(isoDate) & e.deletedAt.isNull())
          ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]))
        .get();
  }

  Future<void> insertExpense(ExpensesCompanion companion) {
    return into(expenses).insert(companion);
  }

  /// Guards on deletedAt.isNull() so double-deleting an already-gone
  /// row reports 0 rows affected rather than clobbering the original
  /// deletedAt with a newer timestamp.
  Future<int> softDelete(String id, String deletedAt, int localRev) {
    return (update(expenses)..where((e) => e.id.equals(id) & e.deletedAt.isNull())).write(
      ExpensesCompanion(
        deletedAt: Value(deletedAt),
        updatedAt: Value(deletedAt),
        localRev: Value(localRev),
      ),
    );
  }
}
