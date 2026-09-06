import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';

void main() {
  test('sensitive model strings redact credentials and password hashes', () {
    const credentials = PaystackCredentials(
      baseUrl: 'https://example.test',
      apiKey: 'device-api-key-secret',
      currency: 'KES',
      defaultEmail: 'private@example.test',
    );
    const user = User(
      id: 'user-id',
      role: UserRole.admin,
      name: 'Owner Name',
      username: 'owner',
      email: 'owner@example.test',
      passwordHash: r'$2b$12$sensitive-hash',
      phone: '0712345678',
      status: 'active',
    );

    expect(credentials.toString(), isNot(contains('device-api-key-secret')));
    expect(credentials.toString(), isNot(contains('private@example.test')));
    expect(user.toString(), isNot(contains(r'$2b$12$sensitive-hash')));
    expect(user.toString(), isNot(contains('owner@example.test')));
    expect(user.toString(), isNot(contains('0712345678')));
  });
}
