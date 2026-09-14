/// Platform-agnostic interface for "prove you're the device owner"
/// (fingerprint/face/Windows Hello on native, nothing on web - see
/// device_authentication_gateway_stub.dart). Kept in its own file with
/// no platform-specific imports so app_security_service.dart can depend
/// on the interface directly while conditionally importing whichever
/// concrete implementation matches the current platform.
abstract class DeviceAuthenticationGateway {
  Future<bool> isSupported();
  Future<bool> authenticate();
}
