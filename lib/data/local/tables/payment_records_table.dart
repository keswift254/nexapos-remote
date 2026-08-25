import 'package:drift/drift.dart';
import 'synced_columns.dart';
import 'sales_table.dart';

/// Generalized from PHP's mpesa_payments table. Deliberately drops
/// merchant_request_id/checkout_request_id/result_code/raw_request/
/// raw_response/raw_callback - those encode PHP-specific webhook
/// mechanics that don't exist on-device. A Phase 2 sync mapping layer
/// reconciles the shape difference; there is no value in cargo-culting
/// unused server-only columns into the client schema now.
///
/// [method] mirrors sales.payment_method for the external methods
/// (mpesa, mpesa_manual, paystack). [referenceNote] is free text the
/// cashier can type (e.g. an M-Pesa confirmation code) - unvalidated,
/// since there's no gateway on-device to verify it against.
/// [status] is always 'paid' in Phase 1: a sale using an external
/// payment method is only inserted here once the cashier has confirmed
/// it, there being no pending/webhook state possible offline.
class PaymentRecords extends Table with SyncedColumns {
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get method => text()();
  IntColumn get amountCents => integer()();
  TextColumn get referenceNote => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('paid'))();
}
