import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/data/payments/paystack_gateway.dart' show PaystackException;
import 'package:nexapos_mobile/data/payments/platform_onboarding_gateway.dart';

const _baseUrl = 'http://localhost/nexapos_platform/public/index.php';

void main() {
  group('registerDevice', () {
    test('parses the returned api_key and sends the registration secret', () async {
      final gateway = PlatformOnboardingGateway(MockClient((request) async {
        expect(request.url.queryParameters['action'], 'register_device');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['device_id'], 'device-1');
        expect(body['device_label'], 'Corner Shop');
        expect(body['registration_secret'], 'secret-abc');
        return http.Response(jsonEncode({'success': true, 'api_key': 'newly_issued_key'}), 201);
      }));

      final result = await gateway.registerDevice(
        baseUrl: _baseUrl,
        deviceId: 'device-1',
        deviceLabel: 'Corner Shop',
        registrationSecret: 'secret-abc',
      );

      expect(result.apiKey, 'newly_issued_key');
    });

    test('a 409 (already registered) surfaces the backend message', () async {
      final gateway = PlatformOnboardingGateway(MockClient((request) async {
        return http.Response(jsonEncode({'success': false, 'message': 'This device is already registered.'}), 409);
      }));

      expect(
        () => gateway.registerDevice(
          baseUrl: _baseUrl,
          deviceId: 'device-1',
          deviceLabel: 'Corner Shop',
          registrationSecret: 'secret-abc',
        ),
        throwsA(isA<PaystackException>().having((e) => e.message, 'message', 'This device is already registered.')),
      );
    });
  });

  group('saveSettlementDetails', () {
    test('parses subaccount_code, is_verified, and account_name', () async {
      final gateway = PlatformOnboardingGateway(MockClient((request) async {
        expect(request.url.queryParameters['action'], 'save_settlement_details');
        expect(request.headers['Authorization'], 'Bearer device_api_key_123');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['settlement_type'], 'bank');
        return http.Response(
          jsonEncode({
            'success': true,
            'subaccount_code': 'ACCT_abc123',
            'is_verified': true,
            'account_name': 'Corner Shop Ltd',
          }),
          200,
        );
      }));

      final result = await gateway.saveSettlementDetails(
        baseUrl: _baseUrl,
        apiKey: 'device_api_key_123',
        businessName: 'Corner Shop',
        settlementType: 'bank',
        bankCode: '011',
        accountNumber: '1234567890',
      );

      expect(result.subaccountCode, 'ACCT_abc123');
      expect(result.isVerified, isTrue);
      expect(result.accountName, 'Corner Shop Ltd');
    });

    test('a Paystack-side rejection (e.g. bad account number) surfaces the message', () async {
      final gateway = PlatformOnboardingGateway(MockClient((request) async {
        return http.Response(jsonEncode({'success': false, 'message': 'Could not resolve account number.'}), 422);
      }));

      expect(
        () => gateway.saveSettlementDetails(
          baseUrl: _baseUrl,
          apiKey: 'device_api_key_123',
          businessName: 'Corner Shop',
          settlementType: 'bank',
          bankCode: '011',
          accountNumber: 'not-a-real-number',
        ),
        throwsA(isA<PaystackException>().having((e) => e.message, 'message', 'Could not resolve account number.')),
      );
    });
  });

  group('getClientStatus', () {
    test('parses a fully-settled client', () async {
      final gateway = PlatformOnboardingGateway(MockClient((request) async {
        expect(request.url.queryParameters['action'], 'client_status');
        return http.Response(
          jsonEncode({
            'success': true,
            'status': 'active',
            'business_name': 'Corner Shop',
            'settlement_type': 'mpesa',
            'bank_code': 'MPTILL',
            'account_number': '9230903',
            'account_name': 'Corner Shop Ltd',
            'subaccount_code': 'ACCT_abc123',
            'is_verified': true,
          }),
          200,
        );
      }));

      final status = await gateway.getClientStatus(baseUrl: _baseUrl, apiKey: 'device_api_key_123');

      expect(status.isSettled, isTrue);
      expect(status.bankCode, 'MPTILL');
      expect(status.accountNumber, '9230903');
    });

    test('parses a not-yet-settled client', () async {
      final gateway = PlatformOnboardingGateway(MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'status': 'pending_settlement',
            'business_name': null,
            'settlement_type': null,
            'bank_code': null,
            'account_number': null,
            'account_name': null,
            'subaccount_code': null,
            'is_verified': false,
          }),
          200,
        );
      }));

      final status = await gateway.getClientStatus(baseUrl: _baseUrl, apiKey: 'device_api_key_123');

      expect(status.isSettled, isFalse);
    });
  });

  group('listDevices', () {
    test('parses devices, marking the owner and disabled ones', () async {
      final gateway = PlatformOnboardingGateway(MockClient((request) async {
        expect(request.url.queryParameters['action'], 'list_devices');
        expect(request.headers['Authorization'], 'Bearer owner_key');
        return http.Response(
          jsonEncode({
            'success': true,
            'devices': [
              {'id': 3, 'device_label': 'Counter PC', 'is_owner': true, 'status': 'active'},
              {'id': 5, 'device_label': 'Cashier Phone', 'is_owner': false, 'status': 'active'},
              {'id': 7, 'device_label': 'Old Phone', 'is_owner': false, 'status': 'disabled'},
            ],
          }),
          200,
        );
      }));

      final devices = await gateway.listDevices(baseUrl: _baseUrl, apiKey: 'owner_key');

      expect(devices, hasLength(3));
      expect(devices.where((d) => d.isOwner).single.deviceLabel, 'Counter PC');
      expect(devices.where((d) => d.isDisabled).single.deviceLabel, 'Old Phone');
    });

    test('a non-owner device calling this surfaces the backend rejection', () async {
      final gateway = PlatformOnboardingGateway(MockClient((request) async {
        return http.Response(
          jsonEncode({'success': false, 'message': 'Only the device that originally set up this shop can manage devices.'}),
          403,
        );
      }));

      expect(
        () => gateway.listDevices(baseUrl: _baseUrl, apiKey: 'non_owner_key'),
        throwsA(isA<PaystackException>().having(
          (e) => e.message,
          'message',
          'Only the device that originally set up this shop can manage devices.',
        )),
      );
    });
  });

  group('revokeDevice', () {
    test('sends the target client_id and succeeds on a 200', () async {
      final gateway = PlatformOnboardingGateway(MockClient((request) async {
        expect(request.url.queryParameters['action'], 'revoke_device');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['client_id'], 5);
        return http.Response(jsonEncode({'success': true}), 200);
      }));

      await gateway.revokeDevice(baseUrl: _baseUrl, apiKey: 'owner_key', clientId: 5);
    });

    test('revoking your own device surfaces the backend rejection rather than silently succeeding', () async {
      final gateway = PlatformOnboardingGateway(MockClient((request) async {
        return http.Response(
          jsonEncode({'success': false, 'message': 'You cannot revoke the device you are currently using.'}),
          422,
        );
      }));

      expect(
        () => gateway.revokeDevice(baseUrl: _baseUrl, apiKey: 'owner_key', clientId: 3),
        throwsA(isA<PaystackException>().having(
          (e) => e.message,
          'message',
          'You cannot revoke the device you are currently using.',
        )),
      );
    });
  });

  group('listBanks', () {
    test('parses bank entries, distinguishing mobile money from regular banks', () async {
      final gateway = PlatformOnboardingGateway(MockClient((request) async {
        expect(request.url.queryParameters['action'], 'list_banks');
        return http.Response(
          jsonEncode({
            'success': true,
            'banks': [
              {'name': 'Equity Bank', 'code': '068', 'type': 'kepss'},
              {'name': 'M-PESA', 'code': 'MPESA', 'type': 'mobile_money'},
              {'name': 'M-PESA Till', 'code': 'MPTILL', 'type': 'mobile_money_business'},
            ],
          }),
          200,
        );
      }));

      final banks = await gateway.listBanks(baseUrl: _baseUrl, apiKey: 'device_api_key_123');

      expect(banks, hasLength(3));
      expect(banks.where((b) => b.isMobileMoney).map((b) => b.name), containsAll(['M-PESA', 'M-PESA Till']));
      expect(banks.where((b) => !b.isMobileMoney).single.name, 'Equity Bank');
    });
  });
}
