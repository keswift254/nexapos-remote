import 'dart:convert';
import 'dart:io' show HttpDate;

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

/// The shop's MAIN device is the reference for the shop's license, in both
/// directions: what it said last wins over what a joined device is still counting
/// (an expiry or a revoke reaches a device that had days left), whether it arrives
/// over the shop's network or through the platform.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late AppDatabase db;
  late FixedClock wall;
  late FakeMonotonicClock mono;
  late LicenseService service;

  // What the fake platform answers client_status with, and what it was sent.
  Map<String, dynamic>? platformLicense;
  var sendServerTime = true;
  var reportStatus = 200;
  var reportOffline = false;
  late List<Map<String, dynamic>> reports;

  // What the fake license server answers verify with.
  var licenseValid = true;
  var licenseValidUntil = '2026-12-07 00:00:00';

  const s0 = 1000000; // an arbitrary stamp; only the order of stamps matters

  setUp(() async {
    installFakeSecureStorage();
    platformLicense = null;
    sendServerTime = true;
    reportStatus = 200;
    reportOffline = false;
    reports = [];
    licenseValid = true;
    licenseValidUntil = '2026-12-07 00:00:00';
    wall = FixedClock(DateTime.utc(2026, 9, 8));
    mono = FakeMonotonicClock();
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(wall),
        monotonicClockProvider.overrideWithValue(mono),
        platformOnboardingGatewayProvider.overrideWithValue(
          PlatformOnboardingGateway(
            MockClient((request) async {
              if (request.url.queryParameters['action'] == 'report_shop_license') {
                if (reportOffline) throw http.ClientException('offline');
                reports.add(jsonDecode(request.body) as Map<String, dynamic>);
                return http.Response(
                  jsonEncode({'success': reportStatus == 200}),
                  reportStatus,
                );
              }
              return http.Response(
                jsonEncode({
                  'success': true,
                  'status': 'active',
                  'shop_id': 12,
                  'is_owner': false,
                  'license': ?platformLicense,
                  if (sendServerTime) 'server_time': wall.now().toUtc().toIso8601String(),
                }),
                200,
              );
            }),
          ),
        ),
        licenseGatewayProvider.overrideWith(
          (ref) => LicenseGateway(
            MockClient((request) async {
              final headers = {'date': HttpDate.format(wall.now().toUtc())};
              if (request.url.queryParameters['action'] == 'verify') {
                return http.Response(
                  jsonEncode({
                    'success': true,
                    'valid': licenseValid,
                    'valid_until': licenseValidUntil,
                  }),
                  200,
                  headers: headers,
                );
              }
              return http.Response(
                jsonEncode({
                  'success': true,
                  'activation_token': 'a' * 64,
                  'valid_until': licenseValidUntil,
                }),
                200,
                headers: headers,
              );
            }),
          ),
        ),
      ],
    );
    await container
        .read(paystackCredentialsServiceProvider)
        .save(
          const PaystackCredentials(
            baseUrl: 'https://example.com/index.php',
            apiKey: 'test',
            currency: 'KES',
            defaultEmail: '',
          ),
        );
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

  /// A joined device already following an UNSTAMPED lease of [days] (what every
  /// version before this one handed out).
  Future<void> joinedWithOldLease(int days) async {
    await service.confirmJoinedMembership();
    expect(await service.acceptLease(LeaseOffer(remaining: Duration(days: days))), isTrue);
  }

  int signals() => container.read(licenseChangeSignalProvider);

  group('over the shop network: the main device\'s newest word wins, up or down', () {
    test('the main device\'s expiry reaches a joined device that was still counting 5 days', () async {
      await joinedWithOldLease(5);
      expect(await service.hasAppAccess(), isTrue);

      final taken = await service.acceptLease(const LeaseOffer(remaining: Duration.zero, stamp: s0));

      expect(taken, isTrue);
      expect(await service.hasAppAccess(), isFalse);
      expect((await service.endedLicense())!.reason, LicenseEndReason.shopLicenseExpired,
          reason: 'it must explain itself, not look like a fresh install');
    });

    test('a newer statement can also SHORTEN the time left', () async {
      await service.confirmJoinedMembership();
      await service.acceptLease(const LeaseOffer(remaining: Duration(days: 60), stamp: s0));

      expect(await service.acceptLease(const LeaseOffer(remaining: Duration(days: 10), stamp: s0 + 1)), isTrue);

      expect((await service.currentLease())!.remaining, const Duration(days: 10));
    });

    test('a stale relay (older stamp) is ignored, whichever way it points', () async {
      await service.confirmJoinedMembership();
      await service.acceptLease(const LeaseOffer(remaining: Duration.zero, stamp: s0 + 10));
      expect(await service.hasAppAccess(), isFalse);

      // Another joined device that has not caught up still holds 5 days from before.
      expect(await service.acceptLease(const LeaseOffer(remaining: Duration(days: 5), stamp: s0)), isFalse);
      expect(await service.acceptLease(const LeaseOffer(remaining: Duration(days: 5))), isFalse,
          reason: 'an unstamped (older version) relay cannot un-expire a stamped ending');
      expect(await service.hasAppAccess(), isFalse);
    });

    test('a renewal (newer stamp) reopens a device that ran out, and clears the notice', () async {
      await service.confirmJoinedMembership();
      await service.acceptLease(const LeaseOffer(remaining: Duration.zero, stamp: s0));
      expect(await service.hasAppAccess(), isFalse);

      expect(await service.acceptLease(const LeaseOffer(remaining: Duration(days: 180), stamp: s0 + 5)), isTrue);

      expect(await service.hasAppAccess(), isTrue);
      expect(await service.endedLicense(), isNull);
    });

    test('the same statement (equal stamp) only ever adds time, as before', () async {
      await service.confirmJoinedMembership();
      await service.acceptLease(const LeaseOffer(remaining: Duration(days: 100), stamp: s0));

      expect(await service.acceptLease(const LeaseOffer(remaining: Duration(days: 90), stamp: s0)), isFalse);
      expect(await service.acceptLease(const LeaseOffer(remaining: Duration(days: 130), stamp: s0)), isTrue);
    });

    test('an unstamped offer (older version) still extends an unstamped lease, and only that', () async {
      await joinedWithOldLease(10);
      expect(await service.acceptLease(const LeaseOffer(remaining: Duration(days: 40))), isTrue);
      expect(await service.acceptLease(const LeaseOffer(remaining: Duration(days: 5))), isFalse);
    });

    test('the same news, only newer, keeps this device\'s count and does not stir the app', () async {
      await service.confirmJoinedMembership();
      await service.acceptLease(const LeaseOffer(remaining: Duration(days: 100), stamp: s0));
      pass(const Duration(seconds: 20));
      final before = signals();
      final counted = (await service.currentLease())!.remaining;

      // Every 15 seconds the main device's check makes a newer stamp with a count that
      // differs by seconds. That must not rewrite the lease or wake the whole app.
      expect(await service.acceptLease(LeaseOffer(remaining: counted + const Duration(seconds: 7), stamp: s0 + 15000)), isFalse);

      expect(signals(), before);
      final lease = (await service.currentLease())!;
      expect(lease.stamp, s0 + 15000, reason: 'the newer stamp is remembered, so an older relay stays ignored');
      expect(lease.remaining, counted);
    });

    test('an ended, stamped lease is passed on so others hear it; an unstamped one is not', () async {
      await service.confirmJoinedMembership();
      await service.acceptLease(const LeaseOffer(remaining: Duration.zero, stamp: s0));

      final offer = (await service.leaseToShare())!;

      expect(offer.remaining, Duration.zero);
      expect(offer.stamp, s0);
    });

    test('a lease that never expires can be ended by a newer statement', () async {
      await service.confirmJoinedMembership();
      await service.acceptLease(const LeaseOffer(remaining: Duration.zero, neverExpires: true, stamp: s0));
      expect(await service.hasAppAccess(), isTrue);

      await service.acceptLease(const LeaseOffer(remaining: Duration.zero, stamp: s0 + 1));

      expect(await service.hasAppAccess(), isFalse);
    });
  });

  group('the main device says so when its license ends', () {
    test('its own license, ended on the license server, is offered as zero time with a stamp', () async {
      await service.activate('CODE1');
      expect((await service.leaseToShare())!.remaining, greaterThan(Duration.zero));

      licenseValid = false;
      licenseValidUntil = '2026-09-01 00:00:00';
      pass(const Duration(minutes: 1));
      await service.backgroundVerify();

      final offer = (await service.leaseToShare())!;
      expect(offer.remaining, Duration.zero);
      expect(offer.stamp, wall.now().millisecondsSinceEpoch ~/ 1000 * 1000,
          reason: 'stamped with the license server\'s clock at the moment it said so');
    });

    test('an offer of its running license carries the stamp of the last check', () async {
      await service.activate('CODE1');

      final offer = (await service.leaseToShare())!;

      expect(offer.stamp, wall.now().millisecondsSinceEpoch ~/ 1000 * 1000);
    });

    test('a main device whose license ended stays on the shop network to say so; nobody else does', () async {
      expect(await service.announcesEndedLicense, isFalse, reason: 'never licensed');
      await service.activate('CODE1');
      expect(await service.announcesEndedLicense, isFalse, reason: 'still licensed');

      licenseValid = false;
      licenseValidUntil = '2026-09-01 00:00:00';
      pass(const Duration(minutes: 1));
      await service.backgroundVerify();

      expect(await service.announcesEndedLicense, isTrue);
    });

    test('a joined device whose shop license ended does not count as a main device that announces one', () async {
      await service.confirmJoinedMembership();
      await service.acceptLease(const LeaseOffer(remaining: Duration.zero, stamp: s0));
      await service.backgroundVerify();

      expect(await service.announcesEndedLicense, isFalse);
    });

    test('a joined device does not offer its own "shop license expired" note as an ending of its own', () async {
      await service.confirmJoinedMembership();
      await service.acceptLease(const LeaseOffer(remaining: Duration(hours: 1)));
      pass(const Duration(hours: 2));
      await service.backgroundVerify(); // records the shop-license-expired notice

      expect(await service.leaseToShare(), isNull, reason: 'unstamped ending: nothing to put in order');
    });
  });

  group('over the internet: the platform carries the main device\'s report', () {
    Map<String, dynamic> view(String state, {String? validUntil, int? checkedAt, bool never = false}) => {
      'state': state,
      'valid_until': validUntil,
      'never_expires': never,
      'checked_at': checkedAt,
    };

    Future<void> joinedAndChecked() async {
      await service.confirmJoinedMembership();
      await service.verifyJoinedMembership();
    }

    test('a joined device with no lease at all follows the shop\'s license from the platform', () async {
      platformLicense = view('active', validUntil: wall.now().add(const Duration(days: 10)).toUtc().toIso8601String(), checkedAt: s0);
      await joinedAndChecked();

      final lease = (await service.currentLease())!;
      expect(lease.remaining, const Duration(days: 10));
      expect(lease.stamp, s0);
      pass(const Duration(days: 11));
      expect(await service.hasAppAccess(), isFalse, reason: 'it now runs out with the shop\'s license, online or not');
    });

    test('the platform\'s expiry locks a device that still had 5 days from before', () async {
      await joinedWithOldLease(5);
      platformLicense = view('expired', checkedAt: s0);

      await service.verifyJoinedMembership();

      expect(await service.hasAppAccess(), isFalse);
      expect((await service.endedLicense())!.reason, LicenseEndReason.shopLicenseExpired);
    });

    test('a revoked license locks it too', () async {
      await joinedWithOldLease(5);
      platformLicense = view('revoked', checkedAt: s0);

      await service.verifyJoinedMembership();

      expect(await service.hasAppAccess(), isFalse);
    });

    test('a renewal reported by the main device reopens it', () async {
      await joinedWithOldLease(5);
      platformLicense = view('expired', checkedAt: s0);
      await service.verifyJoinedMembership();
      expect(await service.hasAppAccess(), isFalse);

      platformLicense = view('active', validUntil: wall.now().add(const Duration(days: 365)).toUtc().toIso8601String(), checkedAt: s0 + 60000);
      await service.verifyJoinedMembership();

      expect(await service.hasAppAccess(), isTrue);
      expect((await service.currentLease())!.remaining, const Duration(days: 365));
    });

    test('a license that never expires is followed as such', () async {
      platformLicense = view('active', never: true, checkedAt: s0);
      await joinedAndChecked();

      pass(const Duration(days: 4000));

      expect((await service.currentLease())!.neverExpires, isTrue);
      expect(await service.hasAppAccess(), isTrue);
    });

    test('the platform\'s figure puts a drifted count right, either way', () async {
      await service.confirmJoinedMembership();
      await service.acceptLease(LeaseOffer(remaining: const Duration(days: 40), stamp: s0));
      // The platform, same statement, says 30 days are left (this device counted too generously).
      platformLicense = view('active', validUntil: wall.now().add(const Duration(days: 30)).toUtc().toIso8601String(), checkedAt: s0);

      await service.verifyJoinedMembership();

      expect((await service.currentLease())!.remaining, const Duration(days: 30));
    });

    test('an older report from the platform does not undo something newer heard on the shop network', () async {
      await service.confirmJoinedMembership();
      await service.acceptLease(const LeaseOffer(remaining: Duration.zero, stamp: s0 + 100));
      platformLicense = view('active', validUntil: wall.now().add(const Duration(days: 30)).toUtc().toIso8601String(), checkedAt: s0);

      await service.verifyJoinedMembership();

      expect(await service.hasAppAccess(), isFalse);
    });

    test('a shop whose main device has never reported changes nothing', () async {
      await joinedWithOldLease(5);
      platformLicense = null;

      await service.verifyJoinedMembership();

      expect((await service.currentLease())!.remaining, const Duration(days: 5));
      expect(await service.hasAppAccess(), isTrue);
    });

    test('without the platform\'s clock a dated license cannot be counted, so it is left alone', () async {
      await joinedWithOldLease(5);
      sendServerTime = false;
      platformLicense = view('active', validUntil: wall.now().add(const Duration(days: 300)).toUtc().toIso8601String(), checkedAt: s0);

      await service.verifyJoinedMembership();

      expect((await service.currentLease())!.remaining, const Duration(days: 5));
    });

    test('a device holding its own valid license is not governed by what the platform says about the shop', () async {
      await service.confirmJoinedMembership();
      await service.activate('CODE1');
      platformLicense = view('expired', checkedAt: s0);

      await service.verifyJoinedMembership();

      expect(await service.hasAppAccess(), isTrue);
      expect(await service.currentLease(), isNull);
    });

    test('a garbage license view from the platform cannot break the membership check', () async {
      await joinedWithOldLease(5);
      platformLicense = {'state': 42, 'valid_until': 'zzz'};

      await service.verifyJoinedMembership();

      expect(await service.hasAppAccess(), isTrue);
    });
  });

  group('the main device tells the platform', () {
    test('activating reports the license as active with its end date', () async {
      await service.activate('CODE1');
      await pumpEventQueue();

      expect(reports, hasLength(1));
      expect(reports.single['state'], 'active');
      expect(reports.single['valid_until'], '2026-12-07T00:00:00.000Z');
      expect(reports.single['checked_at'], wall.now().millisecondsSinceEpoch ~/ 1000 * 1000);
    });

    test('a routine check repeats nothing for half an hour, then confirms again', () async {
      await service.activate('CODE1');
      await pumpEventQueue();
      reports.clear();

      pass(const Duration(minutes: 1));
      await service.backgroundVerify();
      await pumpEventQueue();
      expect(reports, isEmpty, reason: 'same state, just reported');

      pass(const Duration(minutes: 31));
      await service.backgroundVerify();
      await pumpEventQueue();
      expect(reports, hasLength(1));
    });

    test('an extended license is reported at once', () async {
      await service.activate('CODE1');
      await pumpEventQueue();
      reports.clear();

      licenseValidUntil = '2027-06-07 00:00:00';
      pass(const Duration(minutes: 1));
      await service.backgroundVerify();
      await pumpEventQueue();

      expect(reports.single['valid_until'], '2027-06-07T00:00:00.000Z');
    });

    test('an ending on the license server is reported, once, as expired or revoked', () async {
      await service.activate('CODE1');
      await pumpEventQueue();
      reports.clear();

      licenseValid = false;
      licenseValidUntil = '2026-09-01 00:00:00'; // already past: it ran out
      pass(const Duration(minutes: 1));
      await service.backgroundVerify();
      await pumpEventQueue();
      expect(reports.single['state'], 'expired');

      pass(const Duration(minutes: 1));
      await service.backgroundVerify(); // the device is already locked; nothing more to say
      await pumpEventQueue();
      expect(reports, hasLength(1));
    });

    test('a revoke (end date not passed) is reported as revoked', () async {
      await service.activate('CODE1');
      await pumpEventQueue();
      reports.clear();

      licenseValid = false; // valid_until stays in the future: revoked by the vendor
      pass(const Duration(minutes: 1));
      await service.backgroundVerify();
      await pumpEventQueue();

      expect(reports.single['state'], 'revoked');
    });

    test('an ending that could not be reported (offline) is retried until it goes through', () async {
      await service.activate('CODE1');
      await pumpEventQueue();
      reports.clear();

      reportOffline = true;
      licenseValid = false;
      licenseValidUntil = '2026-09-01 00:00:00';
      pass(const Duration(minutes: 1));
      await service.backgroundVerify();
      await pumpEventQueue();
      expect(reports, isEmpty);

      reportOffline = false;
      pass(const Duration(minutes: 1));
      await service.backgroundVerify(); // no token any more - it still tries to say so
      await pumpEventQueue();
      expect(reports.single['state'], 'expired');
    });

    test('a device the platform refuses (not the shop\'s main device) is not asked again for half an hour', () async {
      reportStatus = 403;
      await service.activate('CODE1');
      await pumpEventQueue();
      expect(reports, hasLength(1));
      reports.clear();

      licenseValidUntil = '2027-06-07 00:00:00';
      pass(const Duration(minutes: 5));
      await service.backgroundVerify();
      await pumpEventQueue();
      expect(reports, isEmpty, reason: 'backed off after the refusal');

      pass(const Duration(minutes: 31));
      await service.backgroundVerify();
      await pumpEventQueue();
      expect(reports, hasLength(1));
    });

    test('a device that is not registered with the platform reports nothing and does not fail', () async {
      await container.read(paystackCredentialsServiceProvider).save(
        const PaystackCredentials(baseUrl: '', apiKey: '', currency: 'KES', defaultEmail: ''),
      );

      expect((await service.activate('CODE1')).isOk, isTrue);
      await pumpEventQueue();

      expect(reports, isEmpty);
    });

    test('a joined device never reports a shop license', () async {
      await service.confirmJoinedMembership();
      await service.acceptLease(const LeaseOffer(remaining: Duration(days: 30), stamp: s0));

      await service.backgroundVerify();
      await pumpEventQueue();

      expect(reports, isEmpty);
    });
  });
}
