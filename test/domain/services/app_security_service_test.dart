import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/app_security_service.dart';
import 'package:nexapos_mobile/domain/services/auth_service.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';

import '../../support/fake_secure_storage.dart';

class _DeviceAuthentication implements DeviceAuthenticationGateway {
  bool supported = true;
  bool approved = true;
  int calls = 0;
  @override
  Future<bool> authenticate() async {
    calls++;
    return approved;
  }

  @override
  Future<bool> isSupported() async => supported;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installFakeSecureStorage);

  test('device authentication restores only the enrolled active user without storing a password', () async {
    final device = _DeviceAuthentication();
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceAuthenticationGatewayProvider.overrideWithValue(device),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final created = await container
        .read(authServiceProvider)
        .createUser(
          name: 'Felix',
          username: 'felix',
          password: 'secret123',
          role: UserRole.admin,
        );
    final user = created.when(
      ok: (value) => value,
      failure: (message) => throw StateError(message),
    );
    await container.read(appSecurityServiceProvider).enableFor(user);
    expect(device.calls, 1);
    final stored = await container.read(secureStorageProvider).readAll();
    expect(stored.values, isNot(contains('secret123')));

    final login = await container
        .read(sessionProvider.notifier)
        .loginWithDeviceAuthentication();
    expect(login.isOk, true);
    expect(container.read(sessionProvider)?.id, user.id);
    expect(device.calls, 2);
  });

  test(
    'cancelled or unavailable device authentication does not sign in',
    () async {
      final device = _DeviceAuthentication()..approved = false;
      final db = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          deviceAuthenticationGatewayProvider.overrideWithValue(device),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final result = await container
          .read(sessionProvider.notifier)
          .loginWithDeviceAuthentication();
      expect(result.isFailure, true);
      expect(container.read(sessionProvider), isNull);
    },
  );
}
