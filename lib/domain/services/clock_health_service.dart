import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/providers.dart';
import '../../core/utils/monotonic_clock.dart';
import '../../data/licensing/license_gateway.dart' show licenseServerBaseUrl;
import '../../data/payments/platform_http_client.dart';
import 'region_settings_service.dart';

/// How far the device clock may differ from the real time before it counts as
/// wrong. Generous on purpose: the server's time is read to the second and the
/// round trip is estimated, so anything tighter would flag honest devices.
const clockSkewTolerance = Duration(minutes: 2);

/// How often the app re-checks its clock while it runs.
const clockCheckInterval = Duration(minutes: 30);

/// How soon it tries again after a check that could not read the real time
/// (offline).
const clockRetryInterval = Duration(minutes: 5);

/// A round trip slower than this says nothing reliable about the time (a server
/// waking from sleep, a very bad connection), so the reading is thrown away.
const _maxRoundTrip = Duration(seconds: 8);

/// The real time, as the license server's own clock told it.
class ServerTimeReading {
  const ServerTimeReading({
    required this.serverUtc,
    required this.deviceUtc,
    required this.takenAt,
  });

  /// The server's time at the instant the answer arrived here.
  final DateTime serverUtc;

  /// This device's own clock at that same instant.
  final DateTime deviceUtc;

  /// The monotonic clock at that instant - lets the reading be carried forward
  /// ("the real time now is [serverUtc] plus what has passed since") without
  /// trusting the device clock again.
  final Duration takenAt;

  /// How far ahead of the real time the device clock is (negative: behind).
  Duration get skew => deviceUtc.difference(serverUtc);
}

/// Asks the license server what time it is - the one source of the real time a
/// device has that its owner cannot change from the date-and-time settings.
/// Nothing is sent but an ordinary health-check request; the answer's HTTP
/// `Date` header is the time.
class TrustedTimeService {
  TrustedTimeService(this._ref, {http.Client? client})
    : _client = client ?? http.Client();

  final Ref _ref;
  final http.Client _client;

  /// Null when the server cannot be reached, sends no readable clock (a browser
  /// hides the header from a page on another site), or answered too slowly to
  /// say anything precise.
  Future<ServerTimeReading?> read() async {
    final monotonic = _ref.read(monotonicClockProvider);
    final clock = _ref.read(clockProvider);
    final started = monotonic.elapsed();
    DateTime? stamped;
    try {
      await platformRequest(
        _client,
        'GET',
        'health',
        licenseServerBaseUrl,
        timeout: const Duration(seconds: 12),
        onServerTime: (t) => stamped = t,
      );
    } on PaystackOfflineException {
      return null;
    } on PaystackException {
      // An error answer still carries the server's clock.
    } catch (_) {
      // Best effort: whatever went wrong, there is no reading.
      return null;
    }
    final arrived = monotonic.elapsed();
    final roundTrip = arrived - started;
    final serverStamp = stamped;
    if (serverStamp == null || roundTrip > _maxRoundTrip) return null;
    // The header has whole-second resolution (the true stamp lies in the second
    // that follows it: +0.5 s), and the answer was on its way back for about
    // half the round trip.
    final serverUtc = serverStamp.add(
      const Duration(milliseconds: 500) + roundTrip ~/ 2,
    );
    return ServerTimeReading(
      serverUtc: serverUtc,
      deviceUtc: clock.now().toUtc(),
      takenAt: arrived,
    );
  }
}

final trustedTimeServiceProvider = Provider<TrustedTimeService>(
  (ref) => TrustedTimeService(ref),
);

/// What the device's own time zone setting is, as an offset from UTC. Injectable
/// so a test can say what a device reports.
final deviceUtcOffsetProvider = Provider<Duration Function()>(
  (ref) =>
      () => DateTime.now().timeZoneOffset,
);

/// What one clock check found.
class ClockHealth {
  const ClockHealth({
    required this.checkedAt,
    this.skew,
    this.zoneDiffers = false,
    this.regionSet = false,
    this.deviceOffset,
  });

  /// When the check ran, on the monotonic clock.
  final Duration checkedAt;

  /// Device clock minus real time; null when it could not be measured (no
  /// internet, or the platform hides the server's clock).
  final Duration? skew;

  /// The device's time zone offset does not fit the region the shop chose.
  final bool zoneDiffers;

  /// A region has been chosen at all (without one, the zone is not judged).
  final bool regionSet;

  final Duration? deviceOffset;

  bool get timeIsWrong => skew != null && skew!.abs() > clockSkewTolerance;
  bool get hasProblem => timeIsWrong || zoneDiffers;
}

/// "3 hours 12 minutes" - for telling a shop owner how far off a clock is.
String describeClockDifference(Duration difference) {
  // To the nearest minute: a second or two either way must not turn
  // "3 hours 12 minutes" into "3 hours 11".
  final minutes = (difference.abs().inSeconds / 60).round();
  if (minutes < 1) return 'under a minute';
  var remaining = Duration(minutes: minutes);
  final parts = <String>[];
  void take(String unit, Duration size) {
    final count = remaining.inMicroseconds ~/ size.inMicroseconds;
    if (count == 0) return;
    remaining -= size * count;
    parts.add('$count $unit${count == 1 ? '' : 's'}');
  }

  take('day', const Duration(days: 1));
  if (parts.isEmpty || parts.length == 1) take('hour', const Duration(hours: 1));
  if (parts.length < 2) take('minute', const Duration(minutes: 1));
  return parts.take(2).join(' ');
}

/// Checks the device clock against the real time and against the region the
/// shop chose, at most every [clockCheckInterval] unless asked to.
class ClockHealthNotifier extends Notifier<ClockHealth?> {
  bool _running = false;

  @override
  ClockHealth? build() => null;

  /// Runs a check unless one was made recently (or is under way); returns what
  /// is known afterwards. [force] skips the wait - for a person pressing
  /// "Check now", or right after a fix.
  Future<ClockHealth?> check({bool force = false}) async {
    if (_running) return state;
    final monotonic = ref.read(monotonicClockProvider);
    final last = state;
    if (!force &&
        last != null &&
        monotonic.elapsed() - last.checkedAt <
            (last.skew == null ? clockRetryInterval : clockCheckInterval)) {
      return last;
    }
    _running = true;
    try {
      final reading = await ref.read(trustedTimeServiceProvider).read();
      if (!ref.mounted) return null;
      final settings = await ref.read(regionSettingsServiceProvider).load();
      if (!ref.mounted) return null;
      final offset = ref.read(deviceUtcOffsetProvider)();
      final health = ClockHealth(
        checkedAt: monotonic.elapsed(),
        skew: reading?.skew,
        regionSet: settings != null,
        zoneDiffers: settings != null && !settings.zone.matchesOffset(offset),
        deviceOffset: offset,
      );
      state = health;
      return health;
    } finally {
      _running = false;
    }
  }

  @visibleForTesting
  void debugSet(ClockHealth? value) => state = value;
}

final clockHealthProvider =
    NotifierProvider<ClockHealthNotifier, ClockHealth?>(
      ClockHealthNotifier.new,
    );
