import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:local_auth/local_auth.dart';

import '../../core/legacy_windows_edition.dart';
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
  Future<bool> isSupported() async {
    // The Windows 7/8 edition is built without the local_auth plugin (Windows
    // Hello does not exist there and the plugin cannot load), so there is
    // nothing to ask - and no plugin to answer if we did.
    if (kLegacyWindowsEdition) return false;
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> authenticate() => _auth.authenticate(
    localizedReason: defaultTargetPlatform == TargetPlatform.windows
        ? 'Use Windows Hello to unlock NexaPOS'
        : 'Use your fingerprint or face to unlock NexaPOS',
    biometricOnly: defaultTargetPlatform != TargetPlatform.windows,
    persistAcrossBackgrounding: true,
  );
}
