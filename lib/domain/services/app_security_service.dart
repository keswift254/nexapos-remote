import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart' show clockProvider;
import '../../core/secure_storage_provider.dart';
import '../entities/user.dart';
import '../../data/repositories/user_repository_impl.dart';
export 'device_authentication_gateway.dart';
import 'device_authentication_gateway.dart';
import 'device_authentication_gateway_native.dart'
    if (dart.library.js_interop) 'device_authentication_gateway_stub.dart'
    as device_auth;

const _biometricUserKey = 'nexapos.security.biometricUserId';

/// How long a dismissed "set up quick sign in" reminder stays away.
const biometricReminderEvery = Duration(hours: 72);

/// One reminder clock per user, so one person dismissing it does not silence it
/// for the next.
String _biometricRemindKey(User user) =>
    'nexapos.security.biometricRemindAfter.${user.id}';

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

  /// Whether to nudge [user] to set up quick sign in (fingerprint, face or
  /// Windows Hello): this device can do it, nobody has set it up on this device
  /// yet (there is one such sign-in per device, so a second person is not invited
  /// to take it over), and this user has not dismissed the reminder within the
  /// last [biometricReminderEvery]. Any doubt means no reminder.
  Future<bool> shouldRemindBiometricSetup(User user) async {
    try {
      if (!await _ref.read(deviceAuthenticationGatewayProvider).isSupported()) {
        return false;
      }
      final storage = _ref.read(secureStorageProvider);
      if (await storage.read(key: _biometricUserKey) != null) return false;
      final raw = await storage.read(key: _biometricRemindKey(user));
      final remindAfter = raw == null ? null : DateTime.tryParse(raw);
      return remindAfter == null ||
          !_ref.read(clockProvider).now().isBefore(remindAfter);
    } catch (_) {
      return false;
    }
  }

  /// "Dismiss": the reminder comes back for [user] after [biometricReminderEvery].
  Future<void> dismissBiometricReminder(User user) =>
      _ref.read(secureStorageProvider).write(
        key: _biometricRemindKey(user),
        value: _ref
            .read(clockProvider)
            .now()
            .add(biometricReminderEvery)
            .toUtc()
            .toIso8601String(),
      );

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
