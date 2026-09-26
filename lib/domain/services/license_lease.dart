import '../../core/utils/clock.dart';
import '../../core/utils/monotonic_clock.dart';

/// How far the wall clock may read BEHIND the last time the countdown was
/// updated before it counts as the clock having been set back. Small drifts
/// (an automatic time sync correcting a few seconds) are not tampering.
const leaseClockTolerance = Duration(minutes: 10);

/// What is charged against the countdown when the app starts and finds the
/// clock set back by more than [leaseClockTolerance]: the time the app was
/// closed is unknowable then, so a whole day is assumed. Charging nothing would
/// let anyone stretch a license by winding the clock back before every start;
/// a day makes that pointless, and costs an honest device (a dead clock battery
/// that resets the date) a day per occurrence.
const leaseBackwardJumpPenalty = Duration(hours: 24);

/// The license end date a joined device inherits from the shop's main device,
/// held as TIME LEFT (a duration), never as a date. A duration cannot be
/// changed by editing the device's date, and it is what devices exchange:
/// each one counts its own copy down from the moment it receives it.
class LicenseLease {
  const LicenseLease({
    required this.remaining,
    required this.accountedAt,
    this.neverExpires = false,
    this.stamp,
  });

  /// Trusted time left as of [accountedAt].
  final Duration remaining;

  /// The wall clock when [remaining] was last brought up to date. Only ever
  /// compared with a later reading of the same clock, to find how long the app
  /// was closed - it is not a date anyone relies on.
  final DateTime accountedAt;

  final bool neverExpires;

  /// The moment (ms since 1970, by the LICENSE SERVER's clock) the shop's main
  /// device last had the license server vouch for this state. It is what puts two
  /// statements about the shop's license in order: the one with the later stamp is
  /// the newer word from the main device, so it wins - whether it gives the shop
  /// more time or less (an expiry, a revoke). Null on a lease that came from a
  /// version that did not stamp it; such a lease can only ever be extended.
  final int? stamp;

  bool get isExpired => !neverExpires && remaining <= Duration.zero;

  LicenseLease copyWith({Duration? remaining, DateTime? accountedAt}) =>
      LicenseLease(
        remaining: remaining ?? this.remaining,
        accountedAt: accountedAt ?? this.accountedAt,
        neverExpires: neverExpires,
        stamp: stamp,
      );

  Map<String, dynamic> toJson() => {
    'neverExpires': neverExpires,
    'remainingMs': remaining.inMilliseconds,
    'accountedAt': accountedAt.toUtc().toIso8601String(),
    if (stamp != null) 'stamp': stamp,
  };

  static LicenseLease? fromJson(Object? decoded) {
    if (decoded is! Map) return null;
    final accountedAt = DateTime.tryParse(
      decoded['accountedAt'] as String? ?? '',
    );
    final remainingMs = decoded['remainingMs'];
    if (accountedAt == null || remainingMs is! num) return null;
    final stamp = decoded['stamp'];
    return LicenseLease(
      remaining: Duration(milliseconds: remainingMs.toInt()),
      accountedAt: accountedAt,
      neverExpires: decoded['neverExpires'] == true,
      stamp: stamp is num ? stamp.toInt() : null,
    );
  }
}

/// A lease as sent between devices (over the shop's network): just the time
/// left, in the sender's own trusted count, and the [stamp] that says how recent
/// the main device's word behind it is. No date crosses the wire.
///
/// A zero [remaining] means "the shop's license has ended" - said on purpose so
/// that devices holding some time left are told, not just left to count it down.
class LeaseOffer {
  const LeaseOffer({
    required this.remaining,
    this.neverExpires = false,
    this.stamp,
  });

  final Duration remaining;
  final bool neverExpires;

  /// See [LicenseLease.stamp].
  final int? stamp;

  Map<String, dynamic> toJson() => {
    'neverExpires': neverExpires,
    'remainingMs': remaining.inMilliseconds,
    if (stamp != null) 'stamp': stamp,
  };

  static LeaseOffer? fromJson(Object? decoded) {
    if (decoded is! Map) return null;
    final remainingMs = decoded['remainingMs'];
    if (remainingMs is! num) return null;
    final stamp = decoded['stamp'];
    return LeaseOffer(
      remaining: Duration(milliseconds: remainingMs.toInt()),
      neverExpires: decoded['neverExpires'] == true,
      stamp: stamp is num ? stamp.toInt() : null,
    );
  }
}

/// Counts a [LicenseLease] down so that changing the device's date and time
/// cannot make the time left change. Two clocks are used together:
///
///  * the monotonic clock (how long the app has been running) - immune to any
///    date-and-time change, but it only exists while the app runs and, on some
///    systems, stands still while the device sleeps; and
///  * the wall clock - the only thing that can measure time while the app is
///    closed or the device sleeps, but changeable by anyone.
///
/// While the app runs, the time counted since it last looked is the LARGER of
/// the two readings:
///  * a clock set BACK cannot give time back - the monotonic clock keeps
///    counting - and when it is set forward again the count is exactly what it
///    would have been (nothing is left over from the jump);
///  * a clock set FORWARD counts only for as long as it stays forward. It is
///    impossible to tell that apart from the device really having slept, and it
///    can only ever shorten a license, never extend one.
/// When the app starts, the time it was closed is the wall-clock gap since the
/// last update. A gap that runs BACKWARDS (beyond [leaseClockTolerance]) is
/// charged [leaseBackwardJumpPenalty] instead of nothing, see there.
///
/// Whenever the shop's main device shares its own count, the receiving device
/// simply adopts it (see LicenseService.acceptLease) - so whatever error the
/// clock accumulated in between is wiped out the next time the two meet.
class LeaseCountdown {
  LeaseCountdown(this._clock, this._monotonic);

  final Clock _clock;
  final MonotonicClock _monotonic;

  // Fixed when the app starts (or a new lease is adopted) and never edited:
  // every later reading is measured against these, not against the previous
  // reading, so a jump followed by its undo leaves no trace.
  DateTime? _anchorWall;
  Duration? _anchorMonotonic;
  Duration? _anchorRemaining;

  /// Forget the running reference; the next [advance] starts a new one from
  /// whatever lease it is given. Call after adopting a different lease.
  void reset() {
    _anchorWall = null;
    _anchorMonotonic = null;
    _anchorRemaining = null;
  }

  /// Brings [lease] up to date with the present and returns it.
  LicenseLease advance(LicenseLease lease) {
    final wallNow = _clock.now();
    if (lease.neverExpires) return lease.copyWith(accountedAt: wallNow);

    final monotonicNow = _monotonic.elapsed();
    Duration remaining;
    if (_anchorWall == null) {
      final gap = wallNow.difference(lease.accountedAt);
      final charged = gap > -leaseClockTolerance
          ? (gap.isNegative ? Duration.zero : gap)
          : leaseBackwardJumpPenalty;
      remaining = lease.remaining - charged;
      _anchorWall = wallNow;
      _anchorMonotonic = monotonicNow;
      _anchorRemaining = remaining;
    } else {
      final byMonotonic = monotonicNow - _anchorMonotonic!;
      final byWall = wallNow.difference(_anchorWall!);
      remaining =
          _anchorRemaining! - (byWall > byMonotonic ? byWall : byMonotonic);
    }
    if (remaining.isNegative) remaining = Duration.zero;
    return lease.copyWith(remaining: remaining, accountedAt: wallNow);
  }
}
