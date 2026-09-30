import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AndroidUpdatePermissionService {
  static const _channel = MethodChannel('com.nexapos/update_permissions');

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> canInstallPackages() async {
    if (!_isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> openSettings() async {
    if (!_isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('openInstallPackageSettings') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

final androidUpdatePermissionServiceProvider =
    Provider<AndroidUpdatePermissionService>(
  (ref) => AndroidUpdatePermissionService(),
);
