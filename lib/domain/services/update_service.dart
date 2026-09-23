import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/legacy_windows_edition.dart';
import '../../core/result.dart';
import '../../data/update/update_gateway.dart';
import 'windows_installer_launcher_native.dart'
    if (dart.library.js_interop) 'windows_installer_launcher_stub.dart'
    as installer_launcher;

part 'update_service.g.dart';

@Riverpod(keepAlive: true)
UpdateGateway updateGateway(Ref ref) => UpdateGateway();

@Riverpod(keepAlive: true)
UpdateService updateService(Ref ref) => UpdateService(ref);

/// Whether this is the Windows 7/8 edition - a provider (not just the
/// compile-time constant) so tests can exercise both editions.
final legacyWindowsEditionProvider = Provider<bool>(
  (ref) => kLegacyWindowsEdition,
);

/// Result the caller of build "does a newer build exist" once the vendor's
/// server has been asked - separate from [UpdateAvailabilityNotifier]
/// below, which just remembers the last answer for the dashboard banner.
class UpdateCheckResult {
  final String currentVersion;
  final LatestVersionInfo? latest;
  final bool updateAvailable;

  const UpdateCheckResult({
    required this.currentVersion,
    this.latest,
    required this.updateAvailable,
  });
}

/// Compares dotted version strings numerically per segment (so "1.9.0" <
/// "1.10.0", unlike a naive string/lexicographic compare) - a missing or
/// non-numeric segment counts as 0 rather than throwing, since the two
/// sides are typed in independently by a human in two different places
/// (this app's pubspec.yaml, and whatever the vendor enters into
/// generator.html's "Publish app update" card) that could disagree on
/// segment count.
bool isNewerVersion(String latest, String current) {
  final latestParts = latest
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final currentParts = current
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final length = latestParts.length > currentParts.length
      ? latestParts.length
      : currentParts.length;
  for (var i = 0; i < length; i++) {
    final l = i < latestParts.length ? latestParts[i] : 0;
    final c = i < currentParts.length ? currentParts[i] : 0;
    if (l != c) return l > c;
  }
  return false;
}

