import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/result.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/core/utils/monotonic_clock.dart';
import 'package:nexapos_mobile/domain/region/regions.dart';
import 'package:nexapos_mobile/domain/services/clock_health_service.dart';
import 'package:nexapos_mobile/domain/services/date_settings_opener.dart';
import 'package:nexapos_mobile/domain/services/region_settings_service.dart';
import 'package:nexapos_mobile/domain/services/windows_time_fix_service.dart';
import 'package:nexapos_mobile/features/settings/region_time_screen.dart';

import '../support/fake_monotonic_clock.dart';
import '../support/fake_secure_storage.dart';

const _serverDate = 'Fri, 25 Sep 2026 10:00:00 GMT';
final _serverTime = DateTime.utc(2026, 9, 25, 10);

class _FakeFix extends WindowsTimeFixService {
  _FakeFix(super.ref, this.onFix);

  final Result<TimeFixReport> Function() onFix;

  @override
  Future<Result<TimeFixReport>> fixNow() async => onFix();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FixedClock wall;
  late http.Response Function() timeAnswer;
  late Duration deviceOffset;
  late int fixCalls;
  late Result<TimeFixReport> Function() fixOutcome;
  late int dateSettingsOpened;
  late bool dateSettingsWork;
  late ProviderContainer container;

  Result<TimeFixReport> fixed() => const Result.ok(TimeFixReport(
    ok: true, timeSet: true, zoneSet: true, syncConfigured: true,
  ));

  setUp(() {
    installFakeSecureStorage();
    wall = FixedClock(_serverTime);
    deviceOffset = const Duration(hours: 3);
    dateSettingsOpened = 0;
    dateSettingsWork = true;
    fixCalls = 0;
    fixOutcome = fixed;
    timeAnswer = () => http.Response(jsonEncode({'success': true}), 200, headers: {'date': _serverDate});
  });

