import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/secure_storage_provider.dart';
import '../entities/user.dart';
import '../../data/repositories/user_repository_impl.dart';
export 'device_authentication_gateway.dart';
import 'device_authentication_gateway.dart';
import 'device_authentication_gateway_native.dart'
    if (dart.library.js_interop) 'device_authentication_gateway_stub.dart'
    as device_auth;

const _biometricUserKey = 'nexapos.security.biometricUserId';

final deviceAuthenticationGatewayProvider =
    Provider<DeviceAuthenticationGateway>(
      (_) => device_auth.createDeviceAuthenticationGateway(),
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
