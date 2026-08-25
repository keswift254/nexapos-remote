import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as path;
import 'package:nexapos_mobile/data/update/update_gateway.dart';

void main() {
  group('fetchLatestVersion', () {
    test('parses a published version', () async {
      final gateway = UpdateGateway(MockClient((request) async {
        expect(request.url.queryParameters['action'], 'latest_version');
        return http.Response(
          jsonEncode({
            'success': true,
            'version': '1.0.1',
            'windows_url': 'https://example.com/NexaPOS-Windows.zip',
            'android_url': 'https://example.com/NexaPOS.apk',
            'release_notes': 'Bug fixes',
          }),
          200,
        );
      }));

      final result = await gateway.fetchLatestVersion();

      expect(result, isNotNull);
      expect(result!.version, '1.0.1');
      expect(result.windowsUrl, 'https://example.com/NexaPOS-Windows.zip');
      expect(result.androidUrl, 'https://example.com/NexaPOS.apk');
      expect(result.releaseNotes, 'Bug fixes');
    });

    test('parses published checksums when present', () async {
      final gateway = UpdateGateway(MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'version': '1.0.1',
            'windows_url': 'https://example.com/NexaPOS-Windows.zip',
            'android_url': 'https://example.com/NexaPOS.apk',
            'windows_sha256': 'abc123',
            'android_sha256': 'def456',
          }),
          200,
        );
      }));

      final result = await gateway.fetchLatestVersion();

      expect(result!.windowsSha256, 'abc123');
      expect(result.androidSha256, 'def456');
    });

    test('an older published version with no checksum yet parses as null, not a blank string', () async {
      final gateway = UpdateGateway(MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'version': '1.0.1',
            'windows_url': 'https://example.com/NexaPOS-Windows.zip',
            'android_url': 'https://example.com/NexaPOS.apk',
          }),
          200,
        );
      }));

      final result = await gateway.fetchLatestVersion();

      expect(result!.windowsSha256, isNull);
      expect(result.androidSha256, isNull);
    });

    test('nothing published yet returns null, not an exception', () async {
      final gateway = UpdateGateway(MockClient((request) async {
        return http.Response(
          jsonEncode({'success': false, 'message': 'No version has been published yet.'}),
          404,
        );
      }));

      final result = await gateway.fetchLatestVersion();

      expect(result, isNull);
    });

    test('an unreachable server throws UpdateOfflineException, not UpdateException', () async {
      final gateway = UpdateGateway(MockClient((request) async {
        throw http.ClientException('Connection failed');
      }));

      expect(() => gateway.fetchLatestVersion(), throwsA(isA<UpdateOfflineException>()));
    });

    test('a real server-side error surfaces its message', () async {
      final gateway = UpdateGateway(MockClient((request) async {
        return http.Response(jsonEncode({'success': false, 'message': 'Something broke.'}), 500);
      }));

      expect(
        () => gateway.fetchLatestVersion(),
        throwsA(isA<UpdateException>().having((e) => e.message, 'message', 'Something broke.')),
      );
    });
  });

  group('downloadTo', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('update_gateway_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('refuses a non-HTTPS URL without even attempting the request', () async {
      var requestAttempted = false;
      final gateway = UpdateGateway(MockClient((request) async {
        requestAttempted = true;
        return http.Response.bytes([1, 2, 3], 200);
      }));
      final destination = File(path.join(tempDir.path, 'update.zip'));

      await expectLater(
        () => gateway.downloadTo('http://example.com/update.zip', destination),
        throwsA(isA<UpdateException>()),
      );
      expect(requestAttempted, isFalse, reason: 'must reject before ever sending the request');
    });

    test('streams the response body to the destination file', () async {
      final bytes = List<int>.generate(5000, (i) => i % 256);
      final gateway = UpdateGateway(MockClient((request) async {
        return http.Response.bytes(bytes, 200);
      }));
      final destination = File(path.join(tempDir.path, 'update.zip'));

      await gateway.downloadTo('https://example.com/update.zip', destination);

      expect(await destination.readAsBytes(), bytes);
    });

    test('reports progress as chunks arrive', () async {
      final bytes = List<int>.generate(5000, (i) => i % 256);
      final gateway = UpdateGateway(MockClient((request) async {
        return http.Response.bytes(bytes, 200);
      }));
      final destination = File(path.join(tempDir.path, 'update.zip'));

      final progressUpdates = <int>[];
      await gateway.downloadTo(
        'https://example.com/update.zip',
        destination,
        onProgress: (received, total) {
          progressUpdates.add(received);
          expect(total, bytes.length);
        },
      );

      expect(progressUpdates, isNotEmpty);
      expect(progressUpdates.last, bytes.length);
    });

    test('creates the destination directory if it does not exist yet', () async {
      final gateway = UpdateGateway(MockClient((request) async {
        return http.Response.bytes([1, 2, 3], 200);
      }));
      final destination = File(path.join(tempDir.path, 'nested', 'update.zip'));

      await gateway.downloadTo('https://example.com/update.zip', destination);

      expect(await destination.exists(), isTrue);
    });

    test('a 4xx/5xx response throws UpdateException instead of writing a partial file', () async {
      final gateway = UpdateGateway(MockClient((request) async {
        return http.Response('not found', 404);
      }));
      final destination = File(path.join(tempDir.path, 'update.zip'));

      await expectLater(
        () => gateway.downloadTo('https://example.com/update.zip', destination),
        throwsA(isA<UpdateException>()),
      );
      expect(await destination.exists(), isFalse);
    });

    test('an unreachable server throws UpdateOfflineException', () async {
      final gateway = UpdateGateway(MockClient((request) async {
        throw http.ClientException('Connection failed');
      }));
      final destination = File(path.join(tempDir.path, 'update.zip'));

      expect(
        () => gateway.downloadTo('https://example.com/update.zip', destination),
        throwsA(isA<UpdateOfflineException>()),
      );
    });
  });
}
