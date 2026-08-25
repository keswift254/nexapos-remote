import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';
import '../local/database.dart' hide Expense;
import '../local/database.dart' as drift_db show Expense;
import '../local/daos/expenses_dao.dart';
import '../local/sync_metadata.dart';

part 'expense_repository_impl.g.dart';

final _dateFormat = DateFormat('yyyy-MM-dd');

@Riverpod(keepAlive: true)
ExpenseRepository expenseRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return ExpenseRepositoryImpl(
    db,
    db.expensesDao,
    ref.watch(syncMetadataProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
  );
}

class ExpenseRepositoryImpl implements ExpenseRepository {
  final AppDatabase _db;
  final ExpensesDao _dao;
  final SyncMetadataService _syncMeta;
  final Clock _clock;
  final IdGenerator _idGenerator;

  ExpenseRepositoryImpl(this._db, this._dao, this._syncMeta, this._clock, this._idGenerator);

  Expense _toEntity(drift_db.Expense row) => Expense(
        id: row.id,
        userId: row.userId,
        expenseDate: DateTime.parse(row.expenseDate),
        title: row.title,
        amount: Money(row.amountCents),
        note: row.note,
        createdAt: DateTime.parse(row.createdAt),
      );

  @override
  Future<List<Expense>> forDate(DateTime date) async {
    final rows = await _dao.forDate(_dateFormat.format(date));
    return rows.map(_toEntity).toList();
  }

  @override
  Future<String> create(Expense expense) async {
    final id = expense.id.isEmpty ? _idGenerator.newId() : expense.id;
    await _db.transaction(() async {
      final now = _clock.now().toIso8601String();
      final rev = await _syncMeta.nextLocalRev();
      final deviceId = await _syncMeta.deviceId();
      await _dao.insertExpense(ExpensesCompanion.insert(
        id: id,
        userId: Value(expense.userId),
        expenseDate: _dateFormat.format(expense.expenseDate),
        title: expense.title,
        amountCents: expense.amount.cents,
        note: Value(expense.note),
        createdAt: now,
        updatedAt: now,
        localRev: rev,
        createdByDeviceId: deviceId,
      ));
    });
    return id;
  }

  @override
  Future<bool> delete(String id) async {
    return _db.transaction(() async {
      final now = _clock.now().toIso8601String();
      final rev = await _syncMeta.nextLocalRev();
      final rows = await _dao.softDelete(id, now, rev);
      return rows > 0;
    });
  }
}
