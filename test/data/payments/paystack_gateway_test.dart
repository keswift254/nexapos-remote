import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/payments/paystack_gateway.dart';

const _baseUrl = 'http://localhost/nexapos_platform/public/index.php';

void main() {
  group('initialize', () {
    test('parses a successful response into authorizationUrl and reference', () async {
      final gateway = PaystackGateway(MockClient((request) async {
        expect(request.url.queryParameters['action'], 'initialize_transaction');
        expect(request.headers['Authorization'], 'Bearer device_api_key_123');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['amount'], 10000); // Money.cents, not major units
        expect(body['return_to_app'], isTrue);
        expect(body.containsKey('metadata'), isFalse, reason: 'the backend builds its own metadata now');
        return http.Response(
          jsonEncode({
            'status': true,
            'data': {'authorization_url': 'https://paystack.test/pay/abc', 'reference': 'REF-1'},
          }),
          200,
        );
      }));

      final result = await gateway.initialize(
        baseUrl: _baseUrl,
        apiKey: 'device_api_key_123',
        amount: const Money(10000),
        reference: 'REF-1',
        email: 'customer@nexapos.co.ke',
        currency: 'KES',
      );

      expect(result.authorizationUrl, 'https://paystack.test/pay/abc');
      expect(result.reference, 'REF-1');
    });

    Future<Map<String, dynamic>> bodySentBy(PaystackGateway Function(http.Client) build) async {
      late Map<String, dynamic> sent;
      final gateway = build(MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'status': true,
            'data': {'authorization_url': 'https://paystack.test/pay/abc', 'reference': 'REF-1'},
          }),
          200,
        );
      }));
      await gateway.initialize(
        baseUrl: _baseUrl,
        apiKey: 'device_api_key_123',
        amount: const Money(10000),
        reference: 'REF-1',
        email: 'customer@nexapos.co.ke',
        currency: 'KES',
      );
      return sent;
    }

    test('the web build asks the server to send the customer back to the web app', () async {
      final body = await bodySentBy((client) => PaystackGateway(client, true));

      expect(body['return_to'], 'web');
      expect(body['return_to_app'], isFalse, reason: 'the nexapos:// link means nothing in a browser');
    });

    test('a native build keeps the nexapos:// return and never asks for the web one', () async {
      final body = await bodySentBy((client) => PaystackGateway(client, false));

      expect(body['return_to_app'], isTrue);
      expect(body.containsKey('return_to'), isFalse);
    });

    test('throws PaystackException with the gateway message when status is false', () async {
      final gateway = PaystackGateway(MockClient((request) async {
        return http.Response(jsonEncode({'status': false, 'message': 'Invalid key'}), 200);
      }));

      expect(
        () => gateway.initialize(
          baseUrl: _baseUrl,
          apiKey: 'bad',
          amount: const Money(10000),
          reference: 'REF-1',
          email: 'customer@nexapos.co.ke',
          currency: 'KES',
        ),
        throwsA(isA<PaystackException>().having((e) => e.message, 'message', 'Invalid key')),
      );
    });

    test('a socket-level failure surfaces as PaystackOfflineException', () async {
      final gateway = PaystackGateway(MockClient((request) async {
        throw const SocketException('no route to host');
      }));

      expect(
        () => gateway.initialize(
          baseUrl: _baseUrl,
          apiKey: 'device_api_key_123',
          amount: const Money(10000),
          reference: 'REF-1',
          email: 'customer@nexapos.co.ke',
          currency: 'KES',
        ),
        throwsA(isA<PaystackOfflineException>()),
      );
    });
  });

  group('verify', () {
    test('reports success only when status, amount, and currency all match', () async {
      final gateway = PaystackGateway(MockClient((request) async {
        expect(request.url.queryParameters['action'], 'verify_transaction');
        expect(request.url.queryParameters['reference'], 'REF-1');
        return http.Response(
          jsonEncode({
            'status': true,
            'data': {'status': 'success', 'amount': 10000, 'currency': 'KES', 'reference': 'REF-1'},
          }),
          200,
        );
      }));

      final result = await gateway.verify(
        baseUrl: _baseUrl,
        apiKey: 'device_api_key_123',
        reference: 'REF-1',
        expectedAmount: const Money(10000),
        currency: 'KES',
      );

      expect(result.success, isTrue);
    });

    test('an amount mismatch is not treated as success', () async {
      final gateway = PaystackGateway(MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': true,
            'data': {'status': 'success', 'amount': 5000, 'currency': 'KES', 'reference': 'REF-1'},
          }),
          200,
        );
      }));

      final result = await gateway.verify(
        baseUrl: _baseUrl,
        apiKey: 'device_api_key_123',
        reference: 'REF-1',
        expectedAmount: const Money(10000),
        currency: 'KES',
      );

      expect(result.success, isFalse);
    });

    test('a still-pending transaction is not treated as success', () async {
      final gateway = PaystackGateway(MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': true,
            'data': {'status': 'abandoned', 'amount': 10000, 'currency': 'KES', 'reference': 'REF-1'},
          }),
          200,
        );
      }));

      final result = await gateway.verify(
        baseUrl: _baseUrl,
        apiKey: 'device_api_key_123',
        reference: 'REF-1',
        expectedAmount: const Money(10000),
        currency: 'KES',
      );

      expect(result.success, isFalse);
    });
  });
}
