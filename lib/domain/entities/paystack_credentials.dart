import 'package:freezed_annotation/freezed_annotation.dart';

part 'paystack_credentials.freezed.dart';

/// Deliberately NOT stored in the business_settings table: that table
/// is a Phase 2 sync participant (see business_settings_table.dart), and
/// [apiKey] must never ride along in a sync payload.
/// PaystackCredentialsService persists this via flutter_secure_storage
/// instead - the same device-local, never-synced mechanism already used
/// for the session token.
///
/// This device never holds a Paystack secret key at all - [apiKey] is a
/// token issued by the operator's own payments-platform backend
/// (register_device), which is the only thing that ever talks to
/// Paystack directly. See PaystackGateway.
@freezed
abstract class PaystackCredentials with _$PaystackCredentials {
  const factory PaystackCredentials({
    required String baseUrl,
    required String apiKey,
    required String currency,
    required String defaultEmail,
  }) = _PaystackCredentials;

  const PaystackCredentials._();

  bool get isConfigured => baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;
}
