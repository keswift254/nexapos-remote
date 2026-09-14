import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import 'device_authentication_gateway.dart';

/// Split out of app_security_service.dart because local_auth is
/// native-only (Android/Windows) - importing it unconditionally would
/// block the whole file, and everything that imports it, from
/// compiling for web. Selected via a conditional import keyed on
/// dart.library.js_interop in app_security_service.dart.
DeviceAuthenticationGateway createDeviceAuthenticationGateway() =>
    LocalDeviceAuthenticationGateway();

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
