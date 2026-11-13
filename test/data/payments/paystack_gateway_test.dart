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
      expect(result.status, 'abandoned', reason: 'the status is handed on so the screen can tell a finished prompt from a waiting one');
    });

    test('the status is lower case, and empty when the answer has none', () async {
      PaystackGateway answering(Map<String, dynamic> data) => PaystackGateway(MockClient((request) async {
            return http.Response(jsonEncode({'status': true, 'data': data}), 200);
          }));
      final loud = await answering({'status': ' PAY_OFFLINE ', 'amount': 10000, 'currency': 'KES'}).verify(
        baseUrl: _baseUrl, apiKey: 'k', reference: 'REF-1', expectedAmount: const Money(10000), currency: 'KES',
      );
      expect(loud.status, 'pay_offline');
      final none = await answering({'amount': 10000}).verify(
        baseUrl: _baseUrl, apiKey: 'k', reference: 'REF-1', expectedAmount: const Money(10000), currency: 'KES',
      );
      expect(none.status, '');
    });
  });

  group('chargeMobileMoney (the M-Pesa prompt)', () {
    Future<PaystackChargeResult> charge(http.Client client) => PaystackGateway(client).chargeMobileMoney(
          baseUrl: _baseUrl,
          apiKey: 'device_api_key_123',
          amount: const Money(12000),
          reference: 'REF-1',
          currency: 'KES',
          phone: '0712 345 678',
        );

    test('asks the server to send the prompt, with the number as typed, and opens no page', () async {
      late http.Request sent;
      final result = await charge(MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'status': true,
            'data': {'reference': 'REF-1', 'status': 'pay_offline', 'display_text': 'Please complete authorization process on your mobile phone'},
          }),
          200,
        );
      }));

      expect(sent.method, 'POST');
      expect(sent.url.queryParameters['action'], 'charge_mobile_money');
      expect(sent.headers['Authorization'], 'Bearer device_api_key_123');
      expect(jsonDecode(sent.body), {'amount': 12000, 'currency': 'KES', 'reference': 'REF-1', 'phone': '0712 345 678'});
      expect(result.reference, 'REF-1');
      expect(result.status, 'pay_offline');
    });

    test('a prompt that is pending, or already paid, was still sent', () async {
      for (final status in ['pending', 'success']) {
        final result = await charge(MockClient((request) async {
          return http.Response(jsonEncode({'status': true, 'data': {'reference': 'REF-1', 'status': status}}), 200);
        }));
        expect(result.status, status);
      }
    });

    test('the reference falls back to the one sent when the answer has none', () async {
      final result = await charge(MockClient((request) async {
        return http.Response(jsonEncode({'status': true, 'data': {'status': 'pay_offline'}}), 200);
      }));
      expect(result.reference, 'REF-1');
    });

    test('a prompt that was not sent throws the server\'s own words', () async {
      expect(
        () => charge(MockClient((request) async {
          return http.Response(jsonEncode({'status': false, 'message': 'The M-Pesa prompt could not be sent: invalid phone'}), 422);
        })),
        throwsA(isA<PaystackException>().having((e) => e.message, 'message', 'The M-Pesa prompt could not be sent: invalid phone')),
      );
    });

    test('an answer that says it failed is a refusal, even if the rest of it looks like a sent prompt', () async {
      expect(
        () => charge(MockClient((request) async {
          return http.Response(
            jsonEncode({'status': false, 'message': 'Declined by the processor', 'data': {'reference': 'REF-1', 'status': 'pay_offline'}}),
            200,
          );
        })),
        throwsA(isA<PaystackException>().having((e) => e.message, 'message', 'Declined by the processor')),
      );
    });

    test('an answer that says ok but is not a sent prompt is refused', () async {
      for (final status in ['failed', 'abandoned', 'send_otp', '']) {
        expect(
          () => charge(MockClient((request) async {
            return http.Response(jsonEncode({'status': true, 'message': 'Charge attempted', 'data': {'reference': 'REF-1', 'status': status}}), 200);
          })),
          throwsA(isA<PaystackException>()),
          reason: 'status "$status" must not count as a sent prompt',
        );
      }
    });

    test('no connection is reported as offline, not as a refused prompt', () async {
      expect(
        () => charge(MockClient((request) async => throw http.ClientException('no network'))),
        throwsA(isA<PaystackOfflineException>()),
      );
    });
  });
}