String? publishedChecksumError(String? expectedHex) {
  if (expectedHex == null || expectedHex.isEmpty) {
    return 'This update has no integrity checksum and cannot be installed safely. Contact support.';
  }
  if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(expectedHex)) {
    return 'This update has an invalid integrity checksum and cannot be installed safely. Contact support.';
  }
  return null;
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
    // The Windows 7/8 edition only updates from its own installer. A release
    // published without one is not an update for it: offering the banner
    // would just end in "no download available" on every check.
    final hasInstallerForThisEdition =
        !_ref.read(legacyWindowsEditionProvider) ||
        (latest?.windowsLegacyInstallerUrl.isNotEmpty ?? false);
    final available =
        latest != null &&
        hasInstallerForThisEdition &&
        isNewerVersion(latest.version, packageInfo.version);
    return UpdateCheckResult(
      currentVersion: packageInfo.version,
      latest: latest,
      updateAvailable: available,
    );
  }

  /// Downloads and installs [info] on this platform, reporting 0.0-1.0
  /// progress via [onProgress]. On Windows, success means the app has
  /// already called [exit] and handed off to a detached updater script -
  /// the caller only ever sees this function return on failure there. On
  /// Android it returns normally either way, since the OS installer runs
  /// as a separate activity on top of (not instead of) this app.
  Future<Result<void>> install(
    LatestVersionInfo info, {
    void Function(double progress)? onProgress,
  }) {
    if (Platform.isWindows) return _installWindows(info, onProgress);
    if (Platform.isAndroid) return _installAndroid(info, onProgress);
    return Future.value(
      const Result.failure(
        'One-tap update is not available on this platform yet.',
      ),
    );
  }

  Future<Result<void>> _installWindows(
    LatestVersionInfo info,
    void Function(double)? onProgress,
  ) async {
    final legacy = _ref.read(legacyWindowsEditionProvider);
    final url = legacy ? info.windowsLegacyInstallerUrl : info.windowsInstallerUrl;
    if (url.isEmpty) {
      return Result.failure(
        legacy
            ? 'No Windows 7/8 download is available for this update yet.'
            : 'No Windows download is available for this update.',
      );
    }
    return _installWindowsSetup(
      url,
      legacy ? info.windowsLegacyInstallerSha256 : info.windowsInstallerSha256,
      onProgress,
    );
  }

  Future<Result<void>> _installWindowsSetup(
    String url,
    String? sha256,
    void Function(double)? onProgress,
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final setupFile = File(path.join(tempDir.path, 'NexaPOS-setup.exe'));
      await _ref
          .read(updateGatewayProvider)
          .downloadTo(
            url,
            setupFile,
            onProgress: (received, total) {
              if (total != null && total > 0) {
                onProgress?.call(received / total * 0.9);
              }
            },
          );
      final checksumError = await _verifyChecksum(setupFile, sha256);
      if (checksumError != null) return Result.failure(checksumError);
      onProgress?.call(1.0);
      installer_launcher.launchWindowsInstallerElevated(setupFile.path);
      exit(0);
    } on UpdateOfflineException {
      return const Result.failure(
        'Could not reach the download server. Check your internet connection and try again.',
      );
    } on UpdateException catch (e) {
      return Result.failure(e.message);
    } catch (e) {
      return Result.failure('Could not start the Windows installer: $e');
    }
  }

  Future<Result<void>> _installAndroid(
    LatestVersionInfo info,
    void Function(double)? onProgress,
  ) async {
    if (info.androidUrl.isEmpty) {
      return const Result.failure(
        'No Android download is available for this update.',
      );
    }
    await _AndroidDownloadNotification.start('Downloading update...');
    try {
      final tempDir = await getTemporaryDirectory();
      final apkFile = File(path.join(tempDir.path, 'NexaPOS-update.apk'));
      var lastNotifiedPercent = -1;
      await _ref
          .read(updateGatewayProvider)
          .downloadTo(
            info.androidUrl,
            apkFile,
            onProgress: (received, total) {
              if (total != null && total > 0) {
                onProgress?.call(received / total);
                final percent = (received / total * 100).floor().clamp(0, 100);
                if (percent != lastNotifiedPercent) {
                  lastNotifiedPercent = percent;
                  _AndroidDownloadNotification.update(
                    'Downloading update... $percent%',
                    percent,
                  );
                }
              }
            },
          );

      final checksumError = await _verifyChecksum(apkFile, info.androidSha256);
      if (checksumError != null) return Result.failure(checksumError);

      final result = await OpenFile.open(
        apkFile.path,
        type: 'application/vnd.android.package-archive',
      );
      switch (result.type) {
        case ResultType.done:
          return const Result.ok(null);
        case ResultType.permissionDenied:
          return const Result.failure(
            'NexaPOS needs permission to install updates. In Settings, allow NexaPOS to "Install unknown apps", then tap Install again.',
          );
        case ResultType.noAppToOpen:
          return const Result.failure(
            'No installer is available on this device.',
          );
        case ResultType.fileNotFound:
          return const Result.failure(
            'The downloaded update file went missing - try again.',
          );
        case ResultType.error:
          return Result.failure(result.message);
      }
    } on UpdateOfflineException {
      return const Result.failure(
        'Could not reach the download server. Check your internet connection and try again.',
      );
    } on UpdateException catch (e) {
      return Result.failure(e.message);
    } finally {
      // Always runs - success, a handled failure above, or an unexpected
      // exception propagating out - so the notification never lingers
      // after the app stops actually downloading anything.
      await _AndroidDownloadNotification.stop();
    }
  }

  /// Guards against a compromised/hijacked download host, an on-path
  /// tamperer, or a plain URL typo silently swapping in different bytes
  /// than what the vendor actually published - none of that is stopped
  /// by HTTPS transport alone, which only protects against tampering
  /// *in transit* to whatever host answers for the URL, not the
  /// integrity of that host's own content. A missing or malformed hash
  /// is a hard failure: installing executable code without the promised
  /// integrity check is more dangerous than asking the user to contact
  /// support for an old or incorrectly-published release.
  Future<String?> _verifyChecksum(File file, String? expectedHex) async {
    final metadataError = publishedChecksumError(expectedHex);
    if (metadataError != null) return metadataError;
    final digest = await sha256.bind(file.openRead()).first;
    final actualHex = digest.toString();
    if (actualHex.toLowerCase() != expectedHex!.toLowerCase()) {
      return 'The downloaded update failed an integrity check and was not installed. '
          'This could mean a network problem corrupted the download - try again, or contact support if it keeps happening.';
    }
    return null;
  }
}

