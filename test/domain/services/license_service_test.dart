import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nexapos_mobile/core/providers.dart';
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
}
