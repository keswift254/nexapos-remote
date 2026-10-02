import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:ffi/ffi.dart';
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

  // Capture only this process's foreground window. A separate app may be
  // foreground if authentication is started programmatically.
  (int, bool)? _ownForegroundWindow() {
    if (!Platform.isWindows) return null;
    try {
      final user32 = DynamicLibrary.open('user32.dll');
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      final getForegroundWindow = user32.lookupFunction<
          IntPtr Function(), int Function()>('GetForegroundWindow');
      final getWindowThreadProcessId = user32.lookupFunction<
          Uint32 Function(IntPtr, Pointer<Uint32>),
          int Function(int, Pointer<Uint32>)>('GetWindowThreadProcessId');
      final getCurrentProcessId = kernel32.lookupFunction<
          Uint32 Function(), int Function()>('GetCurrentProcessId');
      final isZoomed = user32.lookupFunction<
          Int32 Function(IntPtr), int Function(int)>('IsZoomed');
      final hwnd = getForegroundWindow();
      if (hwnd == 0) return null;
      final pid = calloc<Uint32>();
      try {
        getWindowThreadProcessId(hwnd, pid);
        if (pid.value != getCurrentProcessId()) return null;
      } finally {
        calloc.free(pid);
      }
      return (hwnd, isZoomed(hwnd) != 0);
    } catch (_) {
      return null;
    }
  }

  void _restoreWindowAfterHello((int, bool)? window) {
    if (window == null) return;
    try {
      final user32 = DynamicLibrary.open('user32.dll');
      final isWindow = user32.lookupFunction<
          Int32 Function(IntPtr), int Function(int)>('IsWindow');
      final isIconic = user32.lookupFunction<
          Int32 Function(IntPtr), int Function(int)>('IsIconic');
      final showWindow = user32.lookupFunction<
          Int32 Function(IntPtr, Int32), int Function(int, int)>('ShowWindow');
      final setForegroundWindow = user32.lookupFunction<
          Int32 Function(IntPtr), int Function(int)>('SetForegroundWindow');
      final hwnd = window.$1;
      if (isWindow(hwnd) == 0) return;
      if (isIconic(hwnd) != 0) {
        showWindow(hwnd, window.$2 ? 3 /* SW_MAXIMIZE */ : 9 /* SW_RESTORE */);
      }
      setForegroundWindow(hwnd);
    } catch (_) {
      // Restoring the UI is best effort; never change the auth result.
    }
  }

  // Windows Hello runs in a separate system process. When this method is
  // invoked by a button press, NexaPOS has foreground permission and can hand
  // it to that process before local_auth asks Windows to open the prompt.
  // Windows may still refuse to change focus; authentication must proceed.
  void _allowWindowsHelloForeground() {
    if (!Platform.isWindows) return;
    try {
      final allowSetForegroundWindow = DynamicLibrary.open('user32.dll')
          .lookupFunction<Int32 Function(Uint32), int Function(int)>(
            'AllowSetForegroundWindow',
          );
      const asfwAny = 0xFFFFFFFF;
      allowSetForegroundWindow(asfwAny);
    } catch (_) {
      // A foreground handoff is only a presentation aid, never an auth gate.
    }
  }

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
  Future<bool> authenticate() async {
    final window = _ownForegroundWindow();
    _allowWindowsHelloForeground();
    try {
      return await _auth.authenticate(
        localizedReason: defaultTargetPlatform == TargetPlatform.windows
            ? 'Use Windows Hello to unlock NexaPOS'
            : 'Use your fingerprint or face to unlock NexaPOS',
        biometricOnly: defaultTargetPlatform != TargetPlatform.windows,
        persistAcrossBackgrounding: true,
      );
    } finally {
      if (window != null) {
        // The Windows Security dialog can finish its focus transition just
        // after local_auth returns, leaving the Flutter window minimized.
        await Future<void>.delayed(const Duration(milliseconds: 150));
        _restoreWindowAfterHello(window);
      }
    }
  }
}
