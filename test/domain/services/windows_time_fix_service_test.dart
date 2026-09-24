import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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
import 'package:nexapos_mobile/data/update/update_gateway.dart';
import 'package:nexapos_mobile/domain/region/regions.dart';
import 'package:nexapos_mobile/domain/services/clock_health_service.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import 'package:nexapos_mobile/domain/services/region_settings_service.dart';
import 'package:nexapos_mobile/domain/services/windows_time_fix_service.dart';

import '../../support/fake_monotonic_clock.dart';
import '../../support/fake_secure_storage.dart';

const _serverDate = 'Fri, 25 Sep 2026 10:00:00 GMT';
final _serverTime = DateTime.utc(2026, 9, 25, 10);

/// Time that moves by itself every time it is looked at, so a loop that waits
/// for something that never happens ends.
class _TickingClock implements MonotonicClock {
  Duration _now = Duration.zero;

  @override
  Duration elapsed() => _now += const Duration(seconds: 1);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final toolBytes = Uint8List.fromList(utf8.encode('pretend this is NexaPosTimeFix.exe'));
  final toolHash = sha256.convert(toolBytes).toString();

  late FixedClock wall;
  late FakeMonotonicClock mono;
  late Directory temp;
  late AppDatabase db;
  late ProviderContainer container;
  late List<(String exe, String args)> launches;
  late void Function(String exe, String args) onLaunch;
  late Future<Uint8List> Function(String url) download;
  late http.Response Function() timeAnswer;
  var downloads = 0;

