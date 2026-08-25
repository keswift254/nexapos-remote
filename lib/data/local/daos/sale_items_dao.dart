import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/sale_items_table.dart';

part 'sale_items_dao.g.dart';

@DriftAccessor(tables: [SaleItems])
class SaleItemsDao extends DatabaseAccessor<AppDatabase> with _$SaleItemsDaoMixin {
  SaleItemsDao(super.db);

  Future<void> insertMany(List<SaleItemsCompanion> companions) {
    return batch((b) => b.insertAll(saleItems, companions));
  }

  Future<List<SaleItem>> forSale(String saleId) {
    return (select(saleItems)..where((i) => i.saleId.equals(saleId) & i.deletedAt.isNull())).get();
  }
}
