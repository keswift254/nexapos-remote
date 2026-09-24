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
import 'package:nexapos_mobile/data/licensing/license_gateway.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import '../../support/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installFakeSecureStorage);

  ProviderContainer buildContainer({required http.Client licenseClient, required Clock clock}) {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) {
        final db = AppDatabase(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
      licenseGatewayProvider.overrideWith((ref) => LicenseGateway(licenseClient)),
      clockProvider.overrideWith((ref) => clock),
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

  test('backgroundVerify clears the license once locally expired without ever touching the network', () async {
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
        throw StateError('backgroundVerify must not call verify() once the cached deadline has already passed');
      }),
    );
    final service = container.read(licenseServiceProvider);
    await service.activate('CODE1');

    clock.set(DateTime.utc(2026, 2, 1));
    await service.backgroundVerify();

    expect(verifyCalls, 0);
    expect(await service.hasValidCachedLicense(), isFalse);
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

  test('rolling the device clock back past valid_until is still treated as expired (clock-rollback protection)', () async {
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
    clock.set(DateTime.utc(2026, 2, 15)); // genuinely past valid_until - watermark advances to here
    expect(await service.hasValidCachedLicense(), isFalse);

    // Wind the clock back to BEFORE valid_until, as a real attempt to
    // dodge the expiry would - without the rollback watermark, this
    // would read as "not expired yet" again since 2026-01-20 < 2026-01-31.
    clock.set(DateTime.utc(2026, 1, 20));

    expect(await service.hasValidCachedLicense(), isFalse);
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

  test('once real time genuinely catches back up past the rollback watermark, the license is trusted again', () async {
    final clock = FixedClock(DateTime.utc(2026, 1, 1));
    final container = buildContainer(
      clock: clock,
      licenseClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'success': true, 'activation_token': 'a' * 64, 'valid_until': '2026-06-01 00:00:00'}),
          200,
        );
      }),
    );
    final service = container.read(licenseServiceProvider);
    await service.activate('CODE1');
    clock.set(DateTime.utc(2026, 3, 1)); // watermark advances to here
    await service.hasValidCachedLicense();

    clock.set(DateTime.utc(2026, 2, 1)); // rolled back - flagged
    expect(await service.hasValidCachedLicense(), isFalse);

    clock.set(DateTime.utc(2026, 3, 15)); // genuinely past the old watermark again, still before valid_until
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

    test('a rolled-back clock is recorded as that, never as a false "expired"', () async {
      await activate(until: '2026-04-01 00:00:00');
      clock.set(DateTime.utc(2026, 3, 15));
      await service.hasValidCachedLicense(); // the device sees March 15th...
      clock.set(DateTime.utc(2026, 2, 1)); // ...then its clock is wound back

      await service.backgroundVerify();

      final end = await service.endedLicense();
      expect(end!.reason, LicenseEndReason.clockSetBack);
      expect(end.validUntil, DateTime.utc(2026, 4, 1));
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
}