class UpdateInstallState {
  const UpdateInstallState({
    this.installing = false,
    this.progress = 0,
    this.error,
    this.info,
  });

  final bool installing;
  final double progress;
  final String? error;
  // Carried here (not just left for UpdateScreen's own checkForUpdate()
  // result) so a screen re-created after navigating away and back can
  // show what's actually being installed without needing to re-check -
  // the point of keeping this state alive in the first place.
  final LatestVersionInfo? info;

  UpdateInstallState copyWith({double? progress}) {
    return UpdateInstallState(
      installing: installing,
      progress: progress ?? this.progress,
      error: error,
      info: info,
    );
  }
}

/// Owns the in-flight download/install Future instead of UpdateScreen's
/// own State - that used to live as plain widget state, so navigating
/// away (e.g. back to the dashboard) and returning built a brand new
/// UpdateScreen with no idea a download was already running: the
/// button reappeared as "Download & Install" even though the actual
/// download was never really cancelled (nothing about disposing a
/// widget stops an in-flight Future), just orphaned from any UI. Worse,
/// tapping the button again from that fresh screen started a second,
/// concurrent download to the exact same temp file path. keepAlive so
/// this survives exactly the navigation that used to lose it.
@Riverpod(keepAlive: true)
class UpdateInstallNotifier extends _$UpdateInstallNotifier {
  Future<void>? _inFlight;

  @override
  UpdateInstallState build() => const UpdateInstallState();

  /// No-ops if a download is already running rather than erroring - the
  /// button that calls this is only ever shown when state.installing is
  /// false, but this stays safe even if something calls it twice anyway.
  void start(LatestVersionInfo info) {
    if (_inFlight != null) return;
    state = UpdateInstallState(installing: true, info: info);
    _inFlight = _run(info).whenComplete(() => _inFlight = null);
  }

  Future<void> _run(LatestVersionInfo info) async {
    final result = await ref
        .read(updateServiceProvider)
        .install(info, onProgress: (p) => state = state.copyWith(progress: p));
    // On Windows, a successful install() has already called exit(0) -
    // this line is unreached there. Android reaches here either way.
    result.when(
      ok: (_) => state = const UpdateInstallState(),
      failure: (message) => state = UpdateInstallState(error: message, info: info),
    );
  }
}

/// Bridges to DownloadForegroundService (android/app/src/main/kotlin/...) -
/// a persistent "Downloading update..." notification that keeps this app's
/// process at Android's foreground-priority tier for as long as the update
/// download is running. Without it, the download previously had no
/// protection from Android's own background app management, or a phone
/// maker's more aggressive battery-saving mode, and could be killed just
/// from the user switching away from NexaPOS mid-download. A no-op on
/// every other platform - the native side of this channel only exists in
/// the Android app.
class _AndroidDownloadNotification {
  static const _channel = MethodChannel('com.nexapos/download_service');

  static Future<void> start(String text) {
    if (!Platform.isAndroid) return Future.value();
    return _channel
        .invokeMethod('start', {'text': text})
        .catchError((_) {});
  }

  static Future<void> update(String text, int progressPercent) {
    if (!Platform.isAndroid) return Future.value();
    return _channel
        .invokeMethod('update', {'text': text, 'progress': progressPercent})
        .catchError((_) {});
  }

  static Future<void> stop() {
    if (!Platform.isAndroid) return Future.value();
    return _channel.invokeMethod('stop').catchError((_) {});
  }
}
