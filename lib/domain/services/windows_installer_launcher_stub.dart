/// Selected instead of windows_installer_launcher_native.dart when
/// compiling for web - unreachable in practice, since the only caller
/// (UpdateService._installWindowsSetup) only runs when Platform.
/// isWindows is true, which is always false on web.
void launchWindowsInstallerElevated(String setupPath, {String? arguments}) =>
    throw UnimplementedError(
      'Self-update has no meaning on web - there is no installed binary.',
    );
