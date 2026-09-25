import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/data/licensing/license_gateway.dart';

const _baseUrl = 'http://localhost/nexapos_license/public/index.php';

void main() {
  group('fetchPlans', () {
    test('reads the plans the server lists, in its order', () async {
      final gateway = LicenseGateway(MockClient((request) async {
        expect(request.url.queryParameters['action'], 'plans');
        expect(request.url.queryParameters['v'], '2', reason: 'asks for the format that carries days and the test mark');
        expect(request.method, 'GET');
        return http.Response(jsonEncode({
          'success': true,
          'purchasing_enabled': true,
          'currency': 'KES',
          'plans': [
            {'id': 'm3', 'label': '3 months', 'months': 3, 'amount_kes': 1500},
            {'id': 'm6', 'label': '6 months', 'months': 6, 'amount_kes': 3000},
            {'id': 'm12', 'label': '1 year', 'months': 12, 'amount_kes': 4800},
          ],
        }), 200);
      }));

      final catalog = await gateway.fetchPlans(baseUrl: _baseUrl);

      expect(catalog.purchasingEnabled, isTrue);
      expect(catalog.plans.map((p) => p.id), ['m3', 'm6', 'm12']);
      expect(catalog.plans[1].label, '6 months');
      expect(catalog.plans[1].months, 6);
      expect(catalog.plans[1].amountKes, 3000);
    });

    test('says payments are not available when the server says so, and still lists the plans', () async {
      final gateway = LicenseGateway(MockClient((request) async => http.Response(jsonEncode({
        'success': true,
        'purchasing_enabled': false,
        'plans': [
          {'id': 'm3', 'label': '3 months', 'months': 3, 'amount_kes': 1500},
        ],
      }), 200)));

      final catalog = await gateway.fetchPlans(baseUrl: _baseUrl);

      expect(catalog.purchasingEnabled, isFalse);
      expect(catalog.plans, hasLength(1));
    });

    test('a plan that is not well formed is left out rather than shown wrongly', () async {
      final gateway = LicenseGateway(MockClient((request) async => http.Response(jsonEncode({
        'success': true,
        'purchasing_enabled': true,
        'plans': [
          {'id': 'ok', 'label': 'Fine', 'months': 3, 'amount_kes': 1500},
          {'id': '', 'label': 'No id', 'months': 3, 'amount_kes': 1500},
          {'id': 'free', 'label': 'Free', 'months': 3, 'amount_kes': 0},
          {'id': 'zero', 'label': 'Zero months', 'months': 0, 'amount_kes': 900},
          'not even a map',
          {'id': 'text', 'label': 'Text price', 'months': 3, 'amount_kes': 'cheap'},
        ],
      }), 200)));

      final catalog = await gateway.fetchPlans(baseUrl: _baseUrl);

      expect(catalog.plans.map((p) => p.id), ['ok']);
    });

    test('an unreachable server is an offline error', () async {
      final gateway = LicenseGateway(MockClient((request) async => throw http.ClientException('down')));

      expect(() => gateway.fetchPlans(baseUrl: _baseUrl), throwsA(isA<LicenseOfflineException>()));
    });
  });

  group('startCheckout', () {
    test('sends the device, the plan and the email - and never a price', () async {
      Map<String, dynamic>? sent;
      final gateway = LicenseGateway(MockClient((request) async {
        expect(request.url.queryParameters['action'], 'checkout_start');
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({
          'success': true,
          'reference': 'nxl-abc',
          'authorization_url': 'https://checkout.paystack.com/xyz',
          'plan': {'id': 'm6', 'label': '6 months', 'months': 6, 'amount_kes': 3000},
        }), 200);
      }));

      final checkout = await gateway.startCheckout(
        baseUrl: _baseUrl, deviceId: 'dev-1', planId: 'm6', email: 'a@b.co',
      );

      expect(sent, {'device_id': 'dev-1', 'plan_id': 'm6', 'email': 'a@b.co'});
      expect(checkout.reference, 'nxl-abc');
      expect(checkout.paymentUrl, Uri.parse('https://checkout.paystack.com/xyz'));
      expect(checkout.plan!.amountKes, 3000);
    });

    test('only ever hands back a secure payment page', () async {
      for (final url in ['http://checkout.paystack.com/xyz', 'javascript:alert(1)', '', 'not a url', 'https://']) {
        final gateway = LicenseGateway(MockClient((request) async => http.Response(jsonEncode({
          'success': true,
          'reference': 'nxl-abc',
          'authorization_url': url,
        }), 200)));

        await expectLater(
          gateway.startCheckout(baseUrl: _baseUrl, deviceId: 'd', planId: 'm3', email: 'a@b.co'),
          throwsA(isA<LicenseException>()),
          reason: 'url: "$url"',
        );
      }
    });

    test("a refusal surfaces the server's own message (rate limit, payments off, bad email...)", () async {
      final gateway = LicenseGateway(MockClient((request) async => http.Response(
        jsonEncode({'success': false, 'message': 'Online payment is not available yet. Contact NexaPOS for a license key.'}),
        503,
      )));

      expect(
        () => gateway.startCheckout(baseUrl: _baseUrl, deviceId: 'd', planId: 'm3', email: 'a@b.co'),
        throwsA(isA<LicenseException>().having((e) => e.message, 'message', contains('not available yet'))),
      );
    });

    test('a missing reference is not accepted', () async {
      final gateway = LicenseGateway(MockClient((request) async => http.Response(jsonEncode({
        'success': true,
        'authorization_url': 'https://checkout.paystack.com/xyz',
      }), 200)));

      expect(
        () => gateway.startCheckout(baseUrl: _baseUrl, deviceId: 'd', planId: 'm3', email: 'a@b.co'),
        throwsA(isA<LicenseException>()),
      );
    });
  });

  group('checkoutStatus', () {
    LicenseGateway answering(Map<String, dynamic> body, [int status = 200]) =>
        LicenseGateway(MockClient((request) async {
          expect(request.url.queryParameters['action'], 'checkout_status');
          expect(jsonDecode(request.body), {'reference': 'nxl-abc', 'device_id': 'dev-1'});
          return http.Response(jsonEncode(body), status);
        }));

    Future<PurchaseStatus> ask(LicenseGateway gateway) =>
        gateway.checkoutStatus(baseUrl: _baseUrl, reference: 'nxl-abc', deviceId: 'dev-1');

    test('pending while it is not paid', () async {
      final status = await ask(answering({'success': true, 'status': 'pending'}));

      expect(status.state, PurchaseState.pending);
      expect(status.code, isNull);
    });

    test('issued brings the license key', () async {
      final status = await ask(answering({'success': true, 'status': 'issued', 'code': 'ABCDE23456'}));

      expect(status.state, PurchaseState.issued);
      expect(status.code, 'ABCDE23456');
    });

    test('issued with no key is an error, not a success', () async {
      expect(() => ask(answering({'success': true, 'status': 'issued'})), throwsA(isA<LicenseException>()));
    });

    test("failed brings the server's explanation", () async {
      final status = await ask(answering({'success': true, 'status': 'failed', 'message': 'The payment did not go through.'}));

      expect(status.state, PurchaseState.failed);
      expect(status.message, contains('did not go through'));
    });

    test('anything it does not recognise is treated as still waiting, never as paid', () async {
      final status = await ask(answering({'success': true, 'status': 'something-new'}));

      expect(status.state, PurchaseState.pending);
    });

    test('an unknown payment is an error carrying the server\'s words', () async {
      expect(
        () => ask(answering({'success': false, 'message': 'Unknown payment.'}, 404)),
        throwsA(isA<LicenseException>().having((e) => e.message, 'message', 'Unknown payment.')),
      );
    });
  });

  group('a short test plan (days, marked test)', () {
    LicenseGateway serving(List<Map<String, dynamic>> plans) => LicenseGateway(MockClient((request) async =>
        http.Response(jsonEncode({'success': true, 'purchasing_enabled': true, 'plans': plans}), 200)));

    test('is read: no months, one day, marked as a test', () async {
      final catalog = await serving([
        {'id': 'm3', 'label': '3 months', 'months': 3, 'days': 0, 'amount_kes': 1500, 'test': false},
        {'id': 'test', 'label': 'Test plan', 'months': 0, 'days': 1, 'amount_kes': 5, 'test': true},
      ]).fetchPlans(baseUrl: _baseUrl);

      expect(catalog.plans.map((p) => p.id), ['m3', 'test']);
      final test = catalog.plans.last;
      expect(test.label, 'Test plan');
      expect(test.months, 0);
      expect(test.days, 1);
      expect(test.amountKes, 5);
      expect(test.isTest, isTrue);
      expect(catalog.plans.first.isTest, isFalse);
      expect(catalog.plans.first.days, 0);
    });

    test('a plan from before days and test existed reads as an ordinary month plan', () async {
      final catalog = await serving([
        {'id': 'm6', 'label': '6 months', 'months': 6, 'amount_kes': 3000},
      ]).fetchPlans(baseUrl: _baseUrl);

      expect(catalog.plans.single.days, 0);
      expect(catalog.plans.single.isTest, isFalse);
    });

    test('only an explicit true marks a plan as a test', () async {
      final catalog = await serving([
        {'id': 'a', 'label': 'A', 'months': 1, 'amount_kes': 500, 'test': 'yes'},
        {'id': 'b', 'label': 'B', 'months': 1, 'amount_kes': 500, 'test': 1},
      ]).fetchPlans(baseUrl: _baseUrl);

      expect(catalog.plans.map((p) => p.isTest), [false, false]);
    });

    test('a plan with neither months nor days, or a negative one, is still left out', () async {
      final catalog = await serving([
        {'id': 'none', 'label': 'None', 'months': 0, 'days': 0, 'amount_kes': 500},
        {'id': 'neg', 'label': 'Negative', 'months': 0, 'days': -1, 'amount_kes': 500},
        {'id': 'negm', 'label': 'Negative months', 'months': -1, 'days': 2, 'amount_kes': 500},
        {'id': 'ok', 'label': 'Fine', 'months': 0, 'days': 2, 'amount_kes': 500},
      ]).fetchPlans(baseUrl: _baseUrl);

      expect(catalog.plans.map((p) => p.id), ['ok']);
    });
  });

  group('a lifetime plan', () {
    LicenseGateway serving(List<Map<String, dynamic>> plans) => LicenseGateway(MockClient((request) async =>
        http.Response(jsonEncode({'success': true, 'purchasing_enabled': true, 'plans': plans}), 200)));

    test('is read: no months, no days, marked lifetime', () async {
      final catalog = await serving([
        {'id': 'lifetime', 'label': 'Lifetime', 'months': 0, 'days': 0, 'lifetime': true, 'amount_kes': 4800, 'test': false},
      ]).fetchPlans(baseUrl: _baseUrl);

      final plan = catalog.plans.single;
      expect(plan.lifetime, isTrue);
      expect(plan.months, 0);
      expect(plan.days, 0);
      expect(plan.amountKes, 4800);
      expect(plan.isTest, isFalse);
    });

    test('is read even if the server leaves the month count out', () async {
      final catalog = await serving([
        {'id': 'lifetime', 'label': 'Lifetime', 'lifetime': true, 'amount_kes': 4800},
      ]).fetchPlans(baseUrl: _baseUrl);

      expect(catalog.plans.single.lifetime, isTrue);
    });

    test('an ordinary plan with no length is still left out - only lifetime may have none', () async {
      final catalog = await serving([
        {'id': 'none', 'label': 'None', 'months': 0, 'days': 0, 'lifetime': false, 'amount_kes': 500},
        {'id': 'ok', 'label': 'Fine', 'months': 6, 'days': 0, 'lifetime': false, 'amount_kes': 1500},
      ]).fetchPlans(baseUrl: _baseUrl);

      expect(catalog.plans.map((p) => p.id), ['ok']);
      expect(catalog.plans.single.lifetime, isFalse);
    });

    test('a lifetime plan with a nonsense length or price is left out', () async {
      final catalog = await serving([
        {'id': 'a', 'label': 'A', 'months': -1, 'lifetime': true, 'amount_kes': 500},
        {'id': 'b', 'label': 'B', 'days': -3, 'lifetime': true, 'amount_kes': 500},
        {'id': 'c', 'label': 'C', 'lifetime': true, 'amount_kes': 0},
      ]).fetchPlans(baseUrl: _baseUrl);

      expect(catalog.plans, isEmpty);
    });

    test('only an explicit true makes a plan lifetime', () async {
      final catalog = await serving([
        {'id': 'a', 'label': 'A', 'months': 1, 'lifetime': 'yes', 'amount_kes': 500},
        {'id': 'b', 'label': 'B', 'months': 1, 'lifetime': 1, 'amount_kes': 500},
      ]).fetchPlans(baseUrl: _baseUrl);

      expect(catalog.plans.map((p) => p.lifetime), [false, false]);
    });
  });

  group('restoreStart', () {
    test('asks for a code for this device and email, and returns the server\'s words', () async {
      late Map<String, dynamic> sent;
      final gateway = LicenseGateway(MockClient((request) async {
        expect(request.url.queryParameters['action'], 'restore_start');
        expect(request.method, 'POST');
        sent = (jsonDecode(request.body) as Map).cast<String, dynamic>();
        return http.Response(jsonEncode({'success': true, 'message': 'A code is on its way.'}), 200);
      }));

      final message = await gateway.restoreStart(baseUrl: _baseUrl, deviceId: 'dev-1', email: 'me@shop.co.ke');

      expect(sent, {'device_id': 'dev-1', 'email': 'me@shop.co.ke'});
      expect(message, 'A code is on its way.');
    });

    test('a refusal throws the server\'s own words', () async {
      final gateway = LicenseGateway(MockClient((request) async =>
          http.Response(jsonEncode({'success': false, 'message': 'Too many attempts. Wait a little while, then try again.'}), 429)));

      expect(
        () => gateway.restoreStart(baseUrl: _baseUrl, deviceId: 'd', email: 'a@b.co'),
        throwsA(isA<LicenseException>().having((e) => e.message, 'message', contains('Too many attempts'))),
      );
    });

    test('no connection is an offline error', () async {
      final gateway = LicenseGateway(MockClient((request) async => throw const SocketException('no internet')));

      expect(
        () => gateway.restoreStart(baseUrl: _baseUrl, deviceId: 'd', email: 'a@b.co'),
        throwsA(isA<LicenseOfflineException>()),
      );
    });
  });

  group('restoreConfirm', () {
    test('sends the code with the device and email, and returns the license key', () async {
      late Map<String, dynamic> sent;
      final gateway = LicenseGateway(MockClient((request) async {
        expect(request.url.queryParameters['action'], 'restore_confirm');
        sent = (jsonDecode(request.body) as Map).cast<String, dynamic>();
        return http.Response(jsonEncode({'success': true, 'code': 'ABCDE23456', 'moved': 2}), 200);
      }));

      final key = await gateway.restoreConfirm(baseUrl: _baseUrl, deviceId: 'dev-1', email: 'me@shop.co.ke', code: '123456');

      expect(sent, {'device_id': 'dev-1', 'email': 'me@shop.co.ke', 'code': '123456'});
      expect(key, 'ABCDE23456');
    });

    test('a wrong code throws the server\'s words', () async {
      final gateway = LicenseGateway(MockClient((request) async =>
          http.Response(jsonEncode({'success': false, 'message': 'That code is not right, or it has expired. Ask for a new one.'}), 422)));

      expect(
        () => gateway.restoreConfirm(baseUrl: _baseUrl, deviceId: 'd', email: 'a@b.co', code: '000000'),
        throwsA(isA<LicenseException>().having((e) => e.message, 'message', contains('not right'))),
      );
    });

    test('a success with no key is an error, not a success', () async {
      final gateway = LicenseGateway(MockClient((request) async => http.Response(jsonEncode({'success': true}), 200)));

      expect(
        () => gateway.restoreConfirm(baseUrl: _baseUrl, deviceId: 'd', email: 'a@b.co', code: '123456'),
        throwsA(isA<LicenseException>()),
      );
    });

    test('no connection is an offline error', () async {
      final gateway = LicenseGateway(MockClient((request) async => throw const SocketException('no internet')));

      expect(
        () => gateway.restoreConfirm(baseUrl: _baseUrl, deviceId: 'd', email: 'a@b.co', code: '123456'),
        throwsA(isA<LicenseOfflineException>()),
      );
    });
  });
}
