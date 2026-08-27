import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/result.dart';
import '../../data/update/update_gateway.dart';

part 'update_service.g.dart';

@Riverpod(keepAlive: true)
UpdateGateway updateGateway(Ref ref) => UpdateGateway();

@Riverpod(keepAlive: true)
UpdateService updateService(Ref ref) => UpdateService(ref);

/// Result the caller of build "does a newer build exist" once the vendor's
/// server has been asked - separate from [UpdateAvailabilityNotifier]
/// below, which just remembers the last answer for the dashboard banner.
class UpdateCheckResult {
  final String currentVersion;
  final LatestVersionInfo? latest;
  final bool updateAvailable;

  const UpdateCheckResult({required this.currentVersion, this.latest, required this.updateAvailable});
}

/// Compares dotted version strings numerically per segment (so "1.9.0" <
/// "1.10.0", unlike a naive string/lexicographic compare) - a missing or
/// non-numeric segment counts as 0 rather than throwing, since the two
/// sides are typed in independently by a human in two different places
/// (this app's pubspec.yaml, and whatever the vendor enters into
/// generator.html's "Publish app update" card) that could disagree on
/// segment count.
bool isNewerVersion(String latest, String current) {
  final latestParts = latest.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final currentParts = current.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final length = latestParts.length > currentParts.length ? latestParts.length : currentParts.length;
  for (var i = 0; i < length; i++) {
    final l = i < latestParts.length ? latestParts[i] : 0;
    final c = i < currentParts.length ? currentParts[i] : 0;
    if (l != c) return l > c;
  }
  return false;
}

/// Remembers the last background check's result so the dashboard banner
/// (see dashboard_screen.dart) can show it reactively without every
/// screen re-querying the server itself - mirrors
/// PendingPaystackSalesNotifier's exact shape (starts empty/null rather
/// than loading, updated by an explicit call from app.dart's periodic
/// timer, not by watching a stream).
@Riverpod(keepAlive: true)
class UpdateAvailabilityNotifier extends _$UpdateAvailabilityNotifier {
  @override
  LatestVersionInfo? build() => null;

  Future<void> check() async {
    try {
      final result = await ref.read(updateServiceProvider).checkForUpdate();
      if (ref.mounted) applyResult(result);
    } catch (_) {
      // Silent by design - this runs unattended on app.dart's periodic
      // sync timer, right alongside licenseService.backgroundVerify(),
      // which has the identical "never let a connectivity hiccup
      // surface" contract. UpdateScreen's own manual "Check for
      // Updates" button calls checkForUpdate() directly instead, so the
      // user-initiated path still sees real errors.
    }
  }

  /// Lets a caller that already ran its own checkForUpdate() (UpdateScreen's
  /// manual "Check for Updates" button) push that fresh result straight
  /// into this shared cache instead of this notifier re-querying the
  /// server a second time - also what keeps the dashboard banner from
  /// showing a stale "update available" for up to 2 minutes after the
  /// user has already installed it or after a fresh check found none.
  void applyResult(UpdateCheckResult result) {
    state = result.updateAvailable ? result.latest : null;
  }
}

/// Online-activate-style one-tap update: [checkForUpdate] compares this
/// build's own version against nexapos_license's published app_version
/// row, and [install] downloads + applies it with no further user
/// interaction beyond the OS's own unavoidable prompts (Android's
/// package-installer confirmation, and - once, ever, per device -
/// approving "install unknown apps" for NexaPOS at the OS level).
class UpdateService {
  final Ref _ref;

  UpdateService(this._ref);