  Future<void> open(WidgetTester tester, {String? savedCountry}) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(wall),
      monotonicClockProvider.overrideWithValue(FakeMonotonicClock()),
      deviceUtcOffsetProvider.overrideWithValue(() => deviceOffset),
      trustedTimeServiceProvider.overrideWith(
        (ref) => TrustedTimeService(ref, client: MockClient((request) async => timeAnswer())),
      ),
      windowsTimeFixServiceProvider.overrideWith((ref) => _FakeFix(ref, () {
        fixCalls++;
        return fixOutcome();
      })),
      dateSettingsOpenerProvider.overrideWithValue(() async {
        dateSettingsOpened++;
        return dateSettingsWork;
      }),
    ]);
    if (savedCountry != null) {
      final region = regionByCode(savedCountry)!;
      await tester.runAsync(() => container.read(regionSettingsServiceProvider).save(
        RegionSettings(region: region, zone: region.zones.first),
      ));
    }
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: RegionTimeScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  }

  group('what it says about the clock', () {
    testWidgets('a right clock and zone: says so, offers nothing to fix', (tester) async {
      await open(tester, savedCountry: 'KE');

      expect(find.text('Region and Time'), findsOneWidget);
      expect(find.byKey(const Key('clock-right')), findsOneWidget);
      expect(find.byKey(const Key('zone-right')), findsOneWidget);
      expect(find.byKey(const Key('fix-clock')), findsNothing);
      expect(find.byKey(const Key('open-date-settings')), findsNothing);
      expect(find.byKey(const Key('check-clock')), findsOneWidget);

      await close(tester);
    });

    testWidgets('a clock ahead is reported with how far, and which way', (tester) async {
      wall.set(_serverTime.add(const Duration(hours: 3, minutes: 12)));
      await open(tester, savedCountry: 'KE');

      expect(find.text("This device's clock is 3 hours 12 minutes ahead of the real time."), findsOneWidget);

      await close(tester);
    });

    testWidgets('a clock behind is reported as behind', (tester) async {
      wall.set(_serverTime.subtract(const Duration(days: 40)));
      await open(tester, savedCountry: 'KE');

      expect(find.textContaining('40 days behind the real time.'), findsOneWidget);

      await close(tester);
    });

    testWidgets('the wrong time zone is reported against the chosen region', (tester) async {
      deviceOffset = Duration.zero;
      await open(tester, savedCountry: 'KE');

      expect(find.byKey(const Key('clock-right')), findsOneWidget, reason: 'the time itself is right');
      expect(
        find.text('This device\'s time zone (UTC+00:00) does not match your region (East Africa Time (UTC+03:00)).'),
        findsOneWidget,
      );

      await close(tester);
    });

    testWidgets('offline: says it could not check, and is not alarmed', (tester) async {
      timeAnswer = () => throw const SocketException('no internet');
      await open(tester, savedCountry: 'KE');

      expect(find.byKey(const Key('clock-unknown')), findsOneWidget);
      expect(find.textContaining('Could not check the date and time'), findsOneWidget);
      expect(find.byKey(const Key('fix-clock')), findsNothing);

      await close(tester);
    });

    testWidgets('with no region saved yet it says the zone cannot be checked, and suggests one from the device', (tester) async {
      deviceOffset = const Duration(hours: 5, minutes: 30);
      await open(tester);

      expect(find.textContaining('Save your region above'), findsOneWidget);
      expect(find.text('India'), findsOneWidget, reason: 'suggested from the device\'s own time zone');
      expect(find.text('India Standard Time (UTC+05:30)'), findsOneWidget);

      await close(tester);
    });

    testWidgets('Check now asks again straight away', (tester) async {
      await open(tester, savedCountry: 'KE');
      expect(find.byKey(const Key('clock-right')), findsOneWidget);

      wall.set(_serverTime.add(const Duration(hours: 2)));
      await tester.tap(find.byKey(const Key('check-clock')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('clock-wrong')), findsOneWidget);

      await close(tester);
    });
  });

  group('the region', () {
    testWidgets('changing it enables Save, and saving remembers it and checks the zone again', (tester) async {
      await open(tester, savedCountry: 'KE');
      final save = find.byKey(const Key('save-region'));
      expect(tester.widget<FilledButton>(save).onPressed, isNull, reason: 'nothing to save yet');

      await tester.tap(find.byKey(const Key('region-country')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ghana').last);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text('Region saved.'), findsOneWidget);
      final saved = (await tester.runAsync(() => container.read(regionSettingsServiceProvider).load()))!;
      expect(saved.region.code, 'GH');
      // Ghana is on UTC; this device is on +03:00, so the zone check now objects.
      expect(find.byKey(const Key('zone-wrong')), findsOneWidget);
      expect(tester.widget<FilledButton>(save).onPressed, isNull, reason: 'saved, so nothing left to save');

      await close(tester);
    });
  });

  group('on Windows', () {
    testWidgets('a wrong clock offers "Fix the clock now", which asks first and then does it', (tester) async {
      wall.set(_serverTime.add(const Duration(hours: 3)));
      await open(tester, savedCountry: 'KE');
      expect(find.byKey(const Key('fix-clock')), findsOneWidget);
      expect(find.byKey(const Key('open-date-settings')), findsNothing);

      await tester.tap(find.byKey(const Key('fix-clock')));
      await tester.pumpAndSettle();
      expect(find.text('Fix the clock?'), findsOneWidget);
      expect(find.textContaining('Windows will ask for permission first'), findsOneWidget);
      expect(fixCalls, 0, reason: 'nothing happens until it is confirmed');

      await tester.tap(find.widgetWithText(FilledButton, 'Fix the clock'));
      await tester.pumpAndSettle();

      expect(fixCalls, 1);
      expect(find.text('The clock is fixed.'), findsOneWidget);

      await close(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('cancelling the question fixes nothing', (tester) async {
      wall.set(_serverTime.add(const Duration(hours: 3)));
      await open(tester, savedCountry: 'KE');

      await tester.tap(find.byKey(const Key('fix-clock')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(fixCalls, 0);
      expect(find.byKey(const Key('region-time-notice')), findsNothing);

      await close(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('a failure is shown in words', (tester) async {
      fixOutcome = () => const Result.failure('Windows did not give permission to change the clock.');
      wall.set(_serverTime.add(const Duration(hours: 3)));
      await open(tester, savedCountry: 'KE');

      await tester.tap(find.byKey(const Key('fix-clock')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Fix the clock'));
      await tester.pumpAndSettle();

      expect(find.text('Windows did not give permission to change the clock.'), findsOneWidget);
      expect(find.text('The clock is fixed.'), findsNothing);

      await close(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('fixing with a region still unsaved saves the one shown, so that zone is the one set', (tester) async {
      wall.set(_serverTime.add(const Duration(hours: 3)));
      await open(tester); // nothing saved; Kenya suggested from +03:00

      await tester.tap(find.byKey(const Key('fix-clock')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Fix the clock'));
      await tester.pumpAndSettle();

      final saved = (await tester.runAsync(() => container.read(regionSettingsServiceProvider).load()))!;
      expect(saved.region.code, 'KE');
      expect(fixCalls, 1);

      await close(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('a right clock offers no fix, but explains what Windows will do if it ever needs one', (tester) async {
      await open(tester, savedCountry: 'KE');

      expect(find.byKey(const Key('fix-clock')), findsNothing);
      expect(find.textContaining('Windows asks for permission'), findsOneWidget);

      await close(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  });

  group('on Android', () {
    testWidgets('a wrong clock offers to open the Date & time settings', (tester) async {
      wall.set(_serverTime.add(const Duration(hours: 3)));
      await open(tester, savedCountry: 'KE');
      expect(find.byKey(const Key('fix-clock')), findsNothing);

      await tester.tap(find.byKey(const Key('open-date-settings')));
      await tester.pumpAndSettle();

      expect(dateSettingsOpened, 1);
      expect(find.textContaining('Automatic date & time'), findsOneWidget);
      expect(find.byKey(const Key('region-time-notice')), findsNothing);

      await close(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('if the settings cannot be opened it says where to go instead', (tester) async {
      dateSettingsWork = false;
      wall.set(_serverTime.add(const Duration(hours: 3)));
      await open(tester, savedCountry: 'KE');

      await tester.tap(find.byKey(const Key('open-date-settings')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not open the settings'), findsOneWidget);

      await close(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('on another system', () {
    testWidgets('a wrong clock says to set it in the device settings, with no fix button', (tester) async {
      wall.set(_serverTime.add(const Duration(hours: 3)));
      await open(tester, savedCountry: 'KE');

      expect(find.byKey(const Key('fix-clock')), findsNothing);
      expect(find.byKey(const Key('open-date-settings')), findsNothing);
      expect(find.textContaining('Set the correct date, time and time zone'), findsOneWidget);

      await close(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });
}