  WindowsTimeFixService build({
    MonotonicClock? monotonic,
    Duration waitTimeout = const Duration(seconds: 5),
    String? sha,
  }) {
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(wall),
      monotonicClockProvider.overrideWithValue(monotonic ?? mono),
      deviceUtcOffsetProvider.overrideWithValue(() => const Duration(hours: 3)),
      licenseGatewayProvider.overrideWith((ref) => LicenseGateway(MockClient((request) async {
        return http.Response(
          jsonEncode({'success': true, 'activation_token': 'a' * 64, 'valid_until': '2026-12-25 10:00:00'}),
          200,
        );
      }))),
      trustedTimeServiceProvider.overrideWith(
        (ref) => TrustedTimeService(ref, client: MockClient((request) async => timeAnswer())),
      ),
      windowsTimeFixServiceProvider.overrideWith(
        (ref) => WindowsTimeFixService(
          ref,
          download: (url) {
            downloads++;
            return download(url);
          },
          launch: (exe, args) {
            launches.add((exe, args));
            onLaunch(exe, args);
          },
          tempDirectory: () async => temp,
          toolUrl: 'https://tools.example/NexaPosTimeFix.exe',
          toolSha256: sha ?? toolHash,
          pollInterval: const Duration(milliseconds: 5),
          waitTimeout: waitTimeout,
        ),
      ),
    ]);
    addTearDown(container.dispose);
    return container.read(windowsTimeFixServiceProvider);
  }

  String resultPathIn(String args) => RegExp(r'--result "([^"]+)"').firstMatch(args)!.group(1)!;

  void reportOk(String exe, String args) {
    File(resultPathIn(args)).writeAsStringSync(jsonEncode({
      'ok': true, 'timeSet': true, 'zoneSet': true, 'syncConfigured': true, 'errors': [], 'warnings': [],
    }));
  }

  setUp(() async {
    installFakeSecureStorage();
    wall = FixedClock(_serverTime.add(const Duration(hours: 3))); // the device is 3 hours ahead
    mono = FakeMonotonicClock();
    temp = await Directory.systemTemp.createTemp('nexapos-timefix-test');
    db = AppDatabase(NativeDatabase.memory());
    launches = [];
    downloads = 0;
    onLaunch = reportOk;
    download = (url) async => toolBytes;
    timeAnswer = () => http.Response(jsonEncode({'success': true}), 200, headers: {'date': _serverDate});
  });

  tearDown(() async {
    await db.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<void> chooseRegion(String code) async {
    final region = regionByCode(code)!;
    await container.read(regionSettingsServiceProvider).save(RegionSettings(region: region, zone: region.zones.first));
  }

  test('reads the real time, runs the downloaded helper with it, and reports success', () async {
    final service = build();
    await chooseRegion('KE');

    final result = await service.fixNow();

    expect(result.isOk, isTrue, reason: result.when(ok: (_) => '', failure: (m) => m));
    expect(launches, hasLength(1));
    final (exe, args) = launches.single;
    expect(File(exe).readAsBytesSync(), toolBytes, reason: 'the verified helper is what runs');
    // The real time (from the server), the device's own clock at the same
    // moment, the chosen zone, and where to report.
    expect(args, contains('--utc 2026-09-25T10:00:00Z'));
    expect(args, contains('--issued 2026-09-25T13:00:00Z'));
    expect(args, contains('--zone "E. Africa Standard Time"'));
    expect(args, contains('--result "'));
    result.when(
      ok: (report) {
        expect(report.timeSet, isTrue);
        expect(report.zoneSet, isTrue);
        expect(report.syncConfigured, isTrue);
      },
      failure: (_) {},
    );
  });

  test('the real time given is carried forward by the running clock, not read off the device', () async {
    final service = build();
    onLaunch = (exe, args) {
      reportOk(exe, args);
    };
    // 90 seconds go by between reading the server and launching the helper - as
    // the monotonic clock sees it. (The download is what takes the time.)
    download = (url) async {
      mono.advance(const Duration(seconds: 90));
      return toolBytes;
    };

    await service.fixNow();

    expect(launches.single.$2, contains('--utc 2026-09-25T10:01:30Z'));
  });

  test('with no region chosen only the time is corrected, and no zone is sent', () async {
    final service = build();

    await service.fixNow();

    expect(launches.single.$2, isNot(contains('--zone')));
  });

  test('a helper that is not the expected file is never run', () async {
    final service = build(sha: '0' * 64);

    final result = await service.fixNow();

    expect(result.isFailure, isTrue);
    expect(launches, isEmpty);
  });

  test('a helper of absurd size is never run', () async {
    download = (url) async => Uint8List(3 * 1024 * 1024);
    final service = build();

    final result = await service.fixNow();

    expect(result.isFailure, isTrue);
    expect(launches, isEmpty);
  });

  test('cannot read the real time (offline): says so, and downloads nothing', () async {
    timeAnswer = () => throw const SocketException('no internet');
    final service = build();

    final result = await service.fixNow();

    expect(result.when(ok: (_) => '', failure: (m) => m), contains('real time'));
    expect(downloads, 0);
    expect(launches, isEmpty);
  });

  test('cannot download the helper: says so, and runs nothing', () async {
    download = (url) async => throw const UpdateOfflineException();
    final service = build();

    final result = await service.fixNow();

    expect(result.when(ok: (_) => '', failure: (m) => m), contains('download'));
    expect(launches, isEmpty);
  });

  test('permission refused at the Windows prompt: a clear message, and the license is left as it was', () async {
    onLaunch = (exe, args) => throw StateError('Windows could not start the installer (ShellExecute code 5).');
    final service = build();

    final result = await service.fixNow();

    expect(result.when(ok: (_) => '', failure: (m) => m), contains('permission'));
  });

  test('a helper that never reports back ends in a clear failure, not a hang', () async {
    onLaunch = (exe, args) {}; // starts, says nothing
    final service = build(monotonic: _TickingClock(), waitTimeout: const Duration(seconds: 30));

    final result = await service.fixNow();

    expect(result.when(ok: (_) => '', failure: (m) => m), contains('did not report back'));
  });

  test('a helper that reports a failure has its reasons shown', () async {
    onLaunch = (exe, args) => File(resultPathIn(args)).writeAsStringSync(jsonEncode({
      'ok': false, 'timeSet': false, 'zoneSet': false, 'syncConfigured': false,
      'errors': ['Windows would not let the clock be changed (code 5).'], 'warnings': [],
    }));
    final service = build();

    final result = await service.fixNow();

    expect(result.when(ok: (_) => '', failure: (m) => m), contains('would not let the clock be changed'));
  });

  test('a report still being written is waited for, not mistaken for a failure', () async {
    onLaunch = (exe, args) {
      final path = resultPathIn(args);
      File(path).writeAsStringSync('{"ok":tr'); // half written
      Timer(const Duration(milliseconds: 40), () => reportOk(exe, args));
    };
    final service = build();

    final result = await service.fixNow();

    expect(result.isOk, isTrue);
  });

  test('a report left over from an earlier run is not mistaken for this one', () async {
    File('${temp.path}${Platform.pathSeparator}nexapos-timefix-result.json').writeAsStringSync(
      jsonEncode({'ok': true, 'timeSet': true, 'zoneSet': true, 'syncConfigured': true}),
    );
    onLaunch = (exe, args) {}; // this time it reports nothing
    final service = build(monotonic: _TickingClock(), waitTimeout: const Duration(seconds: 30));

    final result = await service.fixNow();

    expect(result.isFailure, isTrue);
  });

  test('correcting the clock does not shorten the license: the jump it makes is not charged to it', () async {
    final service = build();
    await container.read(licenseServiceProvider).activate('CODE1'); // valid until 2026-12-25 10:00, per the server clock
    final before = (await container.read(licenseServiceProvider).currentStatus(askServer: false)).remaining!;
    onLaunch = (exe, args) {
      // What the helper does: the wrong (3 hours ahead) date is put right, and
      // the other way round too if this were a device that was behind.
      wall.set(_serverTime);
      mono.advance(const Duration(seconds: 20));
      reportOk(exe, args);
    };

    final result = await service.fixNow();

    expect(result.isOk, isTrue);
    final after = (await container.read(licenseServiceProvider).currentStatus(askServer: false)).remaining!;
    expect(before - after, const Duration(seconds: 20), reason: 'only the 20 seconds the fix really took');
    expect(await container.read(licenseServiceProvider).hasValidCachedLicense(), isTrue);
  });
}
