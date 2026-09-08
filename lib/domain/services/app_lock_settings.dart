import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers.dart';

part 'app_lock_settings.g.dart';

const _appLockMinutesKey = 'nexapos.security.appLockMinutes';

@Riverpod(keepAlive: true)
class AppLockSettings extends _$AppLockSettings {
  @override
  int build() {
    restore();
    return 30;
  }

  Future<void> restore() async {
    final raw = await ref
        .read(secureStorageProvider)
        .read(key: _appLockMinutesKey);
    final value = int.tryParse(raw ?? '');
    if (value != null && const {0, 1, 5, 30}.contains(value)) state = value;
  }

  Future<void> setMinutes(int minutes) async {
    if (!const {0, 1, 5, 30}.contains(minutes)) {
      throw ArgumentError.value(minutes, 'minutes');
    }
    await ref
        .read(secureStorageProvider)
        .write(key: _appLockMinutesKey, value: '$minutes');
    state = minutes;
  }
}
