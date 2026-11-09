import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/secure_storage_provider.dart';
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


/// A browser-style gateway: its credential has to be created (enrolled) once before it can sign anyone in.
class _BrowserDevice implements DeviceAuthenticationGateway, EnrollableDeviceAuthentication {
  bool supported = true;
  bool enrollApproved = true;
  bool signInApproved = true;
  bool enrolled = false;
  bool enrollThrows = false;
  int enrollCalls = 0;
  int authenticateCalls = 0;
  int forgetCalls = 0;
  /// Whether the browser's hint says no but a passkey can still be tried (WebAuthn exists).
  bool canTry = false;
  // Like the real web gateway: a passkey made here before proves it works, whatever the hint says.
  @override
  Future<bool> isSupported() async => supported || enrolled;
  @override
  Future<bool> canTryAnyway() async => canTry;
  @override
  Future<bool> authenticate() async {
    authenticateCalls++;
    return enrolled && signInApproved;
  }

  @override
  Future<bool> enroll() async {
    enrollCalls++;
    if (enrollThrows) throw StateError('This browser cannot set up quick sign in.');
    if (enrollApproved) enrolled = true;
    return enrollApproved;
  }

  @override
  Future<bool> isEnrolled() async => enrolled;
  @override
  Future<String> whyUnsupported() async => 'No Face ID or fingerprint is turned on here. (code: no-device-unlock)';
  @override
  Future<void> forget() async {
    forgetCalls++;
    enrolled = false;
  }
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

  group('a browser passkey', () {
    Future<(ProviderContainer, _BrowserDevice, dynamic)> setUpBrowser() async {
      final device = _BrowserDevice();
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
          .createUser(name: 'Felix', username: 'felix', password: 'secret123', role: UserRole.admin);
      final user = created.when(ok: (value) => value, failure: (message) => throw StateError(message));
      return (container, device, user);
    }

    test('turning quick sign in on creates the passkey (one prompt), and signing in then asks for it', () async {
      final (container, device, user) = await setUpBrowser();
      final security = container.read(appSecurityServiceProvider);
      expect(await security.canUseBiometricLogin(), isFalse, reason: 'not turned on yet');

      await security.enableFor(user);
      expect(device.enrollCalls, 1);
      expect(device.authenticateCalls, 0, reason: 'set-up is the one prompt; it is not asked twice');
      expect(await security.canUseBiometricLogin(), isTrue);

      final login = await container.read(sessionProvider.notifier).loginWithDeviceAuthentication();
      expect(login.isOk, isTrue);
      expect(container.read(sessionProvider)?.id, user.id);
      expect(device.authenticateCalls, 1);
    });

    test('cancelling the set-up prompt leaves quick sign in off', () async {
      final (container, device, user) = await setUpBrowser();
      device.enrollApproved = false;
      final security = container.read(appSecurityServiceProvider);
      await expectLater(security.enableFor(user), throwsA(isA<StateError>()));
      expect(await security.isBiometricLoginEnabled, isFalse);
      expect(await security.canUseBiometricLogin(), isFalse);
    });

    test('a browser that cannot do it says so, and nothing is turned on', () async {
      final (container, device, user) = await setUpBrowser();
      device.enrollThrows = true;
      final security = container.read(appSecurityServiceProvider);
      await expectLater(security.enableFor(user), throwsA(isA<StateError>()));
      expect(await security.isBiometricLoginEnabled, isFalse);

      device
        ..enrollThrows = false
        ..supported = false;
      await expectLater(
        security.enableFor(user),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('no-device-unlock'))),
      );
      expect(device.enrollCalls, 1, reason: 'not even tried when the device cannot do it');
    });

    test('a "no Face ID here" hint does not stop a browser that can do passkeys from trying (iOS 26.2 says no on iPhones that have Face ID)', () async {
      final (container, device, user) = await setUpBrowser();
      device
        ..supported = false
        ..canTry = true;
      final security = container.read(appSecurityServiceProvider);
      await security.enableFor(user);
      expect(device.enrollCalls, 1, reason: 'the phone itself decides');
      expect(await security.canUseBiometricLogin(), isTrue, reason: 'and once it worked, the sign-in button is offered despite the hint');
      final login = await container.read(sessionProvider.notifier).loginWithDeviceAuthentication();
      expect(login.isOk, isTrue);
    });

    test('when the attempt itself is cancelled or refused after a "no" hint, quick sign in stays off', () async {
      final (container, device, user) = await setUpBrowser();
      device
        ..supported = false
        ..canTry = true
        ..enrollApproved = false;
      final security = container.read(appSecurityServiceProvider);
      await expectLater(security.enableFor(user), throwsA(isA<StateError>()));
      expect(await security.isBiometricLoginEnabled, isFalse);
      expect(await security.canUseBiometricLogin(), isFalse);
    });

    test('if the browser lost its passkey the button is not offered (it could only fail)', () async {
      final (container, device, user) = await setUpBrowser();
      final security = container.read(appSecurityServiceProvider);
      await security.enableFor(user);
      expect(await security.canUseBiometricLogin(), isTrue);
      device.enrolled = false; // site data cleared
      expect(await security.canUseBiometricLogin(), isFalse);
    });

    test('turning it off removes the passkey as well as the setting', () async {
      final (container, device, user) = await setUpBrowser();
      final security = container.read(appSecurityServiceProvider);
      await security.enableFor(user);
      await security.disable();
      expect(device.forgetCalls, 1);
      expect(device.enrolled, isFalse);
      expect(await security.isBiometricLoginEnabled, isFalse);
      expect(await security.canUseBiometricLogin(), isFalse);
    });

    test('a failed sign-in prompt does not sign anyone in', () async {
      final (container, device, user) = await setUpBrowser();
      await container.read(appSecurityServiceProvider).enableFor(user);
      device.signInApproved = false;
      final login = await container.read(sessionProvider.notifier).loginWithDeviceAuthentication();
      expect(login.isFailure, isTrue);
      expect(container.read(sessionProvider), isNull);
    });

    test('warming up asks the device once and never throws', () async {
      final (container, device, _) = await setUpBrowser();
      await container.read(appSecurityServiceProvider).warmUp();
      device.supported = false;
      await container.read(appSecurityServiceProvider).warmUp();
    });
  });

  test('phone, tablet and PC apps (no passkey step) behave exactly as before', () async {
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
        .createUser(name: 'Felix', username: 'felix', password: 'secret123', role: UserRole.admin);
    final user = created.when(ok: (value) => value, failure: (message) => throw StateError(message));
    final security = container.read(appSecurityServiceProvider);
    await security.enableFor(user);
    expect(device.calls, 1, reason: 'the one prompt at set-up');
    expect(await security.canUseBiometricLogin(), isTrue);
    await security.disable();
    expect(await security.canUseBiometricLogin(), isFalse);
  });
}
