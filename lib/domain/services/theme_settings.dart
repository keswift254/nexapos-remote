import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/secure_storage_provider.dart';

const _themeModeKey = 'nexapos.appearance.themeMode';

/// A preference for this device/browser only. Until a saved choice is read,
/// follow the operating system so new installs have the requested default.
class ThemeSettings extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    restore();
    return ThemeMode.system;
  }

  Future<void> restore() async {
    try {
      final saved = await ref
          .read(secureStorageProvider)
          .read(key: _themeModeKey);
      if (!ref.mounted) return;
      state = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      // An unavailable preference store must not prevent the app from opening.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    await ref
        .read(secureStorageProvider)
        .write(key: _themeModeKey, value: mode.name);
    if (ref.mounted) state = mode;
  }
}

final themeSettingsProvider = NotifierProvider<ThemeSettings, ThemeMode>(
  ThemeSettings.new,
);
