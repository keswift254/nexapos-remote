import 'device_authentication_gateway.dart';

/// Selected instead of device_authentication_gateway_native.dart when
/// compiling for web (see app_security_service.dart's conditional
/// import) - no biometric/Windows Hello equivalent exists in a browser,
/// so this always reports unsupported. AppSecurityService.
/// canUseBiometricLogin() already checks isSupported() before ever
/// offering the option, so this alone is enough to make every caller
/// fall back to password login on web with no web-specific branching
/// anywhere else.
DeviceAuthenticationGateway createDeviceAuthenticationGateway() =>
    _UnsupportedDeviceAuthenticationGateway();

class _UnsupportedDeviceAuthenticationGateway
    implements DeviceAuthenticationGateway {
  @override
  Future<bool> isSupported() async => false;

  @override
  Future<bool> authenticate() async => false;
}
