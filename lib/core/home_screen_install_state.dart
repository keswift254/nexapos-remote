/// Whether and how this session can be offered "add to home screen" -
/// native and web (and, on web, Android Chrome vs iOS Safari) each
/// support this differently, so this is a plain data snapshot rather
/// than any one browser API's own shape. See
/// home_screen_install_engine_web.dart for the actual browser interop.
class HomeScreenInstallState {
  const HomeScreenInstallState({
    this.isStandalone = true,
    this.isIosSafari = false,
    this.canPromptInstall = false,
    this.isDismissed = false,
  });

  /// No browser chrome to add a shortcut to at all - either this is the
  /// native app, or the web app is already running from a home-screen
  /// icon. Defaults true so every platform starts as "nothing to offer"
  /// until the web engine's synchronous browser checks say otherwise.
  final bool isStandalone;

  /// iOS Safari, where a shortcut can only ever be added manually
  /// (Share > Add to Home Screen) - iOS has never shipped
  /// beforeinstallprompt to hook a real prompt into.
  final bool isIosSafari;

  /// Android Chrome/Edge has fired beforeinstallprompt, so promptInstall
  /// can show a real browser-native install dialog right now.
  final bool canPromptInstall;

  final bool isDismissed;

  bool get shouldOffer =>
      !isStandalone && !isDismissed && (canPromptInstall || isIosSafari);

  HomeScreenInstallState copyWith({
    bool? isStandalone,
    bool? isIosSafari,
    bool? canPromptInstall,
    bool? isDismissed,
  }) {
    return HomeScreenInstallState(
      isStandalone: isStandalone ?? this.isStandalone,
      isIosSafari: isIosSafari ?? this.isIosSafari,
      canPromptInstall: canPromptInstall ?? this.canPromptInstall,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }
}

/// Platform-specific engine behind [HomeScreenInstallState] - selected via
/// a conditional import in home_screen_install_service.dart, the same way
/// windows_installer_launcher_native/_stub.dart split native-only code out
/// of update_service.dart.
abstract class HomeScreenInstallEngine {
  /// Reads the synchronous browser checks (user agent, standalone display
  /// mode, dismissed flag) and starts listening for
  /// beforeinstallprompt/appinstalled so [onChange] can push later
  /// updates. Called once, from the owning notifier's build().
  HomeScreenInstallState start(void Function(HomeScreenInstallState) onChange);

  /// Shows the browser's native install dialog. No-op wherever the last
  /// emitted state's canPromptInstall was false.
  Future<void> promptInstall();

  /// Records that the banner was dismissed, persisted so it stays hidden
  /// across reloads until the app is actually installed.
  void dismiss();
}