  Future<UpdateCheckResult> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final latest = await _ref.read(updateGatewayProvider).fetchLatestVersion();
    final available = latest != null && isNewerVersion(latest.version, packageInfo.version);
    return UpdateCheckResult(currentVersion: packageInfo.version, latest: latest, updateAvailable: available);
  }

  /// Downloads and installs [info] on this platform, reporting 0.0-1.0
  /// progress via [onProgress]. On Windows, success means the app has
  /// already called [exit] and handed off to a detached updater script -
  /// the caller only ever sees this function return on failure there. On
  /// Android it returns normally either way, since the OS installer runs
  /// as a separate activity on top of (not instead of) this app.
  Future<Result<void>> install(LatestVersionInfo info, {void Function(double progress)? onProgress}) {
    if (Platform.isWindows) return _installWindows(info, onProgress);
    if (Platform.isAndroid) return _installAndroid(info, onProgress);
    return Future.value(const Result.failure('One-tap update is not available on this platform yet.'));
  }

  Future<Result<void>> _installWindows(LatestVersionInfo info, void Function(double)? onProgress) async {
    if (info.windowsUrl.isEmpty) return const Result.failure('No Windows download is available for this update.');
    try {
      final tempDir = await getTemporaryDirectory();
      final stagingDir = Directory(path.join(tempDir.path, 'nexapos_update'));
      if (await stagingDir.exists()) await stagingDir.delete(recursive: true);
      await stagingDir.create(recursive: true);

      final zipFile = File(path.join(stagingDir.path, 'update.zip'));
      await _ref.read(updateGatewayProvider).downloadTo(
        info.windowsUrl,
        zipFile,
        onProgress: (received, total) {
          // Reserve the last 10% of the bar for extract+handoff, which
          // have no byte-level progress of their own to report.
          if (total != null && total > 0) onProgress?.call(received / total * 0.9);
        },
      );

      final checksumError = await _verifyChecksum(zipFile, info.windowsSha256);
      if (checksumError != null) return Result.failure(checksumError);

      final extractDir = Directory(path.join(stagingDir.path, 'extracted'));
      await extractFileToDisk(zipFile.path, extractDir.path);
      onProgress?.call(0.95);

      final exeName = path.basename(Platform.resolvedExecutable);
      // The zip's own internal layout (flat vs. wrapped in a top-level
      // folder) is whatever the vendor's build machine happened to
      // produce, not something this code controls - so locate the real
      // exe wherever it landed instead of assuming a fixed depth.
      final exeFile = await _findFile(extractDir, exeName);
      if (exeFile == null) {
        return Result.failure('The downloaded update looks corrupted ($exeName not found inside it).');
      }

      final installDir = File(Platform.resolvedExecutable).parent;
      final stagingBatFile = File(path.join(stagingDir.path, 'apply_update.bat'));
      await stagingBatFile.writeAsString(_windowsUpdaterScript(
        sourceDir: exeFile.parent.path,
        installDir: installDir.path,
        exeName: exeName,
        stagingDir: stagingDir.path,
      ));

      onProgress?.call(1.0);
      // /min so the brief handoff console window doesn't flash full-size;
      // detached so it survives this process exiting immediately after.
      await Process.start(
        'cmd.exe',
        ['/c', 'start', '', '/min', stagingBatFile.path],
        mode: ProcessStartMode.detached,
      );
      // The .bat's first step is a short wait before it touches anything
      // in installDir - but this process still has to have actually
      // exited by then, since Windows won't let the copy overwrite an
      // exe/dll this process itself is still holding open. There's no
      // safe way to keep running past this point, so this call really
      // does end the function (and the process).
      exit(0);
    } on UpdateOfflineException {
      return const Result.failure('Could not reach the download server. Check your internet connection and try again.');
    } on UpdateException catch (e) {
      return Result.failure(e.message);
    } catch (e) {
      return Result.failure('Could not install the update: $e');
    }
  }

  Future<Result<void>> _installAndroid(LatestVersionInfo info, void Function(double)? onProgress) async {
    if (info.androidUrl.isEmpty) return const Result.failure('No Android download is available for this update.');
    try {
      final tempDir = await getTemporaryDirectory();
      final apkFile = File(path.join(tempDir.path, 'NexaPOS-update.apk'));
      await _ref.read(updateGatewayProvider).downloadTo(
        info.androidUrl,
        apkFile,
        onProgress: (received, total) {
          if (total != null && total > 0) onProgress?.call(received / total);
        },
      );

      final checksumError = await _verifyChecksum(apkFile, info.androidSha256);
      if (checksumError != null) return Result.failure(checksumError);

      final result = await OpenFile.open(apkFile.path, type: 'application/vnd.android.package-archive');
      switch (result.type) {
        case ResultType.done:
          return const Result.ok(null);
        case ResultType.permissionDenied:
          return const Result.failure(
            'NexaPOS needs permission to install updates. In Settings, allow NexaPOS to "Install unknown apps", then tap Install again.',
          );
        case ResultType.noAppToOpen:
          return const Result.failure('No installer is available on this device.');
        case ResultType.fileNotFound:
          return const Result.failure('The downloaded update file went missing - try again.');
        case ResultType.error:
          return Result.failure(result.message);
      }
    } on UpdateOfflineException {
      return const Result.failure('Could not reach the download server. Check your internet connection and try again.');
    } on UpdateException catch (e) {
      return Result.failure(e.message);
    }
  }

  /// Guards against a compromised/hijacked download host, an on-path
  /// tamperer, or a plain URL typo silently swapping in different bytes
  /// than what the vendor actually published - none of that is stopped
  /// by HTTPS transport alone, which only protects against tampering
  /// *in transit* to whatever host answers for the URL, not the
  /// integrity of that host's own content. Deliberately does NOT fail
  /// when [expectedHex] is null - an older/rolled-back server response
  /// without a hash published yet must not brick updating entirely; it
  /// just means this specific safeguard is unavailable for that build.
  Future<String?> _verifyChecksum(File file, String? expectedHex) async {
    if (expectedHex == null) return null;
    final digest = await sha256.bind(file.openRead()).first;
    final actualHex = digest.toString();
    if (actualHex.toLowerCase() != expectedHex.toLowerCase()) {
      return 'The downloaded update failed an integrity check and was not installed. '
          'This could mean a network problem corrupted the download - try again, or contact support if it keeps happening.';
    }
    return null;
  }

  Future<File?> _findFile(Directory dir, String name) async {
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && path.basename(entity.path).toLowerCase() == name.toLowerCase()) {
        return entity;
      }
    }
    return null;
  }

  /// installDir is the live app - the one this very process is running
  /// out of - so nothing in this script can touch it until this process
  /// has actually released its file locks, which isn't instant just
  /// because the process has called exit() (confirmed for real: a
  /// deliberately-held exclusive lock on the exe reliably produces
  /// xcopy's "Sharing violation" / exit code 4 for as long as the lock
  /// is held). A single fixed wait then one xcopy attempt - the original
  /// design - meant that if the OS hadn't released the exe's lock by
  /// then, xcopy would still copy every OTHER file (the DLLs, data\)
  /// but skip the exe, relaunching a stale exe next to brand-new
  /// libraries. PackageInfo reads its version straight from the running
  /// exe's own resource block, so the app would then look permanently
  /// out of date to itself even though it had genuinely updated - this
  /// is the exact "old version still there on reopen" failure mode the
  /// logging below was originally added to help diagnose, but the
  /// underlying race was never actually closed until now. Retries the
  /// whole xcopy (not just the exe) up to 10 times, 1s apart, so a
  /// still-copied DLL isn't left half-newer-half-older either.
  ///
  /// Uses `ping -n N 127.0.0.1` instead of `timeout` for the delays -
  /// confirmed for real that `timeout` errors out immediately
  /// ("Input redirection is not supported") when its stdin isn't a real
  /// interactive console, which isn't guaranteed for a detached child
  /// process; ping's delay doesn't depend on console/stdin at all.
  ///
  /// `%ERRORLEVEL%` deliberately isn't read directly inside the `for`
  /// loop body - batch expands `%...%` once when a parenthesized block
  /// is parsed, not fresh on each iteration, so it would silently freeze
  /// at whatever ERRORLEVEL was before the loop even started (confirmed
  /// for real - it read 1 unchanged through all 10 attempts against a
  /// fix that was, per xcopy's own output, actually succeeding every
  /// time). `setlocal enabledelayedexpansion` plus `!EC!` reads the
  /// true per-iteration value instead.
  ///
  /// Logs each step to last_update_log.txt right next to the exe
  /// (survives stagingDir's own cleanup, since it's written to
  /// installDir instead) - this whole script runs invisibly in a
  /// detached process with no console the user or a debugger can watch,
  /// so without this log a real failure here would be a total black box.
  String _windowsUpdaterScript({
    required String sourceDir,
    required String installDir,
    required String exeName,
    required String stagingDir,
  }) {
    final log = '$installDir\\last_update_log.txt';
    return '@echo off\r\n'
        'setlocal enabledelayedexpansion\r\n'
        'echo [%DATE% %TIME%] Update starting > "$log"\r\n'
        'ping -n 3 127.0.0.1 > nul\r\n'
        'for /L %%i in (1,1,10) do (\r\n'
        '    echo [%DATE% %TIME%] Copy attempt %%i - "$sourceDir" to "$installDir" >> "$log"\r\n'
        '    xcopy "$sourceDir" "$installDir" /E /I /Y /Q >> "$log" 2>&1\r\n'
        '    set EC=!ERRORLEVEL!\r\n'
        '    echo [%DATE% %TIME%] xcopy exit code: !EC! >> "$log"\r\n'
        '    if "!EC!"=="0" goto copydone\r\n'
        '    ping -n 2 127.0.0.1 > nul\r\n'
        ')\r\n'
        ':copydone\r\n'
        'start "" "$installDir\\$exeName"\r\n'
        'echo [%DATE% %TIME%] Relaunched $exeName, cleaning up staging >> "$log"\r\n'
        'rmdir /S /Q "$stagingDir"\r\n';
  }
}
