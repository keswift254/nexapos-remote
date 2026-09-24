import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/core/utils/monotonic_clock.dart';
import 'package:nexapos_mobile/data/licensing/license_gateway.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/data/payments/platform_onboarding_gateway.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import 'package:nexapos_mobile/domain/services/paystack_credentials_service.dart';

import '../../support/fake_monotonic_clock.dart';
import '../../support/fake_secure_storage.dart';

/// A joined device following the license of the shop's main device: the time
/// left arrives from that device (over the shop's network), is counted down
/// here, and decides when this device stops - online or not.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late AppDatabase db;
  late FixedClock wall;
  late FakeMonotonicClock mono;
  late LicenseService service;
  var platformStatus = 200;

  setUp(() async {
    installFakeSecureStorage();
    platformStatus = 200;
    wall = FixedClock(DateTime.utc(2026, 9, 8));
    mono = FakeMonotonicClock();
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(wall),
      monotonicClockProvider.overrideWithValue(mono),
      platformOnboardingGatewayProvider.overrideWithValue(
        PlatformOnboardingGateway(MockClient((_) async => http.Response(
          jsonEncode({'success': platformStatus == 200, 'status': 'active', 'shop_id': 12, 'is_owner': false}),
          platformStatus,
        ))),
      ),
      licenseGatewayProvider.overrideWith((ref) => LicenseGateway(MockClient((request) async {
        return http.Response(
          jsonEncode({'success': true, 'activation_token': 'a' * 64, 'valid_until': '2026-12-07 00:00:00'}),
          200,
        );
      }))),
    ]);
    await container.read(paystackCredentialsServiceProvider).save(const PaystackCredentials(
      baseUrl: 'https://example.com/index.php', apiKey: 'test', currency: 'KES', defaultEmail: '',
    ));
    service = container.read(licenseServiceProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  void pass(Duration duration) {
    wall.advance(duration);
    mono.advance(duration);
  }

  Future<void> joinAndFollow(Duration remaining, {bool neverExpires = false}) async {
    await service.confirmJoinedMembership();
    expect(await service.acceptLease(LeaseOffer(remaining: remaining, neverExpires: neverExpires)), isTrue);
  }

  group('access', () {
    test('without a lease a joined device still needs its 24-hour online re-confirmation (unchanged)', () async {
      await service.confirmJoinedMembership();
      pass(const Duration(hours: 25));

      expect(await service.hasAppAccess(), isFalse);
      expect(await service.joinedShopNeedsInternet(), isTrue);
    });

    test('once it follows the shop license it works offline far beyond 24 hours', () async {
      await joinAndFollow(const Duration(days: 180));
      pass(const Duration(days: 5)); // never online in that time

      expect(await service.hasAppAccess(), isTrue);
      expect(await service.joinedShopNeedsInternet(), isFalse);
    });

    test('it stops at exactly the moment the shop license runs out', () async {
      await joinAndFollow(const Duration(hours: 2));

      pass(const Duration(hours: 1, minutes: 59, seconds: 59));
      expect(await service.hasAppAccess(), isTrue);

      pass(const Duration(seconds: 1));
      expect(await service.hasAppAccess(), isFalse);
      expect(await service.joinedShopNeedsInternet(), isFalse, reason: 'not a connectivity problem');
    });

    test('being online does not extend it: confirming the membership leaves the countdown alone', () async {
      await joinAndFollow(const Duration(hours: 2));
      pass(const Duration(hours: 3));

      await service.verifyJoinedMembership(); // the platform answers "still a member"

      expect(await service.hasAppAccess(), isFalse);
    });

    test('a device holding its own valid license is not governed by the lease', () async {
      await service.confirmJoinedMembership();
      await service.activate('CODE1'); // its own license, valid until 2026-12-07
      expect(await service.hasValidCachedLicense(), isTrue);

      expect(await service.acceptLease(const LeaseOffer(remaining: Duration(days: 30))), isFalse,
          reason: 'its own license wins; it does not follow another');
      expect(await service.currentLease(), isNull);
    });
  });

  group('the clock cannot change the countdown', () {
    test('setting the date back does not give time back', () async {
      await joinAndFollow(const Duration(days: 10));
      pass(const Duration(days: 1));
      final before = (await service.currentLease())!.remaining;

      wall.advance(const Duration(days: -100)); // wound back to dodge the expiry

      expect((await service.currentLease())!.remaining, before);
      expect(await service.hasAppAccess(), isTrue);
    });

    test('setting the date far forward is undone by putting it right', () async {
      await joinAndFollow(const Duration(days: 10));
      pass(const Duration(days: 1));

      wall.advance(const Duration(days: 100)); // by accident
      expect(await service.hasAppAccess(), isFalse);

      wall.advance(const Duration(days: -100)); // corrected
      expect(await service.hasAppAccess(), isTrue);
      expect((await service.currentLease())!.remaining, const Duration(days: 9));
    });
  });

  group('ending, and coming back', () {
    test('the app is told to re-check and the reason is recorded once when it runs out', () async {
      await joinAndFollow(const Duration(hours: 1));
      pass(const Duration(hours: 2));
      var signals = 0;
      container.listen(licenseChangeSignalProvider, (_, _) => signals++);

      await service.backgroundVerify();

      final end = await service.endedLicense();
      expect(end!.reason, LicenseEndReason.shopLicenseExpired);
      expect(signals, greaterThan(0));

      final firstNotice = end.noticedAt;
      pass(const Duration(minutes: 5));
      await service.backgroundVerify();
      expect((await service.endedLicense())!.noticedAt, firstNotice, reason: 'recorded once, not on every check');
    });

    test('a device locked by the lease is explained even before the background check has run', () async {
      await joinAndFollow(const Duration(hours: 1));
      pass(const Duration(hours: 2));

      expect((await service.endedLicense())!.reason, LicenseEndReason.shopLicenseExpired);
    });

    test('a renewal from the main device reopens it and clears the notice', () async {
      await joinAndFollow(const Duration(hours: 1));
      pass(const Duration(hours: 2));
      await service.backgroundVerify();
      expect(await service.hasAppAccess(), isFalse);

      expect(await service.acceptLease(const LeaseOffer(remaining: Duration(days: 90))), isTrue);

      expect(await service.hasAppAccess(), isTrue);
      expect(await service.endedLicense(), isNull);
    });

    test('a device that is not on the shop network is told to get online when it never had a lease', () async {
      await service.confirmJoinedMembership();
      pass(const Duration(days: 3));

      expect(await service.joinedShopNeedsInternet(), isTrue);
      expect(await service.endedLicense(), isNull);
    });
  });

  group('which offers a device takes', () {
    test('a device that never joined a shop follows nothing', () async {
      expect(await service.acceptLease(const LeaseOffer(remaining: Duration(days: 30))), isFalse);
      expect(await service.currentLease(), isNull);
    });

    test('only more time is ever taken (a license is extended, never shortened)', () async {
      await joinAndFollow(const Duration(days: 100));

      expect(await service.acceptLease(const LeaseOffer(remaining: Duration(days: 90))), isFalse);
      expect(await service.acceptLease(const LeaseOffer(remaining: Duration(days: 100, seconds: 30))), isFalse,
          reason: 'a few seconds\' difference between two devices\' counts is not a renewal');
      expect(await service.acceptLease(const LeaseOffer(remaining: Duration(days: 130))), isTrue);
      expect((await service.currentLease())!.remaining, const Duration(days: 130));
    });

    test('a device whose own counting fell behind is put right by the main device\'s figure', () async {
      await joinAndFollow(const Duration(days: 100));
      pass(const Duration(days: 1));
      // The main device says 99 days are left; ours also says 99: nothing to do.
      expect(await service.acceptLease(const LeaseOffer(remaining: Duration(days: 99))), isFalse);
      // A day was wrongly charged here (say a set-back clock at startup): the main device says 100.
      expect(await service.acceptLease(const LeaseOffer(remaining: Duration(days: 100))), isTrue);
    });

    test('a license that never expires replaces a dated one, and is never replaced', () async {
      await joinAndFollow(const Duration(days: 30));

      expect(await service.acceptLease(const LeaseOffer(remaining: Duration.zero, neverExpires: true)), isTrue);
      pass(const Duration(days: 4000));
      expect(await service.hasAppAccess(), isTrue);
      expect(await service.acceptLease(const LeaseOffer(remaining: Duration(days: 999))), isFalse);
    });
  });

  group('what a device hands on', () {
    test('a joined device passes on the lease it follows, with its current time left', () async {
      await joinAndFollow(const Duration(days: 30));
      pass(const Duration(days: 4));

      final offer = (await service.leaseToShare())!;

      expect(offer.remaining, const Duration(days: 26));
      expect(offer.neverExpires, isFalse);
    });

    test('an ended lease is not handed on', () async {
      await joinAndFollow(const Duration(hours: 1));
      pass(const Duration(hours: 2));

      expect(await service.leaseToShare(), isNull);
    });

    test('the shop\'s main device offers the time its own license has left', () async {
      await service.activate('CODE1'); // valid until 2026-12-07; the clock reads 2026-09-08

      final offer = (await service.leaseToShare())!;

      expect(offer.remaining, DateTime.utc(2026, 12, 7).difference(wall.now()));
    });

    test('a device with nothing to give gives nothing', () async {
      expect(await service.leaseToShare(), isNull);
    });
  });

  group('leaving, removal and re-joining', () {
    test('leaving the shop drops the lease', () async {
      await joinAndFollow(const Duration(days: 30));

      await service.clearJoinedMembership();

      expect(await service.currentLease(), isNull);
    });

    test('a confirmed removal drops the lease along with the shop data', () async {
      await joinAndFollow(const Duration(days: 30));
      platformStatus = 403;

      await service.verifyJoinedMembership();

      expect(await service.currentLease(), isNull);
      expect(await service.hasAppAccess(), isFalse);
    });

    test('joining again starts with no lease, so it cannot inherit another shop\'s', () async {
      await joinAndFollow(const Duration(days: 30));

      await service.confirmJoinedMembership();

      expect(await service.currentLease(), isNull);
    });
  });

  group('the Settings status', () {
    test('a joined device reports the shop license time it follows', () async {
      await joinAndFollow(const Duration(days: 30));
      pass(const Duration(days: 4));

      final status = await service.currentStatus(askServer: false);

      expect(status.state, LicenseState.joined);
      expect(status.sharedRemaining, const Duration(days: 26));
      expect(status.sharedNeverExpires, isFalse);
    });

    test('and reports it expired once it has run out', () async {
      await joinAndFollow(const Duration(hours: 1));
      pass(const Duration(hours: 2));

      expect((await service.currentStatus(askServer: false)).state, LicenseState.expired);
    });

    test('a shop license that never expires is reported as such', () async {
      await joinAndFollow(Duration.zero, neverExpires: true);

      final status = await service.currentStatus(askServer: false);

      expect(status.sharedNeverExpires, isTrue);
      expect(status.sharedRemaining, isNull);
    });
  });
}
