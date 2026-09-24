import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/secure_storage_provider.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/core/utils/monotonic_clock.dart';
import 'package:nexapos_mobile/data/licensing/license_gateway.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import '../../support/fake_monotonic_clock.dart';
import '../../support/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installFakeSecureStorage);

  ProviderContainer buildContainer({
    required http.Client licenseClient,
    required Clock clock,
    FakeMonotonicClock? mono,
  }) {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) {
        final db = AppDatabase(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
      licenseGatewayProvider.overrideWith((ref) => LicenseGateway(licenseClient)),
      clockProvider.overrideWith((ref) => clock),
      if (mono != null) monotonicClockProvider.overrideWithValue(mono),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('approved authenticator reset is device-local and cannot replay after reenrollment', () async {
    var generation = 1;
    var valid = true;
    final container = buildContainer(clock: FixedClock(DateTime.utc(2026)),
      licenseClient: MockClient((request) async => http.Response(jsonEncode({
        'success': true, 'valid': valid, 'authenticator_generation': generation,
      }), 200)));
    final storage = container.read(secureStorageProvider);
    await storage.write(key: 'nexapos.license.activationToken', value: 'licensed-token');
    await storage.write(key: 'nexapos.security.admin', value: 'old-secret');
    await storage.write(key: 'unrelated', value: 'keep');
    final service = container.read(licenseServiceProvider);
    await service.checkAuthenticatorReset();
    expect(await storage.read(key: 'nexapos.security.admin'), isNull);
    expect(await storage.read(key: 'unrelated'), 'keep');
    await storage.write(key: 'nexapos.security.admin', value: 'new-secret');
    await service.checkAuthenticatorReset();
    expect(await storage.read(key: 'nexapos.security.admin'), 'new-secret');
    generation = 2;
    valid = false;
    await expectLater(service.checkAuthenticatorReset(), throwsStateError);
    expect(await storage.read(key: 'nexapos.security.admin'), 'new-secret');
  });

  test('a license with no valid_until (never expires) stays licensed no matter how far the clock advances', () async {
    final clock = FixedClock(DateTime.utc(2026, 1, 1));
    final container = buildContainer(
      clock: clock,
      licenseClient: MockClient((request) async {
        return http.Response(jsonEncode({'success': true, 'activation_token': 'a' * 64, 'valid_until': null}), 200);
      }),
    );
    final service = container.read(licenseServiceProvider);
    await service.activate('CODE1');

    clock.advance(const Duration(days: 3650));

    expect(await service.hasValidCachedLicense(), isTrue);
  });

  test('a license with a future valid_until is licensed', () async {
    final clock = FixedClock(DateTime.utc(2026, 1, 1));
    final container = buildContainer(
      clock: clock,
      licenseClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'success': true, 'activation_token': 'a' * 64, 'valid_until': '2026-01-31 00:00:00'}),
          200,
        );
      }),
    );
    final service = container.read(licenseServiceProvider);
    await service.activate('CODE1');

    clock.set(DateTime.utc(2026, 1, 15));

    expect(await service.hasValidCachedLicense(), isTrue);
  });

  test('hasValidCachedLicense deactivates fully offline once the local clock passes valid_until', () async {
    final clock = FixedClock(DateTime.utc(2026, 1, 1));
    final container = buildContainer(
      clock: clock,
      licenseClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'success': true, 'activation_token': 'a' * 64, 'valid_until': '2026-01-31 00:00:00'}),
          200,
        );
      }),
    );
    final service = container.read(licenseServiceProvider);
    await service.activate('CODE1');
    expect(await service.hasValidCachedLicense(), isTrue);

    clock.set(DateTime.utc(2026, 2, 1));

    // No network call happens in this check at all - that's the point:
    // the deadline is enforced from the device's own cached clock.
    expect(await service.hasValidCachedLicense(), isFalse);
  });

  test('backgroundVerify clears the license once its count has run out and the server cannot be reached', () async {
    final clock = FixedClock(DateTime.utc(2026, 1, 1));
    var verifyCalls = 0;
    final container = buildContainer(
      clock: clock,
      licenseClient: MockClient((request) async {
        if (request.url.queryParameters['action'] == 'activate') {
          return http.Response(
            jsonEncode({'success': true, 'activation_token': 'a' * 64, 'valid_until': '2026-01-31 00:00:00'}),
            200,
          );
        }
        verifyCalls++;
        throw const SocketException('no internet');
      }),
    );
    final service = container.read(licenseServiceProvider);
    await service.activate('CODE1');

    clock.set(DateTime.utc(2026, 2, 1));
    await service.backgroundVerify();

    expect(verifyCalls, 1, reason: 'the server is asked first, in case only the date was wrong');
    expect(await service.hasValidCachedLicense(), isFalse);
    expect(
      await container.read(secureStorageProvider).read(key: 'nexapos.license.activationToken'),
      isNull,
      reason: 'offline, a license that has run out must really end',
    );
  });

  test('a device whose date jumped far forward gets its license back from the server, not locked out', () async {
    final clock = FixedClock(DateTime.utc(2026, 1, 1));
    final container = buildContainer(
      clock: clock,
      mono: FakeMonotonicClock(),
      licenseClient: MockClient((request) async {
        if (request.url.queryParameters['action'] == 'activate') {
          return http.Response(
            jsonEncode({'success': true, 'activation_token': 'a' * 64, 'valid_until': '2026-01-31 00:00:00'}),
            200,
          );
        }
        // The server's own clock says it is 5 January.
        return http.Response(
          jsonEncode({'success': true, 'valid': true, 'valid_until': '2026-01-31 00:00:00'}),
          200,
          headers: {'date': 'Mon, 05 Jan 2026 00:00:00 GMT'},
        );
      }),
    );
    final service = container.read(licenseServiceProvider);
    await service.activate('CODE1');

    clock.set(DateTime.utc(2030, 6, 1)); // somebody set the date years ahead
    expect(await service.hasValidCachedLicense(), isFalse);
    await service.backgroundVerify();

    expect(await service.hasValidCachedLicense(), isTrue);
    final status = await service.currentStatus(askServer: false);
    expect(status.state, LicenseState.active);
    expect(status.remaining, const Duration(days: 26));
  });

  test('a device whose date is wrong still gets the true time left from the server clock at activation', () async {
    final clock = FixedClock(DateTime.utc(2027, 1, 1)); // a year ahead of the real date
    final container = buildContainer(
      clock: clock,
      mono: FakeMonotonicClock(),
      licenseClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'success': true, 'activation_token': 'a' * 64, 'valid_until': '2026-01-31 00:00:00'}),
          200,
          headers: {'date': 'Thu, 01 Jan 2026 00:00:00 GMT'},
        );
      }),
    );
    final service = container.read(licenseServiceProvider);

    await service.activate('CODE1');

    expect(await service.hasValidCachedLicense(), isTrue);
    expect((await service.currentStatus(askServer: false)).remaining, const Duration(days: 30));
  });

  test('backgroundVerify refreshes the cached deadline from a reachable server (e.g. a renewal)', () async {
    final clock = FixedClock(DateTime.utc(2026, 1, 1));
    final container = buildContainer(
      clock: clock,
      licenseClient: MockClient((request) async {
        if (request.url.queryParameters['action'] == 'activate') {
          return http.Response(
            jsonEncode({'success': true, 'activation_token': 'a' * 64, 'valid_until': '2026-01-31 00:00:00'}),
            200,
          );
        }
        return http.Response(
          jsonEncode({'success': true, 'valid': true, 'valid_until': '2026-06-01 00:00:00'}),
          200,
        );
      }),
    );
    final service = container.read(licenseServiceProvider);
    await service.activate('CODE1');

    clock.set(DateTime.utc(2026, 1, 20));
    await service.backgroundVerify();

    clock.set(DateTime.utc(2026, 2, 15));
    expect(await service.hasValidCachedLicense(), isTrue);
  });

  test('winding the device clock back after the license ran out does not bring it back', () async {
    final clock = FixedClock(DateTime.utc(2026, 1, 1));
    final container = buildContainer(
      clock: clock,
      licenseClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'success': true, 'activation_token': 'a' * 64, 'valid_until': '2026-01-31 00:00:00'}),
          200,
        );
      }),
    );
    final service = container.read(licenseServiceProvider);
    await service.activate('CODE1');
    clock.set(DateTime.utc(2026, 2, 15)); // genuinely past valid_until
    expect(await service.hasValidCachedLicense(), isFalse);

    // Wind the clock back to BEFORE valid_until, as a real attempt to dodge the
    // expiry would.
    clock.set(DateTime.utc(2026, 1, 20));

    expect(await service.hasValidCachedLicense(), isFalse);
  });

  group('the time left is counted, so changing the date and time does not change it', () {
    late FixedClock wall;
    late FakeMonotonicClock mono;
    late ProviderContainer container;
    late LicenseService service;

    void pass(Duration duration) {
      wall.advance(duration);
      mono.advance(duration);
    }

    Future<Duration?> remaining() async => (await service.currentStatus(askServer: false)).remaining;

    setUp(() async {
      wall = FixedClock(DateTime.utc(2026, 1, 1));
      mono = FakeMonotonicClock();
      container = buildContainer(
        clock: wall,
        mono: mono,
        licenseClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'success': true, 'activation_token': 'a' * 64, 'valid_until': '2026-01-31 00:00:00'}),
            200,
          );
        }),
      );
      service = container.read(licenseServiceProvider);
      await service.activate('CODE1');
    });

    test('time passing counts down normally', () async {
      expect(await remaining(), const Duration(days: 30));

      pass(const Duration(days: 10));

      expect(await remaining(), const Duration(days: 20));
    });

    test('setting the clock BACK does not give any time back', () async {
      pass(const Duration(days: 10));

      wall.set(wall.now().subtract(const Duration(days: 30))); // the date is wound back a month
      pass(const Duration(days: 1));

      expect(await remaining(), const Duration(days: 19));
      expect(await service.hasValidCachedLicense(), isTrue);
    });

    test('setting it back and then forward again leaves the count exactly what it should be', () async {
      pass(const Duration(days: 10));
      wall.set(wall.now().subtract(const Duration(days: 30)));
      pass(const Duration(days: 5));
      wall.set(wall.now().add(const Duration(days: 30)));

      expect(await remaining(), const Duration(days: 15));
    });

    test('a clock wound back a little is not treated as tampering either', () async {
      pass(const Duration(days: 10));
      wall.set(wall.now().subtract(const Duration(minutes: 5))); // an automatic time sync

      expect(await remaining(), const Duration(days: 20));
    });

    test('a date set forward and put right again while the app runs costs nothing', () async {
      pass(const Duration(days: 10));
      wall.set(wall.now().add(const Duration(days: 60)));
      expect(await service.hasValidCachedLicense(), isFalse, reason: 'while it stays forward it counts');
      wall.set(wall.now().subtract(const Duration(days: 60)));

      // It ran out while the date was wrong, so it stays out until the server
      // (or a new activation) says otherwise: nobody gains by trying it.
      expect(await service.hasValidCachedLicense(), isFalse);
    });

    test('a clock set back while the app is closed is charged a day, not given as free time', () async {
      pass(const Duration(days: 10));
      expect(await remaining(), const Duration(days: 20)); // saved

      // "Restart": a new service reading the same saved data, on a device whose
      // date was wound back a month while the app was closed.
      final restartedWall = FixedClock(wall.now().subtract(const Duration(days: 30)));
      final restarted = buildContainer(
        clock: restartedWall,
        mono: FakeMonotonicClock(),
        licenseClient: MockClient((request) async => http.Response('{}', 500)),
      ).read(licenseServiceProvider);

      final status = await restarted.currentStatus(askServer: false);

      expect(status.remaining, const Duration(days: 19));
    });

    test('a restart with the clock moved forward charges the time that seems to have passed', () async {
      pass(const Duration(days: 10));
      expect(await remaining(), const Duration(days: 20));

      final restartedWall = FixedClock(wall.now().add(const Duration(days: 7)));
      final restarted = buildContainer(
        clock: restartedWall,
        mono: FakeMonotonicClock(),
        licenseClient: MockClient((request) async => http.Response('{}', 500)),
      ).read(licenseServiceProvider);

      expect((await restarted.currentStatus(askServer: false)).remaining, const Duration(days: 13));
    });
  });

  test('an extension from the server is carried even when the server sends no clock', () async {
    final wall = FixedClock(DateTime.utc(2026, 1, 1));
    final mono = FakeMonotonicClock();
    var extended = false;
    final container = buildContainer(
      clock: wall,
      mono: mono,
      licenseClient: MockClient((request) async {
        if (request.url.queryParameters['action'] == 'activate') {
          return http.Response(
            jsonEncode({'success': true, 'activation_token': 'a' * 64, 'valid_until': '2026-01-31 00:00:00'}),
            200,
          );
        }
        return http.Response(
          jsonEncode({'success': true, 'valid': true, 'valid_until': extended ? '2026-03-02 00:00:00' : '2026-01-31 00:00:00'}),
          200,
        );
      }),
    );
    final service = container.read(licenseServiceProvider);
    await service.activate('CODE1');
    wall.advance(const Duration(days: 10));
    mono.advance(const Duration(days: 10));

    await service.backgroundVerify();
    expect((await service.currentStatus(askServer: false)).remaining, const Duration(days: 20), reason: 'a routine check with no change leaves the count alone');

    extended = true;
    await service.backgroundVerify();

    expect((await service.currentStatus(askServer: false)).remaining, const Duration(days: 50));
  });

  test('a device saved before counting existed starts its count from the saved end date', () async {
    final wall = FixedClock(DateTime.utc(2026, 1, 15));
    final container = buildContainer(
      clock: wall,
      mono: FakeMonotonicClock(),
      licenseClient: MockClient((request) async => http.Response('{}', 500)),
    );
    final storage = container.read(secureStorageProvider);
    await storage.write(key: 'nexapos.license.activationToken', value: 'a' * 64);
    await storage.write(key: 'nexapos.license.validUntil', value: DateTime.utc(2026, 1, 31).toIso8601String());
    final service = container.read(licenseServiceProvider);

    expect(await service.hasValidCachedLicense(), isTrue);
    expect((await service.currentStatus(askServer: false)).remaining, const Duration(days: 16));
  });

  test('a small clock adjustment within tolerance is not treated as a rollback attempt', () async {
    final clock = FixedClock(DateTime.utc(2026, 1, 1, 12, 0, 0));
    final container = buildContainer(
      clock: clock,
      licenseClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'success': true, 'activation_token': 'a' * 64, 'valid_until': '2026-01-31 00:00:00'}),
          200,
        );
      }),
    );
    final service = container.read(licenseServiceProvider);
    await service.activate('CODE1');

    // A few minutes backward (e.g. an NTP correction) - well within the
    // 10-minute tolerance, must not falsely lock a legitimate user out.
    clock.set(DateTime.utc(2026, 1, 1, 11, 55, 0));

    expect(await service.hasValidCachedLicense(), isTrue);
  });

  test('a never-expiring license (no valid_until) is unaffected by clock rollback - nothing to dodge', () async {
    final clock = FixedClock(DateTime.utc(2026, 1, 1));
    final container = buildContainer(
      clock: clock,
      licenseClient: MockClient((request) async {
        return http.Response(jsonEncode({'success': true, 'activation_token': 'a' * 64, 'valid_until': null}), 200);
      }),
    );
    final service = container.read(licenseServiceProvider);
    await service.activate('CODE1');
    clock.set(DateTime.utc(2026, 6, 1));
    expect(await service.hasValidCachedLicense(), isTrue);

    clock.set(DateTime.utc(2026, 1, 5)); // rolled back, but there's no deadline to protect

    expect(await service.hasValidCachedLicense(), isTrue);
  });

  test('activating a fresh code with no cached deadline yet is not treated as expired', () async {
    final clock = FixedClock(DateTime.utc(2026, 1, 1));
    final container = buildContainer(
      clock: clock,
      licenseClient: MockClient((request) async {
        return http.Response(jsonEncode({'success': true, 'activation_token': 'a' * 64}), 200);
      }),
    );
    final service = container.read(licenseServiceProvider);

    final result = await service.activate('CODE1');

    expect(result.isOk, isTrue);
    expect(await service.hasValidCachedLicense(), isTrue);
  });

  group('currentStatus (Settings > License)', () {
    // The activate call answers with [activatedUntil]; every verify call after
    // that is answered by whatever [verifyAnswer] currently returns.
    late int verifyCalls;
    late http.Response Function() verifyAnswer;
    late FixedClock clock;

    ProviderContainer build({String? activatedUntil = '2026-01-31 00:00:00'}) {
      verifyCalls = 0;
      verifyAnswer = () => http.Response(
        jsonEncode({'success': true, 'valid': true, 'valid_until': activatedUntil}),
        200,
      );
      clock = FixedClock(DateTime.utc(2026, 1, 1));
      return buildContainer(
        clock: clock,
        licenseClient: MockClient((request) async {
          if (request.url.queryParameters['action'] == 'verify') {
            verifyCalls++;
            return verifyAnswer();
          }
          return http.Response(
            jsonEncode({'success': true, 'activation_token': 'a' * 64, 'valid_until': activatedUntil}),
            200,
          );
        }),
      );
    }

    http.Response invalid(String? validUntil) =>
        http.Response(jsonEncode({'success': true, 'valid': false, 'valid_until': validUntil}), 200);

    test('a live license is active, with the end date the SERVER just reported', () async {
      final container = build();
      final service = container.read(licenseServiceProvider);
      await service.activate('CODE1');
      // The vendor extended it since activation.
      verifyAnswer = () => http.Response(
        jsonEncode({'success': true, 'valid': true, 'valid_until': '2026-03-01 12:00:00'}),
        200,
      );

      final status = await service.currentStatus();

      expect(status.state, LicenseState.active);
      expect(status.validUntil, DateTime.utc(2026, 3, 1, 12));
      expect(status.checkedWithServer, isTrue);
    });

    test('a license with no end date never expires', () async {
      final container = build(activatedUntil: null);
      final service = container.read(licenseServiceProvider);
      await service.activate('CODE1');

      final status = await service.currentStatus();

      expect(status.state, LicenseState.active);
      expect(status.validUntil, isNull);
    });

    test('invalid with an end date already past means it ran out: expired', () async {
      final container = build();
      final service = container.read(licenseServiceProvider);
      await service.activate('CODE1');
      clock.set(DateTime.utc(2026, 2, 5));
      verifyAnswer = () => invalid('2026-01-31 00:00:00');

      final status = await service.currentStatus();

      expect(status.state, LicenseState.expired);
      expect(status.validUntil, DateTime.utc(2026, 1, 31));
    });

    test('invalid while time is still left means the vendor ended it: revoked', () async {
      final container = build();
      final service = container.read(licenseServiceProvider);
      await service.activate('CODE1');
      verifyAnswer = () => invalid('2026-01-31 00:00:00');

      final status = await service.currentStatus();

      expect(status.state, LicenseState.revoked);
    });

    test('invalid for a never-expiring license is revoked too', () async {
      final container = build(activatedUntil: null);
      final service = container.read(licenseServiceProvider);
      await service.activate('CODE1');
      verifyAnswer = () => invalid(null);

      expect((await service.currentStatus()).state, LicenseState.revoked);
    });

    test('offline: shows what is saved and says it was not confirmed', () async {
      final container = build();
      final service = container.read(licenseServiceProvider);
      await service.activate('CODE1');
      verifyAnswer = () => throw const SocketException('no internet');

      final status = await service.currentStatus();

      expect(status.state, LicenseState.active);
      expect(status.validUntil, DateTime.utc(2026, 1, 31));
      expect(status.checkedWithServer, isFalse);
    });

    test('offline with a saved end date already past: expired, no server needed', () async {
      final container = build();
      final service = container.read(licenseServiceProvider);
      await service.activate('CODE1');
      clock.set(DateTime.utc(2026, 2, 5));
      verifyAnswer = () => throw const SocketException('no internet');

      final status = await service.currentStatus();

      expect(status.state, LicenseState.expired);
      expect(status.checkedWithServer, isFalse);
    });

    test('a server error does not make a good license look bad', () async {
      final container = build();
      final service = container.read(licenseServiceProvider);
      await service.activate('CODE1');
      verifyAnswer = () => http.Response(jsonEncode({'success': false, 'message': 'boom'}), 500);

      expect((await service.currentStatus()).state, LicenseState.active);
    });

    test('askServer: false never contacts the server', () async {
      final container = build();
      final service = container.read(licenseServiceProvider);
      await service.activate('CODE1');

      final status = await service.currentStatus(askServer: false);

      expect(verifyCalls, 0);
      expect(status.state, LicenseState.active);
      expect(status.checkedWithServer, isFalse);
    });

    test('is read-only: seeing "revoked" does not clear the saved license', () async {
      final container = build();
      final service = container.read(licenseServiceProvider);
      await service.activate('CODE1');
      verifyAnswer = () => invalid('2026-01-31 00:00:00');

      await service.currentStatus();

      expect(await container.read(secureStorageProvider).read(key: 'nexapos.license.activationToken'), isNotNull);
      expect(await service.hasValidCachedLicense(), isTrue);
    });

    test('a device that joined a shop reports it, with when it last confirmed', () async {
      final container = build();
      final storage = container.read(secureStorageProvider);
      await storage.write(
        key: 'nexapos.license.shopMembership',
        value: jsonEncode({
          'shopId': 7,
          'deviceId': 'd',
          'verifiedAt': DateTime.utc(2025, 12, 31, 20).toIso8601String(),
          'blocked': false,
        }),
      );

      final status = await container.read(licenseServiceProvider).currentStatus();

      expect(status.state, LicenseState.joined);
      expect(status.joinedVerifiedAt, DateTime.utc(2025, 12, 31, 20));
      expect(verifyCalls, 0);
    });

    test('a blocked membership is revoked; nothing at all is not activated', () async {
      final container = build();
      final service = container.read(licenseServiceProvider);
      expect((await service.currentStatus()).state, LicenseState.notActivated);

      await container.read(secureStorageProvider).write(
        key: 'nexapos.license.shopMembership',
        value: jsonEncode({'blocked': true}),
      );
      expect((await service.currentStatus()).state, LicenseState.revoked);
    });
  });

  group('endedLicense (why the app locked - shown on the activation screen)', () {
    late FixedClock clock;
    late http.Response Function() verifyAnswer;
    late String? activationUntil;
    late ProviderContainer container;
    late LicenseService service;

    Future<String?> storedToken() =>
        container.read(secureStorageProvider).read(key: 'nexapos.license.activationToken');

    Future<void> activate({String? until = '2026-01-31 00:00:00'}) async {
      activationUntil = until;
      await service.activate('CODE1');
    }

    http.Response invalid(String? validUntil) =>
        http.Response(jsonEncode({'success': true, 'valid': false, 'valid_until': validUntil}), 200);

    setUp(() {
      clock = FixedClock(DateTime.utc(2026, 1, 1));
      activationUntil = '2026-01-31 00:00:00';
      verifyAnswer = () => http.Response(
        jsonEncode({'success': true, 'valid': true, 'valid_until': activationUntil}),
        200,
      );
      container = buildContainer(
        clock: clock,
        licenseClient: MockClient((request) async {
          if (request.url.queryParameters['action'] == 'verify') return verifyAnswer();
          return http.Response(
            jsonEncode({'success': true, 'activation_token': 'a' * 64, 'valid_until': activationUntil}),
            200,
          );
        }),
      );
      service = container.read(licenseServiceProvider);
    });

    test('a device that was never licensed has nothing to report', () async {
      expect(await service.endedLicense(), isNull);
    });

    test('a licensed, healthy device has nothing to report', () async {
      await activate();
      await service.backgroundVerify();

      expect(await service.endedLicense(), isNull);
    });

    test('running out is recorded when the app locks, and survives the token being cleared', () async {
      await activate();
      clock.set(DateTime.utc(2026, 2, 5));

      await service.backgroundVerify();

      expect(await storedToken(), isNull, reason: 'the license really was cleared');
      final end = await service.endedLicense();
      expect(end!.reason, LicenseEndReason.expired);
      expect(end.validUntil, DateTime.utc(2026, 1, 31));
      expect(end.noticedAt, DateTime.utc(2026, 2, 5));
    });

    test('the server reporting an end date already past is recorded as expired', () async {
      await activate();
      clock.set(DateTime.utc(2026, 1, 15)); // saved end date (31 Jan) is still ahead locally
      verifyAnswer = () => invalid('2026-01-10 00:00:00');

      await service.backgroundVerify();

      final end = await service.endedLicense();
      expect(end!.reason, LicenseEndReason.expired);
      expect(end.validUntil, DateTime.utc(2026, 1, 10));
    });

    test('the server ending a license that still had time left is recorded as revoked', () async {
      await activate();
      verifyAnswer = () => invalid('2026-01-31 00:00:00');

      await service.backgroundVerify();

      expect(await storedToken(), isNull);
      expect((await service.endedLicense())!.reason, LicenseEndReason.revoked);
    });

    test('a rolled-back clock neither ends the license nor is reported as an ended one', () async {
      await activate(until: '2026-04-01 00:00:00');
      clock.set(DateTime.utc(2026, 3, 15));
      await service.hasValidCachedLicense(); // the device sees March 15th...
      clock.set(DateTime.utc(2026, 2, 1)); // ...then its clock is wound back

      await service.backgroundVerify();

      expect(await service.endedLicense(), isNull);
      expect(await storedToken(), isNotNull);
      expect(await service.hasValidCachedLicense(), isTrue);
    });

    test('an expired license is already explained BEFORE the background check clears it, and nothing changes', () async {
      await activate();
      clock.set(DateTime.utc(2026, 2, 5));

      final end = await service.endedLicense();

      expect(end!.reason, LicenseEndReason.expired);
      expect(await storedToken(), isNotNull, reason: 'asking must not clear the license');
    });

    test('activating again removes the notice', () async {
      await activate();
      clock.set(DateTime.utc(2026, 2, 5));
      await service.backgroundVerify();
      expect(await service.endedLicense(), isNotNull);

      await activate(until: '2026-03-01 00:00:00'); // renewed

      expect(await service.endedLicense(), isNull);
    });

    test('an unreadable saved record is ignored rather than breaking the screen', () async {
      await container.read(secureStorageProvider).write(key: 'nexapos.license.lastEnd', value: '{not json');

      expect(await service.endedLicense(), isNull);
    });
  });

  group('joinedShopNeedsInternet (activation-screen notice for a joined device)', () {
    late FixedClock clock;
    late ProviderContainer container;
    late LicenseService service;

    setUp(() {
      clock = FixedClock(DateTime.utc(2026, 1, 10, 12));
      container = buildContainer(
        clock: clock,
        licenseClient: MockClient((request) async => http.Response(
          jsonEncode({'success': true, 'activation_token': 'a' * 64, 'valid_until': null}),
          200,
        )),
      );
      service = container.read(licenseServiceProvider);
    });

    Future<void> joined({required DateTime verifiedAt, String? deviceId, bool blocked = false}) async {
      await container.read(secureStorageProvider).write(
        key: 'nexapos.license.shopMembership',
        value: jsonEncode({
          'shopId': 7,
          'deviceId': deviceId ?? await container.read(syncMetadataProvider).deviceId(),
          'verifiedAt': verifiedAt.toIso8601String(),
          'blocked': blocked,
        }),
      );
    }

    test('a device that never joined a shop has nothing to be told', () async {
      expect(await service.joinedShopNeedsInternet(), isFalse);
    });

    test('a membership confirmed within the last 24 hours is fine - the device still has access', () async {
      await joined(verifiedAt: clock.now().subtract(const Duration(hours: 23, minutes: 59)));

      expect(await service.hasAppAccess(), isTrue);
      expect(await service.joinedShopNeedsInternet(), isFalse);
    });

    test('once 24 hours have passed without a confirmation it needs the internet, and that is exactly when it locks', () async {
      await joined(verifiedAt: clock.now().subtract(const Duration(hours: 24)));

      expect(await service.hasAppAccess(), isFalse);
      expect(await service.joinedShopNeedsInternet(), isTrue);
    });

    test('days without a confirmation: still just "needs the internet" - the record is kept', () async {
      await joined(verifiedAt: clock.now().subtract(const Duration(days: 3)));

      expect(await service.joinedShopNeedsInternet(), isTrue);
      expect(await container.read(secureStorageProvider).read(key: 'nexapos.license.shopMembership'), isNotNull,
          reason: 'a network failure must never remove the membership');
    });

    test('a confirmed removal is not the same thing and gets no "connect" notice', () async {
      await joined(verifiedAt: clock.now().subtract(const Duration(days: 3)), blocked: true);

      expect(await service.joinedShopNeedsInternet(), isFalse);
    });

    test('a clock set back before the last confirmation also needs a fresh online check', () async {
      await joined(verifiedAt: clock.now().add(const Duration(hours: 1)));

      expect(await service.hasAppAccess(), isFalse);
      expect(await service.joinedShopNeedsInternet(), isTrue);
    });

    test('a device that also holds its own valid license is not locked, so no notice', () async {
      await service.activate('CODE1'); // never expires
      await joined(verifiedAt: clock.now().subtract(const Duration(days: 3)));

      expect(await service.hasAppAccess(), isTrue);
      expect(await service.joinedShopNeedsInternet(), isFalse);
    });

    test('a membership recorded for a different device needs a fresh online check too', () async {
      await joined(verifiedAt: clock.now(), deviceId: 'some-other-device');

      expect(await service.hasAppAccess(), isFalse);
      expect(await service.joinedShopNeedsInternet(), isTrue);
    });
  });
}
