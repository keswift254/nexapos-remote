import '../entities/sale.dart';

abstract class SaleRepository {
  Future<Sale?> findById(String id);

  /// Inserts a new sale row exactly as given - CheckoutService decides
  /// status ('paid' for cash/mpesa/mpesa_manual, 'pending' for a
  /// paystack sale awaiting gateway confirmation).
  Future<String> create(Sale sale);

  /// The only way a sale's status ever changes after creation: a
  /// pending paystack sale resolving to 'paid' or 'cancelled'.
  Future<void> updateStatus(String id, String status);

  /// Sales left stranded in 'pending' - see Sales table's status doc.
  Future<List<Sale>> findPendingPaystack();
}
