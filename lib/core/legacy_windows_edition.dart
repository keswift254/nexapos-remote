/// True only in the Windows 7/8 edition of the desktop app, which is built
/// with `--dart-define=NEXAPOS_LEGACY_WINDOWS=true`.
///
/// That edition runs on a patched Flutter engine (Google's official one cannot
/// start below Windows 10) and leaves out plugins that need Windows 10
/// components - currently local_auth's Windows Hello support. It also updates
/// from its own installer, never the Windows 10/11 one: that installer's
/// engine cannot start on these systems, so following it would brick the PC.
const bool kLegacyWindowsEdition = bool.fromEnvironment(
  'NEXAPOS_LEGACY_WINDOWS',
);
