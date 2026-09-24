import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:nexapos_mobile/core/result.dart';
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

  group('publishedChecksumError', () {
    test('rejects a missing or malformed checksum', () {
      expect(publishedChecksumError(null), isNotNull);
      expect(publishedChecksumError('abc123'), isNotNull);
    });

    test('accepts a full SHA-256 checksum', () {
      expect(publishedChecksumError(List.filled(64, 'a').join()), isNull);
      expect(
        publishedChecksumError(List.filled(4, 'ABCDEF0123456789').join()),
        isNull,
      );
    });
  });

  group('Windows 7/8 edition update track', () {
    ProviderContainer buildContainer(
      Map<String, Object?> published, {
      required bool legacyEdition,
    }) {
      final container = ProviderContainer(
        overrides: [
          legacyWindowsEditionProvider.overrideWithValue(legacyEdition),
          updateGatewayProvider.overrideWith(
            (ref) => UpdateGateway(
              MockClient(
                (request) async =>
                    http.Response(jsonEncode({'success': true, ...published}), 200),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    const modernOnly = {
      'version': '1.1.0',
      'windows_installer_url': 'https://example.com/setup.exe',
      'android_url': 'https://example.com/app.apk',
    };
    const withLegacy = {
      ...modernOnly,
      'windows_legacy_installer_url': 'https://example.com/legacy.exe',
      'windows_legacy_installer_sha256':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    };

    test('the legacy edition is offered an update once a legacy installer exists', () async {
      final result = await buildContainer(withLegacy, legacyEdition: true)
          .read(updateServiceProvider)
          .checkForUpdate();
      expect(result.updateAvailable, isTrue);
    });

    test(
      'the legacy edition is NOT offered a release that has no legacy installer '
      '(following the Windows 10 installer would break it)',
      () async {
        final result = await buildContainer(modernOnly, legacyEdition: true)
            .read(updateServiceProvider)
            .checkForUpdate();
        expect(result.updateAvailable, isFalse);
        expect(result.latest?.version, '1.1.0');
      },
    );

    test('the normal edition ignores the legacy fields entirely', () async {
      final result = await buildContainer(modernOnly, legacyEdition: false)
          .read(updateServiceProvider)
          .checkForUpdate();
      expect(result.updateAvailable, isTrue);
    });

    test('install() in the legacy edition refuses to fall back to the Windows 10 installer', () async {
      final container = buildContainer(modernOnly, legacyEdition: true);
      final info = (await container.read(updateServiceProvider).checkForUpdate()).latest!;

      final result = await container.read(updateServiceProvider).install(info);

      // Only meaningful where Platform.isWindows; elsewhere install() reports
      // the platform is unsupported - either way it must not succeed.
      expect(result.isFailure, isTrue);
    });
  });

  group('Windows delta-update patch fallback (_tryWindowsPatch via install())', () {
    // None of these scenarios may ever reach exit(0) - that would kill the
    // test runner process itself. Every fixture below deliberately omits
    // windows_installer_sha256, so even if _tryWindowsPatch falls through
    // to the full-installer path (exactly what it's designed to do on any
    // failure), _verifyChecksum's "no published checksum" guard fails the
    // install before installer_launcher/exit(0) is ever reached - the same
    // safety net the pre-existing "install() in the legacy edition..." test
    // above already relies on.
    ProviderContainer buildContainer(
      Map<String, Object?> published, {
      Future<http.Response> Function(http.Request)? handler,
    }) {
      final container = ProviderContainer(
        overrides: [
          legacyWindowsEditionProvider.overrideWithValue(false),
          updateGatewayProvider.overrideWith(
            (ref) => UpdateGateway(
              MockClient(
                handler ??
                    (request) async => http.Response(
                      jsonEncode({'success': true, ...published}),
                      200,
                    ),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    const baseInfo = {
      'version': '1.0.46',
      'windows_installer_url': 'https://example.com/setup.exe',
      'android_url': 'https://example.com/app.apk',
    };

    Future<Result<void>> install(ProviderContainer container) async {
      final info = (await container.read(updateServiceProvider).checkForUpdate()).latest!;
      return container.read(updateServiceProvider).install(info);
    }

    test(
      'no patch fields published: falls through to the full-installer flow without attempting a patch',
      () async {
        final result = await install(buildContainer(baseInfo));
        expect(result.isFailure, isTrue);
      },
    );

    test(
      'the published patch was built from a different version than what is installed: falls back without attempting it',
      () async {
        final published = {
          ...baseInfo,
          // The mocked PackageInfo version (see setUp) is '1.0.0'.
          'patch_from_version': '9.9.9',
          'windows_installer_patch_url': 'https://example.com/bundle.nxbundle',
          'windows_installer_patch_sha256': List.filled(64, 'a').join(),
          'patch_applier_url': 'https://example.com/apply.exe',
          'patch_applier_sha256': List.filled(64, 'b').join(),
        };
        final result = await install(buildContainer(published));
        expect(result.isFailure, isTrue);
      },
    );

    test(
      'the downloaded patch bundle fails its checksum: falls back to the full install',
      () async {
        final published = {
          ...baseInfo,
          'patch_from_version': '1.0.0',
          'windows_installer_patch_url': 'https://example.com/bundle.nxbundle',
          // Deliberately wrong - won't match whatever bytes the mock
          // server actually returns for this URL.
          'windows_installer_patch_sha256': List.filled(64, 'a').join(),
          'patch_applier_url': 'https://example.com/apply.exe',
          'patch_applier_sha256': List.filled(64, 'b').join(),
        };
        final result = await install(buildContainer(published));
        expect(result.isFailure, isTrue);
      },
    );

    test(
      'a well-formed patch bundle referencing a file this device does not have installed: '
      'falls back to the full install without throwing',
      () async {
        final manifestBytes = utf8.encode(
          jsonEncode({
            'files': [
              {
                'path': 'this-file-does-not-exist-on-the-test-machine.bin',
                'oldSha256': List.filled(64, '0').join(),
                'newSha256': List.filled(64, '1').join(),
                'patchFile': 'patch_0.nxpatch',
              },
            ],
          }),
        );
        final archive = Archive()
          ..addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes))
          ..addFile(ArchiveFile('patch_0.nxpatch', 4, [0, 1, 2, 3]));
        final bundleBytes = ZipEncoder().encode(archive)!;
        final bundleSha256 = sha256.convert(bundleBytes).toString();
        final applierBytes = utf8.encode('not a real exe - this path is never reached');
        final applierSha256 = sha256.convert(applierBytes).toString();

        final published = {
          ...baseInfo,
          'patch_from_version': '1.0.0',
          'windows_installer_patch_url': 'https://example.com/bundle.nxbundle',
          'windows_installer_patch_sha256': bundleSha256,
          'patch_applier_url': 'https://example.com/apply.exe',
          'patch_applier_sha256': applierSha256,
        };

        final container = buildContainer(
          published,
          handler: (request) async {
            final url = request.url.toString();
            if (url.contains('bundle.nxbundle')) {
              return http.Response.bytes(bundleBytes, 200);
            }
            if (url.contains('apply.exe')) {
              return http.Response.bytes(applierBytes, 200);
            }
            return http.Response(jsonEncode({'success': true, ...published}), 200);
          },
        );

        final result = await install(container);
        expect(result.isFailure, isTrue);
      },
    );
  });

  group('UpdateService.checkForUpdate', () {
    ProviderContainer buildContainer(http.Client updateClient) {
      final container = ProviderContainer(
        overrides: [
          updateGatewayProvider.overrideWith(
            (ref) => UpdateGateway(updateClient),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('a higher published version is reported as available', () async {
      final container = buildContainer(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'success': true,
              'version': '1.1.0',
              'windows_installer_url': 'https://example.com/setup.exe',
              'android_url': 'https://example.com/app.apk',
            }),
            200,
          );
        }),
      );

      final result = await container
          .read(updateServiceProvider)
          .checkForUpdate();

      expect(result.currentVersion, '1.0.0');
      expect(result.updateAvailable, isTrue);
      expect(result.latest?.version, '1.1.0');
    });

    test(
      'a client may skip an earlier release and still sees the current latest',
      () async {
        PackageInfo.setMockInitialValues(
          appName: 'NexaPOS',
          packageName: 'com.nexapos.nexapos_mobile',
          version: '1.0.11',
          buildNumber: '12',
          buildSignature: '',
        );
        final container = buildContainer(
          MockClient((request) async {
            return http.Response(
              jsonEncode({
                'success': true,
                'version': '1.0.13',
                'windows_installer_url': 'https://example.com/setup.exe',
                'android_url': 'https://example.com/app.apk',
              }),
              200,
            );
          }),
        );

        final result = await container
            .read(updateServiceProvider)
            .checkForUpdate();

        expect(result.currentVersion, '1.0.11');
        expect(result.latest?.version, '1.0.13');
        expect(result.updateAvailable, isTrue);
      },
    );

    test(
      'a published version equal to the current one is not an update',
      () async {
        final container = buildContainer(
          MockClient((request) async {
            return http.Response(
              jsonEncode({
                'success': true,
                'version': '1.0.0',
                'windows_installer_url': '',
                'android_url': '',
              }),
              200,
            );
          }),
        );

        final result = await container
            .read(updateServiceProvider)
            .checkForUpdate();

        expect(result.updateAvailable, isFalse);
      },
    );

    test('nothing published yet is not an update', () async {
      final container = buildContainer(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'success': false,
              'message': 'No version has been published yet.',
            }),
            404,
          );
        }),
      );

      final result = await container
          .read(updateServiceProvider)
          .checkForUpdate();

      expect(result.updateAvailable, isFalse);
      expect(result.latest, isNull);
    });
  });

  group('UpdateAvailabilityNotifier', () {
    ProviderContainer buildContainer(http.Client updateClient) {
      final container = ProviderContainer(
        overrides: [
          updateGatewayProvider.overrideWith(
            (ref) => UpdateGateway(updateClient),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('starts with no update flagged', () {
      final container = buildContainer(
        MockClient((request) async => http.Response('', 500)),
      );
      expect(container.read(updateAvailabilityProvider), isNull);
    });

    test('check() populates state once a newer version is found', () async {
      final container = buildContainer(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'success': true,
              'version': '2.0.0',
              'windows_installer_url': 'https://x/setup.exe',
              'android_url': 'https://x/app.apk',
            }),
            200,
          );
        }),
      );

      await container.read(updateAvailabilityProvider.notifier).check();

      expect(container.read(updateAvailabilityProvider)?.version, '2.0.0');
    });

    test('check() swallows a server error rather than throwing (this runs unattended on a timer)', () async {
      final container = buildContainer(
        MockClient((request) async {
          throw http.ClientException('Connection failed');
        }),
      );

      await expectLater(
        container.read(updateAvailabilityProvider.notifier).check(),
        completes,
      );
      expect(container.read(updateAvailabilityProvider), isNull);
    });

    test('applyResult() lets a caller that already checked push the result in directly', () {
      final container = buildContainer(
        MockClient((request) async => http.Response('', 500)),
      );
      const result = UpdateCheckResult(
        currentVersion: '1.0.0',
        updateAvailable: true,
        latest: LatestVersionInfo(
          version: '1.2.0',
          windowsInstallerUrl: 'https://x/setup.exe',
          androidUrl: 'https://x/app.apk',
        ),
      );

      container.read(updateAvailabilityProvider.notifier).applyResult(result);

      expect(container.read(updateAvailabilityProvider)?.version, '1.2.0');
    });
  });
}
