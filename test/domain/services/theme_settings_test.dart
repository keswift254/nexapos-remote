import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/domain/services/theme_settings.dart';

import '../../support/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installFakeSecureStorage);

  test(
    'theme follows the system by default and remembers a local choice',
    () async {
      final first = ProviderContainer();
      expect(first.read(themeSettingsProvider), ThemeMode.system);
      await first.read(themeSettingsProvider.notifier).setMode(ThemeMode.dark);
      expect(first.read(themeSettingsProvider), ThemeMode.dark);
      first.dispose();

      final reopened = ProviderContainer();
      addTearDown(reopened.dispose);
      await reopened.read(themeSettingsProvider.notifier).restore();
      expect(reopened.read(themeSettingsProvider), ThemeMode.dark);
      await reopened
          .read(themeSettingsProvider.notifier)
          .setMode(ThemeMode.light);
      expect(reopened.read(themeSettingsProvider), ThemeMode.light);
      await reopened
          .read(themeSettingsProvider.notifier)
          .setMode(ThemeMode.system);
      expect(reopened.read(themeSettingsProvider), ThemeMode.system);
    },
  );
}
