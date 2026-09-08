import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/providers.dart';
import '../entities/user.dart';
import '../../data/repositories/user_repository_impl.dart';

const _biometricUserKey = 'nexapos.security.biometricUserId';

abstract class DeviceAuthenticationGateway {
  Future<bool> isSupported();
  Future<bool> authenticate();
}

class LocalDeviceAuthenticationGateway implements DeviceAuthenticationGateway {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  Future<bool> isSupported() async =>
      await _auth.canCheckBiometrics || await _auth.isDeviceSupported();

  @override
  Future<bool> authenticate() => _auth.authenticate(
    localizedReason: defaultTargetPlatform == TargetPlatform.windows
        ? 'Use Windows Hello to unlock NexaPOS'
        : 'Use your fingerprint or face to unlock NexaPOS',
    biometricOnly: defaultTargetPlatform != TargetPlatform.windows,
    persistAcrossBackgrounding: true,
  );
}

final deviceAuthenticationGatewayProvider =
    Provider<DeviceAuthenticationGateway>(
      (_) => LocalDeviceAuthenticationGateway(),
    );

final appSecurityServiceProvider = Provider<AppSecurityService>(
  (ref) => AppSecurityService(ref),
);

class AppSecurityService {
  final Ref _ref;
  AppSecurityService(this._ref);

  Future<bool> get isBiometricLoginEnabled async =>
      (await _ref.read(secureStorageProvider).read(key: _biometricUserKey)) !=
      null;

  Future<bool> canUseBiometricLogin() async {
    if (!await isBiometricLoginEnabled) return false;
    try {
      return await _ref.read(deviceAuthenticationGatewayProvider).isSupported();
    } catch (_) {
      return false;
    }
  }

  Future<void> enableFor(User user) async {
    final gateway = _ref.read(deviceAuthenticationGatewayProvider);
    if (!await gateway.isSupported()) {
      throw StateError(
        'Set up fingerprint, face recognition, or Windows Hello on this device first.',
      );
    }
    if (!await gateway.authenticate()) {
      throw StateError('Device authentication was cancelled.');
    }
    await _ref
        .read(secureStorageProvider)
        .write(key: _biometricUserKey, value: user.id);
  }

  Future<void> disable() =>
      _ref.read(secureStorageProvider).delete(key: _biometricUserKey);

  Future<User?> authenticateUser() async {
    final storage = _ref.read(secureStorageProvider);
    final userId = await storage.read(key: _biometricUserKey);
    if (userId == null) return null;
    try {
      final gateway = _ref.read(deviceAuthenticationGatewayProvider);
      if (!await gateway.isSupported() || !await gateway.authenticate()) {
        return null;
      }
      final user = await _ref.read(userRepositoryProvider).findById(userId);
      if (user == null || !user.isActive) {
        await disable();
        return null;
      }
      return user;
    } catch (_) {
      return null;
    }
  }
}
