import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/domain/services/app_lock_settings.dart';

import '../../support/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installFakeSecureStorage);

  test(
    'app lock defaults to 30 minutes and persists supported choices',
    () async {
      final first = ProviderContainer();
      expect(first.read(appLockSettingsProvider), 30);
      await first.read(appLockSettingsProvider.notifier).setMinutes(5);
      expect(first.read(appLockSettingsProvider), 5);
      first.dispose();

    final restored = ProviderContainer();
    await restored.read(appLockSettingsProvider.notifier).restore();
      expect(restored.read(appLockSettingsProvider), 5);
      restored.dispose();
    },
  );

  test('unsupported lock durations are rejected', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await expectLater(
      container.read(appLockSettingsProvider.notifier).setMinutes(2),
      throwsArgumentError,
    );
  });
}
