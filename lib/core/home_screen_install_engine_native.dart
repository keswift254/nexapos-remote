import 'home_screen_install_state.dart';

/// Selected instead of home_screen_install_engine_web.dart when compiling
/// for native (Windows/Android) - "add to home screen" has no meaning
/// outside a browser tab, so every check just reports "nothing to offer"
/// and every action is a no-op.
class _NativeHomeScreenInstallEngine implements HomeScreenInstallEngine {
  @override
  HomeScreenInstallState start(
    void Function(HomeScreenInstallState) onChange,
  ) => const HomeScreenInstallState();

  @override
  Future<void> promptInstall() async {}

  @override
  void dismiss() {}
}

HomeScreenInstallEngine createHomeScreenInstallEngine() =>
    _NativeHomeScreenInstallEngine();
