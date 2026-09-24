import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app can send a person to the system's Date & time screen. Only
/// Android has one it can open: an app cannot change the clock there itself, so
/// the person does it - Settings > Region and Time in NexaPOS just takes them to
/// the right place.
bool get canOpenDateSettings =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

const _channel = MethodChannel('com.nexapos/app_info');

Future<bool> openAndroidDateSettings() async {
  if (!canOpenDateSettings) return false;
  try {
    return await _channel.invokeMethod<bool>('openDateSettings') ?? false;
  } catch (_) {
    return false;
  }
}

/// Injectable so a screen test does not need a device.
final dateSettingsOpenerProvider = Provider<Future<bool> Function()>(
  (ref) => openAndroidDateSettings,
);
