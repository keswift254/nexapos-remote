import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// A setup executable with a `requireAdministrator` manifest cannot be
/// launched by CreateProcess from the unelevated Flutter process. Shell
/// Execute's `runas` verb delegates the handoff to Windows and shows the
/// standard UAC prompt instead.
///
/// Split out of update_service.dart - the only part of that file that
/// touched win32/ffi (hence dart:ffi) - so the rest of the file (which
/// dashboard_screen.dart imports unconditionally for every role) can
/// still compile for web. Selected via a conditional import keyed on
/// dart.library.js_interop in update_service.dart; only ever actually
/// called when Platform.isWindows is true, so the web stub's
/// UnimplementedError is unreachable in practice.
void launchWindowsInstallerElevated(String setupPath) {
  final result = using((arena) {
    return ShellExecute(
      null,
      arena.pcwstr('runas'),
      arena.pcwstr(setupPath),
      null,
      null,
      SW_SHOWNORMAL,
    );
  });
  if (result.address <= 32) {
    throw StateError(
      'Windows could not start the installer (ShellExecute code ${result.address}).',
    );
  }
}
