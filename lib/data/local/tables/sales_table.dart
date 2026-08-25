import 'package:drift/drift.dart';
import 'synced_columns.dart';
import 'users_table.dart';

/// sale_type: 'retail', 'wholesale'.
/// payment_method: 'cash', 'mpesa', 'mpesa_manual', 'paystack' (same 4
/// values as PHP). On the phone, mpesa/mpesa_manual/paystack are marked
/// paid immediately with an optional reference note - there is no online
/// gateway to call while offline, so PHP's pending-status/webhook dance
/// doesn't apply. See PaymentRecords for the note/reference.
/// status: 'paid', 'pending', 'cancelled' (pending is unused in Phase 1
/// since nothing async ever resolves it, but costs nothing to keep for a
/// future "park/hold sale" workflow).
///
/// [saleNumber] is regenerated as deviceShortCode-yyyyMMddHHmmss-
/// randomSuffix in CheckoutService, fixing a genuine collision risk
/// in PHP's `'S' . date('YmdHis')` (one-second resolution, no random
/// suffix) - confirmed at public/index.php:325.
class Sales extends Table with SyncedColumns {
  TextColumn get saleNumber => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get customerName => text().nullable()();
  TextColumn get customerPhone => text().nullable()();
  TextColumn get saleType => text()();
  TextColumn get paymentMethod => text()();
  IntColumn get subtotalCents => integer()();
  IntColumn get discountCents => integer().withDefault(const Constant(0))();
  IntColumn get totalCents => integer()();
  TextColumn get status => text()();
}
