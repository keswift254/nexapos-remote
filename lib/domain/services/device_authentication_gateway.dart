/// Platform-agnostic interface for "prove you're the device owner"
/// (fingerprint/face/Windows Hello on native, a WebAuthn passkey - Face ID,
/// Touch ID, a fingerprint - in a browser, see
/// device_authentication_gateway_web.dart). Kept in its own file with
/// no platform-specific imports so app_security_service.dart can depend
/// on the interface directly while conditionally importing whichever
/// concrete implementation matches the current platform.
abstract class DeviceAuthenticationGateway {
  Future<bool> isSupported();
  Future<bool> authenticate();
}

/// For gateways that must be set up on this device before their first use: the browser's
/// passkey has to be created once (the person unlocks it with their face or finger), and is
/// then asked for at every sign in. Native fingerprint / Windows Hello need no such step, so
/// they do not implement this and [AppSecurityService] treats them as always ready.
abstract class EnrollableDeviceAuthentication {
  /// Creates the credential. False if the person cancelled; throws [StateError] (with
  /// something fit to show) if this device or browser cannot do it.
  Future<bool> enroll();

  /// Whether a credential from an earlier [enroll] is still here.
  Future<bool> isEnrolled();

  /// Removes it (quick sign in turned off).
  Future<void> forget();
}
