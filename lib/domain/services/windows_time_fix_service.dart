import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../core/providers.dart';
import '../../core/result.dart';
import '../../core/utils/monotonic_clock.dart';
import '../../data/update/update_gateway.dart';
import 'clock_health_service.dart';
import 'license_service.dart';
import 'region_settings_service.dart';
import 'update_service.dart' show updateGatewayProvider;
import 'windows_installer_launcher_native.dart'
    if (dart.library.js_interop) 'windows_installer_launcher_stub.dart'
    as installer_launcher;

/// Where the small elevated helper that sets the clock is hosted (the same
/// fast host as the update patches), and the SHA-256 of the exact file there.
/// The app refuses to run anything that does not match - the same rule the
/// updater follows for everything it runs elevated. Change both together
/// whenever release-tools/NexaPosTimeFix.cs is rebuilt.
const timeFixToolUrl =
    'https://nexapos-downloads.condojuniur.workers.dev/NexaPosTimeFix.exe';
const timeFixToolSha256 =
    'd0dcde8d5246539fea497315041cc2487c1ca128cc19991645388b61ee7f2ff2';

/// What the helper reported back.
class TimeFixReport {
  const TimeFixReport({
    required this.ok,
    required this.timeSet,
    required this.zoneSet,
    required this.syncConfigured,
    this.errors = const [],
    this.warnings = const [],
  });

  final bool ok;
  final bool timeSet;
  final bool zoneSet;

  /// Windows was set up to keep the clock right by itself from now on.
  final bool syncConfigured;
  final List<String> errors;
  final List<String> warnings;

  static TimeFixReport? fromJson(Object? decoded) {
    if (decoded is! Map) return null;
    List<String> strings(Object? value) => value is List
        ? [for (final item in value) item.toString()]
        : const <String>[];
    return TimeFixReport(
      ok: decoded['ok'] == true,
      timeSet: decoded['timeSet'] == true,
      zoneSet: decoded['zoneSet'] == true,
      syncConfigured: decoded['syncConfigured'] == true,
      errors: strings(decoded['errors']),
      warnings: strings(decoded['warnings']),
    );
  }
}

/// "Fix the clock" on Windows: reads the real time from the license server,
/// then has a small helper (one UAC prompt) set the device's clock and time
/// zone and switch on Windows' own time sync. The app itself cannot change the
/// system clock - it does not run as administrator.
///
/// Everything outside the helper is injectable so it can be tested without
/// touching a real clock.
class WindowsTimeFixService {
  WindowsTimeFixService(
    this._ref, {
    this._download,
    this._launch,
    this._tempDirectory,
    this.toolUrl = timeFixToolUrl,
    this.toolSha256 = timeFixToolSha256,
    this.pollInterval = const Duration(milliseconds: 500),
    this.waitTimeout = const Duration(seconds: 90),
  });

  final Ref _ref;
  final Future<Uint8List> Function(String url)? _download;
  final void Function(String exePath, String arguments)? _launch;
  final Future<Directory> Function()? _tempDirectory;
  final String toolUrl;
  final String toolSha256;
  final Duration pollInterval;
  final Duration waitTimeout;

  static const _maxToolBytes = 2 * 1024 * 1024;

  Future<Result<TimeFixReport>> fixNow() async {
    // 1. What the real time is - from the server, never from this device.
    final reading = await _ref.read(trustedTimeServiceProvider).read();
    if (reading == null) {
      return const Result.failure(
        'Could not read the real time. Connect to the internet and try again.',
      );
    }

    // 2. The helper, exactly the file this build was made for.
    final Uint8List toolBytes;
    try {
      toolBytes = await (_download ??
          _ref.read(updateGatewayProvider).downloadBytes)(toolUrl);
    } on UpdateOfflineException {
      return const Result.failure(
        'Could not download the clock tool. Check your internet connection and try again.',
      );
    } on UpdateException catch (e) {
      return Result.failure(e.message);
    } catch (e) {
      return Result.failure('Could not download the clock tool: $e');
    }
    if (toolBytes.length > _maxToolBytes ||
        sha256.convert(toolBytes).toString().toLowerCase() !=
            toolSha256.toLowerCase()) {
      return const Result.failure(
        'The downloaded clock tool is not the expected file, so it was not run.',
      );
    }

    final directory = await (_tempDirectory ?? getTemporaryDirectory)();
    final toolFile = File(path.join(directory.path, 'NexaPosTimeFix.exe'));
    final resultFile = File(
      path.join(directory.path, 'nexapos-timefix-result.json'),
    );
    try {
      await toolFile.writeAsBytes(toolBytes, flush: true);
      if (await resultFile.exists()) await resultFile.delete();
    } catch (e) {
      return Result.failure('Could not prepare the clock tool: $e');
    }

    // 3. Run it - inside the license service's clock-correction window, so the
    // jump it is about to make is not charged to the license as time passing.
    final settings = await _ref.read(regionSettingsServiceProvider).load();
    final monotonic = _ref.read(monotonicClockProvider);
    final clock = _ref.read(clockProvider);
    TimeFixReport? report;
    String? failure;
    await _ref.read(licenseServiceProvider).withClockCorrection(() async {
      // The real time as of this instant, carried forward from the reading by
      // the monotonic clock, and the device's own clock at the same instant:
      // the helper works out for itself how long the permission prompt took.
      final trustedNow = reading.serverUtc.add(
        monotonic.elapsed() - reading.takenAt,
      );
      final arguments = [
        '--utc ${_stamp(trustedNow)}',
        '--issued ${_stamp(clock.now())}',
        if (settings != null) '--zone "${settings.zone.windowsId}"',
        '--result "${resultFile.path}"',
      ].join(' ');
      try {
        final launch =
            _launch ??
            (String exe, String args) => installer_launcher
                .launchWindowsInstallerElevated(exe, arguments: args);
        launch(toolFile.path, arguments);
      } catch (_) {
        failure =
            'Windows did not give permission to change the clock. Try again '
            'and choose Yes when Windows asks.';
        return;
      }
      final deadline = monotonic.elapsed() + waitTimeout;
      while (monotonic.elapsed() < deadline) {
        if (await resultFile.exists()) {
          try {
            report = TimeFixReport.fromJson(
              jsonDecode(await resultFile.readAsString()),
            );
          } catch (_) {
            // Not fully written yet, or unreadable - look again.
            await Future<void>.delayed(pollInterval);
            continue;
          }
          if (report != null) return;
        }
        await Future<void>.delayed(pollInterval);
      }
      failure = 'The clock tool did not report back. The clock may not have '
          'been changed - check it and try again.';
    });

    final done = report;
    if (failure != null || done == null) {
      return Result.failure(failure ?? 'The clock tool did not report back.');
    }
    // Look again right away, so the warning goes (or says what is left).
    try {
      await _ref.read(clockHealthProvider.notifier).check(force: true);
    } catch (_) {
      // The fix itself is done; the next routine check will catch up.
    }
    if (!done.ok) {
      return Result.failure(
        done.errors.isEmpty
            ? 'The clock could not be fixed.'
            : done.errors.join(' '),
      );
    }
    return Result.ok(done);
  }

  /// "2026-09-25T10:15:30Z": whole seconds, the one form the helper reads.
  static String _stamp(DateTime value) {
    final utc = value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-'
        '${two(utc.day)}T${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}Z';
  }
}

final windowsTimeFixServiceProvider = Provider<WindowsTimeFixService>(
  (ref) => WindowsTimeFixService(ref),
);
