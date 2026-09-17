import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/home_screen_install_engine_native.dart'
    if (dart.library.js_interop) '../../core/home_screen_install_engine_web.dart'
    as engine;
import '../../core/home_screen_install_state.dart';

export '../../core/home_screen_install_state.dart' show HomeScreenInstallState;

part 'home_screen_install_service.g.dart';

/// Only ever meaningfully different from the default (nothing to offer)
/// on web - see HomeScreenInstallState.isStandalone's doc. Kept alive so
/// Android Chrome's beforeinstallprompt listener, registered once in
/// build(), stays attached for the tab's whole life instead of being torn
/// down and re-added whenever this provider's last watcher unsubscribes.
@Riverpod(keepAlive: true)
class HomeScreenInstallNotifier extends _$HomeScreenInstallNotifier {
  final _engine = engine.createHomeScreenInstallEngine();

  @override
  HomeScreenInstallState build() => _engine.start((next) => state = next);

  Future<void> promptInstall() => _engine.promptInstall();

  void dismiss() {
    _engine.dismiss();
    state = state.copyWith(isDismissed: true);
  }
}
