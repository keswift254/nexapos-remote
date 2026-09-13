import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/sales_table.dart';

part 'sales_dao.g.dart';

@DriftAccessor(tables: [Sales])
class SalesDao extends DatabaseAccessor<AppDatabase> with _$SalesDaoMixin {
  SalesDao(super.db);

  Future<void> insertSale(SalesCompanion companion) {
    return into(sales).insert(companion);
  }

  Future<Sale?> findById(String id) {
    return (select(sales)..where((s) => s.id.equals(id) & s.deletedAt.isNull())).getSingleOrNull();
  }

  /// A sale only ever sits in 'pending' while it's awaiting confirmation
  /// from an online gateway - paystack or intasend, see sales_table.dart's
  /// status doc. Used at app startup to reconcile any left stranded by
  /// the app being killed outright while PaystackWaitingScreen/
  /// IntaSendWaitingScreen was still polling. Despite the name, this
  /// covers both gateways - each PaymentService's own
  /// reconcilePendingSales filters the result to its own paymentMethod.
  Future<List<Sale>> findPendingPaystack() {
    return (select(sales)
          ..where((s) =>
              s.status.equals('pending') &
              (s.paymentMethod.equals('paystack') | s.paymentMethod.equals('intasend')) &
              s.deletedAt.isNull()))
        .get();
  }

  /// The only post-creation write a sale ever gets: a paystack sale
  /// moving pending -> paid or pending -> cancelled. Nothing else about
  /// a sale is ever edited once inserted.
  Future<void> updateStatus(String id, String status, String updatedAt, int localRev) {
    return (update(sales)..where((s) => s.id.equals(id))).write(
      SalesCompanion(status: Value(status), updatedAt: Value(updatedAt), localRev: Value(localRev)),
    );
  }
}
