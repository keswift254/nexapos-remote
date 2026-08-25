import '../entities/sale_item.dart';

abstract class SaleItemRepository {
  Future<List<SaleItem>> forSale(String saleId);

  /// Bulk-inserts every line of a sale in one go - CheckoutService
  /// never inserts sale_items one at a time.
  Future<void> createMany(List<SaleItem> items);
}
