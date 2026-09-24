import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/core/utils/monotonic_clock.dart';
import 'package:nexapos_mobile/domain/region/regions.dart';
import 'package:nexapos_mobile/domain/services/clock_health_service.dart';
import 'package:nexapos_mobile/domain/services/region_settings_service.dart';

import '../../support/fake_monotonic_clock.dart';
import '../../support/fake_secure_storage.dart';

const _serverDate = 'Fri, 25 Sep 2026 10:00:00 GMT';
final _serverTime = DateTime.utc(2026, 9, 25, 10);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FixedClock wall;
  late FakeMonotonicClock mono;
  late int requests;
  late http.Response Function() answer;
  late Duration deviceOffset;
  late ProviderContainer container;

  setUp(() {
    installFakeSecureStorage();
    wall = FixedClock(_serverTime);
    mono = FakeMonotonicClock();
    requests = 0;
    deviceOffset = const Duration(hours: 3);
    answer = () => http.Response(jsonEncode({'success': true}), 200, headers: {'date': _serverDate});
    container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(wall),
      monotonicClockProvider.overrideWithValue(mono),
      deviceUtcOffsetProvider.overrideWithValue(() => deviceOffset),
      trustedTimeServiceProvider.overrideWith(
        (ref) => TrustedTimeService(ref, client: MockClient((request) async {
          requests++;
          expect(request.url.queryParameters['action'], 'health');
          return answer();
        })),
      ),
    ]);
    addTearDown(container.dispose);
  });

  group('TrustedTimeService', () {
    test('reads the real time from the server\'s Date header and works out how wrong the device is', () async {
      wall.set(_serverTime.add(const Duration(hours: 3))); // the device is 3 hours ahead

      final reading = (await container.read(trustedTimeServiceProvider).read())!;

      // The header has whole-second resolution, so the true time is taken as
      // the middle of that second.
      expect(reading.serverUtc, _serverTime.add(const Duration(milliseconds: 500)));
      expect(reading.skew, const Duration(hours: 3) - const Duration(milliseconds: 500));
    });

    test('a device that is behind has a negative skew', () async {
      wall.set(_serverTime.subtract(const Duration(days: 40)));

      final reading = (await container.read(trustedTimeServiceProvider).read())!;

      expect(reading.skew.isNegative, isTrue);
      expect(reading.skew.abs() > const Duration(days: 39), isTrue);
    });

    test('half the round trip is allowed for the answer travelling back', () async {
      answer = () {
        mono.advance(const Duration(milliseconds: 400));
        return http.Response(jsonEncode({'success': true}), 200, headers: {'date': _serverDate});
      };

      final reading = (await container.read(trustedTimeServiceProvider).read())!;

      expect(reading.serverUtc, _serverTime.add(const Duration(milliseconds: 500 + 200)));
    });

    test('an answer that took too long says nothing reliable', () async {
      answer = () {
        mono.advance(const Duration(seconds: 20)); // a server waking from sleep
        return http.Response(jsonEncode({'success': true}), 200, headers: {'date': _serverDate});
      };

      expect(await container.read(trustedTimeServiceProvider).read(), isNull);
    });

    test('no Date header (a browser hides it), no reading', () async {
      answer = () => http.Response(jsonEncode({'success': true}), 200);

      expect(await container.read(trustedTimeServiceProvider).read(), isNull);
    });

    test('an unreachable server, no reading', () async {
      answer = () => throw const SocketException('no internet');

      expect(await container.read(trustedTimeServiceProvider).read(), isNull);
    });

    test('an error answer still carries the server\'s clock', () async {
      answer = () => http.Response('<html>502</html>', 502, headers: {'date': _serverDate});

      expect(await container.read(trustedTimeServiceProvider).read(), isNotNull);
    });

    test('the reading can be carried forward by the monotonic clock', () async {
      final reading = (await container.read(trustedTimeServiceProvider).read())!;

      mono.advance(const Duration(minutes: 5));

      final now = reading.serverUtc.add(mono.elapsed() - reading.takenAt);
      expect(now, _serverTime.add(const Duration(minutes: 5, milliseconds: 500)));
    });
  });

  group('ClockHealthNotifier.check', () {
    ClockHealthNotifier notifier() => container.read(clockHealthProvider.notifier);

    Future<void> chooseRegion(String code, {int zone = 0}) async {
      final region = regionByCode(code)!;
      await container.read(regionSettingsServiceProvider).save(RegionSettings(region: region, zone: region.zones[zone]));
    }

    test('nothing is known before the first check', () {
      expect(container.read(clockHealthProvider), isNull);
    });

    test('a clock that is right is no problem', () async {
      final health = (await notifier().check())!;

      expect(health.timeIsWrong, isFalse);
      expect(health.hasProblem, isFalse);
      expect(container.read(clockHealthProvider), same(health));
    });

    test('a clock that is hours ahead is wrong', () async {
      wall.set(_serverTime.add(const Duration(hours: 3, minutes: 12)));

      final health = (await notifier().check())!;

      expect(health.timeIsWrong, isTrue);
      expect(health.hasProblem, isTrue);
      expect(describeClockDifference(health.skew!), '3 hours 12 minutes');
    });

    test('a clock months behind is wrong', () async {
      wall.set(_serverTime.subtract(const Duration(days: 90)));

      expect((await notifier().check())!.timeIsWrong, isTrue);
    });

    test('a small difference is tolerated, a larger one is not', () async {
      wall.set(_serverTime.add(const Duration(minutes: 1)));
      expect((await notifier().check(force: true))!.timeIsWrong, isFalse);

      wall.set(_serverTime.add(const Duration(minutes: 3)));
      expect((await notifier().check(force: true))!.timeIsWrong, isTrue);
    });

    test('offline: the time cannot be judged, and that is not reported as a problem', () async {
      answer = () => throw const SocketException('no internet');

      final health = (await notifier().check())!;

      expect(health.skew, isNull);
      expect(health.timeIsWrong, isFalse);
      expect(health.hasProblem, isFalse);
    });

    test('with no region chosen the time zone is not judged', () async {
      deviceOffset = const Duration(hours: -8);

      final health = (await notifier().check())!;

      expect(health.regionSet, isFalse);
      expect(health.zoneDiffers, isFalse);
    });

    test('a device whose time zone fits the chosen region is fine', () async {
      await chooseRegion('KE');
      deviceOffset = const Duration(hours: 3);

      final health = (await notifier().check())!;

      expect(health.regionSet, isTrue);
      expect(health.zoneDiffers, isFalse);
    });

    test('a device set to the wrong time zone is reported', () async {
      await chooseRegion('KE');
      deviceOffset = Duration.zero; // Windows left on UTC, say

      final health = (await notifier().check())!;

      expect(health.zoneDiffers, isTrue);
      expect(health.hasProblem, isTrue);
      expect(health.timeIsWrong, isFalse, reason: 'the time itself can be right while the zone is wrong');
    });

    test('a region with daylight saving accepts both of its offsets', () async {
      await chooseRegion('GB');

      deviceOffset = Duration.zero;
      expect((await notifier().check(force: true))!.zoneDiffers, isFalse);
      deviceOffset = const Duration(hours: 1);
      expect((await notifier().check(force: true))!.zoneDiffers, isFalse);
      deviceOffset = const Duration(hours: 3);
      expect((await notifier().check(force: true))!.zoneDiffers, isTrue);
    });

    test('checks are spaced out: a second check soon after asks nothing new', () async {
      final first = await notifier().check();
      mono.advance(const Duration(minutes: 29));

      final second = await notifier().check();

      expect(requests, 1);
      expect(second, same(first));
    });

    test('...and it checks again once the interval has passed', () async {
      await notifier().check();
      mono.advance(clockCheckInterval + const Duration(seconds: 1));

      await notifier().check();

      expect(requests, 2);
    });

    test('force checks straight away', () async {
      await notifier().check();

      await notifier().check(force: true);

      expect(requests, 2);
    });

    test('a check that could not read the time is retried sooner than a good one', () async {
      answer = () => throw const SocketException('no internet');
      await notifier().check();
      mono.advance(clockRetryInterval + const Duration(seconds: 1));

      await notifier().check();

      expect(requests, 2);
      expect(clockRetryInterval < clockCheckInterval, isTrue);
    });

    test('two checks started together make one request', () async {
      final both = await Future.wait([notifier().check(), notifier().check()]);

      expect(requests, 1);
      expect(both[0], isNotNull);
    });
  });

  group('describeClockDifference', () {
    test('says how far off in the two biggest units', () {
      expect(describeClockDifference(const Duration(hours: 3, minutes: 12)), '3 hours 12 minutes');
      expect(describeClockDifference(const Duration(days: 2, hours: 5, minutes: 40)), '2 days 5 hours');
      expect(describeClockDifference(const Duration(hours: 1)), '1 hour');
      expect(describeClockDifference(const Duration(seconds: 70)), '1 minute');
      expect(describeClockDifference(const Duration(hours: 3, minutes: 11, seconds: 59, milliseconds: 500)), '3 hours 12 minutes');
      expect(describeClockDifference(const Duration(days: 1, minutes: 30)), '1 day 30 minutes');
    });

    test('ignores which way, and is honest when it is tiny', () {
      expect(describeClockDifference(const Duration(hours: -3)), '3 hours');
      expect(describeClockDifference(const Duration(seconds: 20)), 'under a minute');
    });
  });
}
