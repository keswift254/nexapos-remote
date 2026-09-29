import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/data/payments/platform_http_client.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/services/paystack_credentials_service.dart';

import '../../support/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(installFakeSecureStorage);

  test('registered Render device uses Namecrane with its existing API key', () async {
    final service = PaystackCredentialsService(const FlutterSecureStorage());
    await service.save(const PaystackCredentials(
      baseUrl: 'https://nexapos-platform.onrender.com/index.php',
      apiKey: 'existing-device-key',
      currency: 'KES',
      defaultEmail: 'cashier@example.com',
    ));

    final loaded = await service.load();
    expect(loaded.baseUrl, nexaposPlatformBaseUrl);
    expect(loaded.apiKey, 'existing-device-key');
    expect(loaded.currency, 'KES');
    expect(loaded.defaultEmail, 'cashier@example.com');

    await service.save(loaded);
    expect((await service.load()).baseUrl, nexaposPlatformBaseUrl);
  });

  test('a custom platform address is preserved', () async {
    final service = PaystackCredentialsService(const FlutterSecureStorage());
    await service.save(const PaystackCredentials(
      baseUrl: 'https://custom.example/index.php',
      apiKey: 'custom-device-key',
      currency: 'KES',
      defaultEmail: '',
    ));

    final loaded = await service.load();
    expect(loaded.baseUrl, 'https://custom.example/index.php');
    expect(loaded.apiKey, 'custom-device-key');
  });
}
