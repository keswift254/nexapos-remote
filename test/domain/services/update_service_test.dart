import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:nexapos_mobile/data/update/update_gateway.dart';
import 'package:nexapos_mobile/domain/services/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'NexaPOS',
      packageName: 'com.nexapos.nexapos_mobile',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  group('isNewerVersion', () {
    test('a higher patch version is newer', () {
      expect(isNewerVersion('1.0.1', '1.0.0'), isTrue);
    });

    test('a higher minor version is newer even when the patch is 0', () {
      expect(isNewerVersion('1.1.0', '1.0.9'), isTrue);
    });

    test('compares numerically, not lexicographically (1.10.0 > 1.9.0)', () {
      expect(isNewerVersion('1.10.0', '1.9.0'), isTrue);
    });

    test('an equal version is not newer', () {
      expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
    });

    test('an older version is not newer', () {
      expect(isNewerVersion('1.0.0', '1.0.1'), isFalse);
    });

    test('a shorter version string is padded with zeros, not treated as older by default', () {
      expect(isNewerVersion('1.1', '1.0.9'), isTrue);
    });

    test('a non-numeric segment is treated as 0 rather than throwing', () {
      expect(() => isNewerVersion('1.x.0', '1.0.0'), returnsNormally);
    });
  });

  group('UpdateService.checkForUpdate', () {
    ProviderContainer buildContainer(http.Client updateClient) {
      final container = ProviderContainer(overrides: [
        updateGatewayProvider.overrideWith((ref) => UpdateGateway(updateClient)),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('a higher published version is reported as available', () async {
      final container = buildContainer(MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'version': '1.1.0',
            'windows_url': 'https://example.com/win.zip',
            'android_url': 'https://example.com/app.apk',
          }),
          200,
        );
      }));

      final result = await container.read(updateServiceProvider).checkForUpdate();

      expect(result.currentVersion, '1.0.0');
      expect(result.updateAvailable, isTrue);
      expect(result.latest?.version, '1.1.0');
    });

    test('a published version equal to the current one is not an update', () async {
      final container = buildContainer(MockClient((request) async {
        return http.Response(jsonEncode({'success': true, 'version': '1.0.0', 'windows_url': '', 'android_url': ''}), 200);
      }));

      final result = await container.read(updateServiceProvider).checkForUpdate();

      expect(result.updateAvailable, isFalse);
    });

    test('nothing published yet is not an update', () async {
      final container = buildContainer(MockClient((request) async {
        return http.Response(jsonEncode({'success': false, 'message': 'No version has been published yet.'}), 404);
      }));

      final result = await container.read(updateServiceProvider).checkForUpdate();

      expect(result.updateAvailable, isFalse);
      expect(result.latest, isNull);
    });
  });

  group('UpdateAvailabilityNotifier', () {
    ProviderContainer buildContainer(http.Client updateClient) {
      final container = ProviderContainer(overrides: [
        updateGatewayProvider.overrideWith((ref) => UpdateGateway(updateClient)),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('starts with no update flagged', () {
      final container = buildContainer(MockClient((request) async => http.Response('', 500)));
      expect(container.read(updateAvailabilityProvider), isNull);
    });

    test('check() populates state once a newer version is found', () async {
      final container = buildContainer(MockClient((request) async {
        return http.Response(
          jsonEncode({'success': true, 'version': '2.0.0', 'windows_url': 'https://x/win.zip', 'android_url': 'https://x/app.apk'}),
          200,
        );
      }));

      await container.read(updateAvailabilityProvider.notifier).check();

      expect(container.read(updateAvailabilityProvider)?.version, '2.0.0');
    });

    test('check() swallows a server error rather than throwing (this runs unattended on a timer)', () async {
      final container = buildContainer(MockClient((request) async {
        throw http.ClientException('Connection failed');
      }));

      await expectLater(container.read(updateAvailabilityProvider.notifier).check(), completes);
      expect(container.read(updateAvailabilityProvider), isNull);
    });

    test('applyResult() lets a caller that already checked push the result in directly', () {
      final container = buildContainer(MockClient((request) async => http.Response('', 500)));
      const result = UpdateCheckResult(
        currentVersion: '1.0.0',
        updateAvailable: true,
        latest: LatestVersionInfo(version: '1.2.0', windowsUrl: 'https://x/win.zip', androidUrl: 'https://x/app.apk'),
      );

      container.read(updateAvailabilityProvider.notifier).applyResult(result);

      expect(container.read(updateAvailabilityProvider)?.version, '1.2.0');
    });
  });
}
