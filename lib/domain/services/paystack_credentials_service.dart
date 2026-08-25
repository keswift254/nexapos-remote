import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../entities/paystack_credentials.dart';

part 'paystack_credentials_service.g.dart';

const _baseUrlKey = 'nexapos.platform.baseUrl';
const _apiKeyKey = 'nexapos.platform.apiKey';
const _currencyKey = 'nexapos.paystack.currency';
const _defaultEmailKey = 'nexapos.paystack.defaultEmail';
const _deviceLabelKey = 'nexapos.platform.deviceLabel';
const _defaultCurrency = 'KES';
const _defaultEmail = 'customer@nexapos.co.ke';

@Riverpod(keepAlive: true)
PaystackCredentialsService paystackCredentialsService(Ref ref) {
  return PaystackCredentialsService(ref.watch(secureStorageProvider));
}

/// See paystack_credentials.dart for why these live in secure storage
/// instead of the synced business_settings table. Deliberately does NOT
/// cache settlement status (subaccount_code etc.) - that lives only on
/// the backend (see PlatformOnboardingGateway.getClientStatus), fetched
/// fresh every time, so it can never drift from what the operator (or a
/// dashboard edit) actually set.
class PaystackCredentialsService {
  final FlutterSecureStorage _storage;

  PaystackCredentialsService(this._storage);

  Future<PaystackCredentials> load() async {
    final baseUrl = await _storage.read(key: _baseUrlKey) ?? '';
    final apiKey = await _storage.read(key: _apiKeyKey) ?? '';
    final currency = await _storage.read(key: _currencyKey) ?? _defaultCurrency;
    final email = await _storage.read(key: _defaultEmailKey) ?? _defaultEmail;
    return PaystackCredentials(baseUrl: baseUrl, apiKey: apiKey, currency: currency, defaultEmail: email);
  }

  Future<void> save(PaystackCredentials credentials) async {
    await _storage.write(key: _baseUrlKey, value: credentials.baseUrl.trim());
    await _storage.write(key: _apiKeyKey, value: credentials.apiKey.trim());
    final currency = credentials.currency.trim();
    await _storage.write(key: _currencyKey, value: currency.isEmpty ? _defaultCurrency : currency.toUpperCase());
    final email = credentials.defaultEmail.trim();
    await _storage.write(key: _defaultEmailKey, value: email.isEmpty ? _defaultEmail : email);
  }

  /// The label this device registered under (e.g. "Front counter") - not
  /// part of [PaystackCredentials] itself since nothing about checkout
  /// needs it; the only reader is device_sync_screen.dart, which shows it
  /// to other devices scanning the network so they can tell this device
  /// apart from any other shop that happens to be broadcasting nearby.
  Future<String> loadDeviceLabel() async => (await _storage.read(key: _deviceLabelKey))?.trim() ?? '';

  Future<void> saveDeviceLabel(String label) async {
    await _storage.write(key: _deviceLabelKey, value: label.trim());
  }

  /// Un-registers this device from whichever payments server it's
  /// currently pointed at, without touching currency/default-email/
  /// device-label (those are this device's own preferences, not tied to
  /// a particular server) - PaymentSettingsScreen only shows the server-
  /// address field again once [isConfigured] is false, so this is the
  /// only way back to it after the first registration.
  Future<void> clearRegistration() async {
    await _storage.delete(key: _baseUrlKey);
    await _storage.delete(key: _apiKeyKey);
  }
}
