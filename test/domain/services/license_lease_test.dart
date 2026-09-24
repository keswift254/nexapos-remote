import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/domain/services/license_lease.dart';

import '../../support/fake_monotonic_clock.dart';

void main() {
  const sixMonths = Duration(days: 180);

  late FixedClock wall;
  late FakeMonotonicClock mono;
  late LeaseCountdown countdown;
  late LicenseLease lease;

  setUp(() {
    wall = FixedClock(DateTime.utc(2026, 1, 1));
    mono = FakeMonotonicClock();
    countdown = LeaseCountdown(wall, mono);
    lease = LicenseLease(remaining: sixMonths, accountedAt: wall.now());
  });

  /// Real time passing: the wall clock and the running-time clock both move.
  void pass(Duration duration) {
    wall.advance(duration);
    mono.advance(duration);
  }

  /// Someone editing the device's date and time: only the wall clock moves.
  void setClockBy(Duration change) => wall.advance(change);

  /// The app being closed and started again: the running-time clock starts
  /// over and nothing remembers where the previous run's reference was.
  void restartApp() {
    countdown = LeaseCountdown(wall, FakeMonotonicClock());
  }

  group('while the app is running', () {
    test('counts down with real time', () {
      lease = countdown.advance(lease); // establishes the reference
      pass(const Duration(days: 10));

      expect(countdown.advance(lease).remaining, sixMonths - const Duration(days: 10));
    });

    test('a clock set BACK changes nothing: the count keeps going and never gains time', () {
      lease = countdown.advance(lease);
      pass(const Duration(days: 1));
      setClockBy(const Duration(days: -30)); // e.g. to dodge the expiry

      expect(countdown.advance(lease).remaining, sixMonths - const Duration(days: 1),
          reason: 'setting the clock back must not add time back');

      pass(const Duration(days: 1));
      expect(countdown.advance(lease).remaining, sixMonths - const Duration(days: 2),
          reason: 'and the count carries on at the real rate afterwards');
    });

    test('a clock set back and then put right leaves no trace at all', () {
      lease = countdown.advance(lease);
      pass(const Duration(days: 1));
      setClockBy(const Duration(days: -60));
      pass(const Duration(hours: 1));
      expect(countdown.advance(lease).remaining, sixMonths - const Duration(days: 1, hours: 1));

      setClockBy(const Duration(days: 60)); // put right again

      expect(countdown.advance(lease).remaining, sixMonths - const Duration(days: 1, hours: 1));
    });

    test('a clock set FORWARD counts only while it stays forward - putting it right undoes it', () {
      lease = countdown.advance(lease);
      pass(const Duration(days: 1));
      setClockBy(const Duration(days: 30)); // a wrong date entered by accident

      expect(countdown.advance(lease).remaining, sixMonths - const Duration(days: 31));

      setClockBy(const Duration(days: -30)); // and corrected

      expect(countdown.advance(lease).remaining, sixMonths - const Duration(days: 1),
          reason: 'an accidental date change must not cost the license anything once corrected');
    });

    test('time the device slept (the wall clock moved, the running-time clock did not) still counts', () {
      lease = countdown.advance(lease);
      wall.advance(const Duration(hours: 8)); // lid closed overnight

      expect(countdown.advance(lease).remaining, sixMonths - const Duration(hours: 8));
    });

    test('runs out at zero, and stays there', () {
      lease = LicenseLease(remaining: const Duration(hours: 2), accountedAt: wall.now());
      lease = countdown.advance(lease);
      pass(const Duration(hours: 1, minutes: 59));
      expect(countdown.advance(lease).isExpired, isFalse);

      pass(const Duration(minutes: 1));
      final ended = countdown.advance(lease);
      expect(ended.remaining, Duration.zero);
      expect(ended.isExpired, isTrue);

      pass(const Duration(days: 5));
      expect(countdown.advance(ended).remaining, Duration.zero);
    });

    test('a license that never expires is never touched, whatever the clock does', () {
      final forever = LicenseLease(remaining: Duration.zero, accountedAt: wall.now(), neverExpires: true);
      pass(const Duration(days: 4000));
      setClockBy(const Duration(days: -900));

      final after = countdown.advance(forever);

      expect(after.neverExpires, isTrue);
      expect(after.isExpired, isFalse);
    });
  });

  group('when the app is started again', () {
    test('the time it was closed counts', () {
      lease = countdown.advance(lease);
      pass(const Duration(days: 3)); // closed for three days
      restartApp();

      expect(countdown.advance(lease).remaining, sixMonths - const Duration(days: 3));
    });

    test('a clock found set back is charged a day, not nothing (or restarting would stretch a license)', () {
      lease = countdown.advance(lease);
      setClockBy(const Duration(days: -30));
      restartApp();

      expect(countdown.advance(lease).remaining, sixMonths - leaseBackwardJumpPenalty);
    });

    test('winding the clock back before every start gains nothing', () {
      lease = countdown.advance(lease);
      for (var start = 1; start <= 3; start++) {
        setClockBy(const Duration(days: -30));
        restartApp();
        lease = countdown.advance(lease);
      }

      expect(lease.remaining, sixMonths - leaseBackwardJumpPenalty * 3);
    });

    test('a clock a few minutes behind (an automatic time correction) is not held against the device', () {
      lease = countdown.advance(lease);
      setClockBy(const Duration(minutes: -5));
      restartApp();

      expect(countdown.advance(lease).remaining, sixMonths);
    });
  });

  group('adopting a lease from the shop\'s main device', () {
    test('reset() makes the next reading start fresh from the lease it is given', () {
      lease = countdown.advance(lease);
      pass(const Duration(days: 40));
      lease = countdown.advance(lease);

      // The main device reports more time left (a renewal).
      lease = LicenseLease(remaining: const Duration(days: 365), accountedAt: wall.now());
      countdown.reset();
      pass(const Duration(hours: 1));

      expect(countdown.advance(lease).remaining, const Duration(days: 365) - const Duration(hours: 1));
    });
  });

  group('what is saved and what is sent', () {
    test('a lease survives being saved and read back', () {
      final back = LicenseLease.fromJson(lease.toJson())!;

      expect(back.remaining, lease.remaining);
      expect(back.accountedAt, lease.accountedAt);
      expect(back.neverExpires, isFalse);
    });

    test('an unreadable saved lease is ignored, not a crash', () {
      expect(LicenseLease.fromJson('nonsense'), isNull);
      expect(LicenseLease.fromJson({'remainingMs': 5}), isNull);
    });

    test('an offer carries only time left - no date crosses between devices', () {
      final offer = LeaseOffer(remaining: sixMonths);

      expect(offer.toJson().keys, unorderedEquals(['neverExpires', 'remainingMs']));
      expect(LeaseOffer.fromJson(offer.toJson())!.remaining, sixMonths);
      expect(LeaseOffer.fromJson({'neverExpires': true, 'remainingMs': 0})!.neverExpires, isTrue);
      expect(LeaseOffer.fromJson('junk'), isNull);
    });
  });
}
