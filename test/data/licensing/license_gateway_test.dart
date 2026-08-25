import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/data/licensing/license_gateway.dart';

const _baseUrl = 'http://localhost/nexapos_license/public/index.php';

void main() {
  group('activate', () {
    test('parses the returned activation_token', () async {
      final gateway = LicenseGateway(MockClient((request) async {
        expect(request.url.queryParameters['action'], 'activate');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['code'], 'L3RLFCH5KA');
        expect(body['device_id'], 'device-1');
        return http.Response(jsonEncode({'success': true, 'activation_token': 'a' * 64, 'valid_until': null}), 200);
      }));

      final result = await gateway.activate(baseUrl: _baseUrl, code: 'L3RLFCH5KA', deviceId: 'device-1');

      expect(result.token, 'a' * 64);
      expect(result.validUntil, isNull);
    });

    test('parses a real valid_until as UTC, not the device\'s local timezone', () async {
      final gateway = LicenseGateway(MockClient((request) async {
        return http.Response(
          jsonEncode({'success': true, 'activation_token': 'a' * 64, 'valid_until': '2026-09-22 17:44:05'}),
          200,
        );
      }));

      final result = await gateway.activate(baseUrl: _baseUrl, code: 'L3RLFCH5KA', deviceId: 'device-1');

      expect(result.validUntil, DateTime.utc(2026, 9, 22, 17, 44, 5));
    });

    test('a code that was already used surfaces the backend message', () async {
      final gateway = LicenseGateway(MockClient((request) async {
        return http.Response(
          jsonEncode({'success': false, 'message': 'This license key has already been used.'}),
          422,
        );
      }));

      expect(
        () => gateway.activate(baseUrl: _baseUrl, code: 'L3RLFCH5KA', deviceId: 'device-2'),
        throwsA(isA<LicenseException>().having((e) => e.message, 'message', 'This license key has already been used.')),
      );
    });

    test('an unreachable server throws LicenseOfflineException, not LicenseException', () async {
      final gateway = LicenseGateway(MockClient((request) async {
        throw http.ClientException('Connection failed');
      }));

      expect(
        () => gateway.activate(baseUrl: _baseUrl, code: 'L3RLFCH5KA', deviceId: 'device-1'),
        throwsA(isA<LicenseOfflineException>()),
      );
    });
  });

  group('verify', () {
    test('sends the activation token as a Bearer header and parses valid:true', () async {
      final gateway = LicenseGateway(MockClient((request) async {
        expect(request.url.queryParameters['action'], 'verify');
        expect(request.headers['Authorization'], 'Bearer some_token_123');
        return http.Response(jsonEncode({'success': true, 'valid': true, 'valid_until': null}), 200);
      }));

      final result = await gateway.verify(baseUrl: _baseUrl, activationToken: 'some_token_123');

      expect(result.valid, isTrue);
      expect(result.validUntil, isNull);
    });

    test('a revoked license is reported as valid:false, not an exception', () async {
      final gateway = LicenseGateway(MockClient((request) async {
        return http.Response(jsonEncode({'success': true, 'valid': false}), 200);
      }));

      final result = await gateway.verify(baseUrl: _baseUrl, activationToken: 'revoked_token');

      expect(result.valid, isFalse);
    });

    test('parses a real valid_until as UTC', () async {
      final gateway = LicenseGateway(MockClient((request) async {
        return http.Response(
          jsonEncode({'success': true, 'valid': true, 'valid_until': '2026-12-01 00:00:00'}),
          200,
        );
      }));

      final result = await gateway.verify(baseUrl: _baseUrl, activationToken: 'some_token_123');

      expect(result.validUntil, DateTime.utc(2026, 12, 1));
    });
  });
}
