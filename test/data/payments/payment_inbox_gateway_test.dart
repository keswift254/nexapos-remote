import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/payments/payment_inbox_gateway.dart';
import 'package:nexapos_mobile/data/payments/platform_http_client.dart';

/// The app's side of the shop's payment inbox (the platform's payment_inbox_* actions): what is sent, and how every answer
/// - and every refusal - is read.
void main() {
  const base = 'https://sync.test/index.php';
  const key = 'device-key';
  final requests = <http.Request>[];

  PaymentInboxGateway gateway(int status, Object body) => PaymentInboxGateway(MockClient((request) async {
        requests.add(request);
        return http.Response(body is String ? body : jsonEncode(body), status, headers: {'content-type': 'application/json'});
      }));

  setUp(requests.clear);

  Map<String, dynamic> paymentJson(String code, {int? amount = 50000, bool received = true, Map<String, dynamic>? used}) => {
        'code': code,
        'message_received': received,
        'amount_cents': amount,
        'payer_name': 'JOHN DOE',
        'payer_phone': '254712345678',
        'account_ref': null,
        'paid_at_text': '18/11/26 1:05 PM',
        'message': '...',
        'received_at': '2026-11-18T10:05:09Z',
        'phone_label': 'iPhone 11',
        'used': used,
      };

  group('normalizeMpesaCode (the platform\'s own rule)', () {
    test('capitals, no spaces or dashes', () {
      expect(normalizeMpesaCode(' ukh3 r3nl-tu '), 'UKH3R3NLTU');
      expect(normalizeMpesaCode('UKH3R3N1'), 'UKH3R3N1');
      expect(normalizeMpesaCode('UKH3R3NLTU12'), 'UKH3R3NLTU12');
    });
    test('8 to 12 characters, letters AND numbers, nothing else', () {
      for (final bad in ['', '   ', 'UKH3R3N', 'UKH3R3NLTU123', 'ABCDEFGHIJ', '1234567890', 'UKH3R3NL!U']) {
        expect(normalizeMpesaCode(bad), isNull, reason: bad);
      }
    });
  });

  group('list', () {
    test('asks with the device key for the hours wanted, and reads the payments and the number of phones', () async {
      final result = await gateway(200, {
        'success': true,
        'phones': 2,
        'payments': [
          paymentJson('SJK2TILL9X'),
          paymentJson('TYP3DCODE1', amount: null, received: false, used: {'sale_id': 's', 'sale_number': 'N-1', 'amount_cents': 300, 'at': null}),
          {'code': '', 'message_received': true},
          'not a row',
        ],
      }).list(baseUrl: base, apiKey: key, hours: 6);
      expect(requests.single.method, 'GET');
      expect(requests.single.url.queryParameters, {'action': 'payment_inbox_list', 'hours': '6'});
      expect(requests.single.headers['Authorization'], 'Bearer device-key');
      expect(result.phones, 2);
      expect(result.payments.map((p) => p.code), ['SJK2TILL9X', 'TYP3DCODE1']);
      final first = result.payments.first;
      expect(first.messageReceived, isTrue);
      expect(first.amount, const Money(50000));
      expect(first.payerName, 'JOHN DOE');
      expect(first.paidAtText, '18/11/26 1:05 PM');
      expect(first.receivedAt, DateTime.utc(2026, 11, 18, 10, 5, 9));
      expect(first.phoneLabel, 'iPhone 11');
      expect(first.isUsed, isFalse);
      final typed = result.payments.last;
      expect(typed.messageReceived, isFalse);
      expect(typed.amount, isNull);
      expect(typed.isUsed, isTrue);
      expect(typed.usedOnSaleNumber, 'N-1');
      expect(typed.usedAmount, const Money(300));
    });

    test('the hours are kept between 1 and 72', () async {
      await gateway(200, {'success': true, 'phones': 0, 'payments': []}).list(baseUrl: base, apiKey: key, hours: 500);
      await gateway(200, {'success': true, 'phones': 0, 'payments': []}).list(baseUrl: base, apiKey: key, hours: 0);
      expect(requests.map((r) => r.url.queryParameters['hours']), ['72', '1']);
    });

    test('an amount that is not whole cents, or "received" that is not exactly true, is not believed', () async {
      final result = await gateway(200, {
        'success': true,
        'payments': [
          {'code': 'ODD1AMOUNT', 'message_received': 'yes', 'amount_cents': '100'},
          {'code': 'ODD2AMOUNT', 'message_received': 1, 'amount_cents': 10.5},
        ],
      }).list(baseUrl: base, apiKey: key);
      expect(result.phones, 0);
      expect(result.payments.map((p) => (p.messageReceived, p.amount)), [(false, null), (false, null)]);
    });

    test('an unreadable list, an old server and a device that is not allowed are said plainly', () async {
      await expectLater(gateway(200, {'success': true, 'payments': {}}).list(baseUrl: base, apiKey: key),
          throwsA(isA<PaystackException>().having((e) => e.message, 'message', contains('cannot read'))));
      await expectLater(gateway(404, {'success': false, 'message': 'Unknown action.'}).list(baseUrl: base, apiKey: key),
          throwsA(isA<PaystackException>().having((e) => e.message, 'message', 'The shop server cannot do M-Pesa till payments yet. Ask the owner to update it.')));
      await expectLater(gateway(401, {'status': false, 'message': 'Invalid or missing API key.'}).list(baseUrl: base, apiKey: key),
          throwsA(isA<PaystackException>().having((e) => e.message, 'message', 'This device is not allowed to do this. Ask the owner to check Connected devices.')));
    });

    test('no internet is told apart', () async {
      final offline = PaymentInboxGateway(MockClient((_) async => throw http.ClientException('down')));
      await expectLater(offline.list(baseUrl: base, apiKey: key), throwsA(isA<PaystackOfflineException>()));
    });
  });

  group('claim', () {
    test('sends the code, THIS sale\'s id, number and total, asks for the message to be there, and reads the payment', () async {
      final payment = await gateway(200, {
        'success': true,
        'confirmed': true,
        'payment': paymentJson('SJK2TILL9X', used: {'sale_id': 'sale-1', 'sale_number': 'ABC-1', 'amount_cents': 50000, 'at': '2026-11-18T10:06:00Z'}),
      }).claim(baseUrl: base, apiKey: key, code: 'SJK2TILL9X', saleId: 'sale-1', saleNumber: 'ABC-1', amount: const Money(50000));
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.queryParameters, {'action': 'payment_inbox_claim'});
      expect(request.headers['Authorization'], 'Bearer device-key');
      expect(jsonDecode(request.body), {
        'code': 'SJK2TILL9X',
        'sale_id': 'sale-1',
        'sale_number': 'ABC-1',
        'amount_cents': 50000,
        'require_message': true,
        'accept_amount': false,
      });
      expect(payment.code, 'SJK2TILL9X');
      expect(payment.usedOnSaleNumber, 'ABC-1');
    });

    test('accept_amount is sent only when asked for', () async {
      await gateway(200, {'success': true, 'payment': paymentJson('SJK2TILL9X')})
          .claim(baseUrl: base, apiKey: key, code: 'SJK2TILL9X', saleId: 's', saleNumber: 'n', amount: const Money(1), acceptAmount: true);
      expect(jsonDecode(requests.single.body)['accept_amount'], isTrue);
    });

    test('each refusal keeps the platform\'s reason and words (and the amount really paid)', () async {
      Future<TillClaimRefused> refusal(int status, Map<String, dynamic> body) async {
        try {
          await gateway(status, body).claim(baseUrl: base, apiKey: key, code: 'SJK2TILL9X', saleId: 's', saleNumber: 'n', amount: const Money(50000));
        } on TillClaimRefused catch (e) {
          return e;
        }
        fail('not refused');
      }

      final notReceived = await refusal(404, {'success': false, 'reason': 'not_received', 'message': 'No M-Pesa message with this code has arrived yet.'});
      expect((notReceived.reason, notReceived.message), ('not_received', 'No M-Pesa message with this code has arrived yet.'));
      final used = await refusal(409, {'success': false, 'reason': 'used', 'message': 'This M-Pesa code was already used on sale ABC-1.', 'sale_number': 'ABC-1'});
      expect((used.reason, used.message), ('used', 'This M-Pesa code was already used on sale ABC-1.'));
      final differs = await refusal(409, {'success': false, 'reason': 'amount_differs', 'message': 'x', 'amount_cents': 60000});
      expect((differs.reason, differs.paidAmount), ('amount_differs', const Money(60000)));
      final unknown = await refusal(409, {'success': false, 'reason': 'amount_unknown', 'message': 'x'});
      expect((unknown.reason, unknown.paidAmount), ('amount_unknown', null));
      final old = await refusal(404, {'success': false, 'status': false, 'message': 'Unknown action.'});
      expect((old.reason, old.message), ('unavailable', 'The shop server cannot check M-Pesa payments yet. Ask the owner to update it.'));
    });

    test('an answer that cannot be read (not a success, no payment, another code) is not taken for a yes', () async {
      for (final body in [
        {'success': false, 'payment': paymentJson('SJK2TILL9X')},
        {'success': true},
        {'success': true, 'payment': paymentJson('OTHER1CODE')},
      ]) {
        await expectLater(
          gateway(200, body).claim(baseUrl: base, apiKey: key, code: 'SJK2TILL9X', saleId: 's', saleNumber: 'n', amount: const Money(1)),
          throwsA(isA<PaystackException>()),
          reason: '$body',
        );
      }
      await expectLater(
        gateway(200, '<html>oops</html>').claim(baseUrl: base, apiKey: key, code: 'SJK2TILL9X', saleId: 's', saleNumber: 'n', amount: const Money(1)),
        throwsA(isA<PaystackException>()),
      );
    });

    test('no internet is told apart', () async {
      final offline = PaymentInboxGateway(MockClient((_) async => throw http.ClientException('down')));
      await expectLater(
        offline.claim(baseUrl: base, apiKey: key, code: 'SJK2TILL9X', saleId: 's', saleNumber: 'n', amount: const Money(1)),
        throwsA(isA<PaystackOfflineException>()),
      );
    });
  });

  group('phones', () {
    Map<String, dynamic> phoneJson(int id, String label) => {
          'id': id,
          'label': label,
          'added_by': 'owner',
          'added_at': '2026-11-17T11:16:00Z',
          'last_message_at': id == 3 ? '2026-11-17T11:52:00Z' : null,
          'sender_check': id == 3 ? true : 'yes',
        };

    test('the list: phones with when they were added and last heard from; rows without a real id are left out', () async {
      final result = await gateway(200, {
        'success': true,
        'max_phones': 5,
        'phones': [phoneJson(3, "Mama's iPhone"), phoneJson(4, 'Spare'), {'id': '5', 'label': 'text id'}, 'x'],
      }).phones(baseUrl: base, apiKey: key);
      expect(requests.single.method, 'GET');
      expect(requests.single.url.queryParameters, {'action': 'payment_inbox_sources'});
      expect(requests.single.headers['Authorization'], 'Bearer device-key');
      expect(result.max, 5);
      expect(result.phones.map((p) => p.label), ["Mama's iPhone", 'Spare']);
      expect(result.phones.first.lastMessageAt, DateTime.utc(2026, 11, 17, 11, 52));
      expect(result.phones.last.lastMessageAt, isNull);
      expect(result.phones.first.addedBy, 'owner');
      expect(result.phones.first.senderCheck, isTrue);
      expect(result.phones.last.senderCheck, isFalse, reason: 'only a literal true from the shop counts');
    });

    test('the most phones defaults to 5 when the shop does not say; an unreadable list is refused', () async {
      expect((await gateway(200, {'success': true, 'phones': []}).phones(baseUrl: base, apiKey: key)).max, 5);
      await expectLater(gateway(200, {'success': true}).phones(baseUrl: base, apiKey: key), throwsA(isA<PaystackException>()));
    });

    test('setting a phone up sends the name, who asks and their password, and gives back the key, the phone and the address', () async {
      final made = await gateway(201, {'success': true, 'key': 'npk_0123456789abcdef0123456789abcdef0123456789abcdef', 'phone': phoneJson(9, 'Shop iPhone')})
          .addPhone(baseUrl: base, apiKey: key, label: 'Shop iPhone', userId: 'admin-1', password: 'pw');
      expect(requests.single.method, 'POST');
      expect(requests.single.url.queryParameters, {'action': 'payment_inbox_add_source'});
      expect(jsonDecode(requests.single.body), {'label': 'Shop iPhone', 'user_id': 'admin-1', 'password': 'pw'});
      expect(made.key, 'npk_0123456789abcdef0123456789abcdef0123456789abcdef');
      expect(made.phone.id, 9);
      expect(made.address, '$base?action=payment_inbox_ingest');
      expect(made.setupPageLink, 'https://nexapos.cc/lite/phone.html#k=npk_0123456789abcdef0123456789abcdef0123456789abcdef');
    });

    test('a key that is not a key, or no phone with it, is never passed off as one', () async {
      for (final body in [
        {'success': true, 'key': 'npk_short', 'phone': phoneJson(9, 'P')},
        {'success': true, 'key': 'NPK_0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF', 'phone': phoneJson(9, 'P')},
        {'success': true, 'phone': phoneJson(9, 'P')},
        {'success': true, 'key': 'npk_0123456789abcdef0123456789abcdef0123456789abcdef'},
        {'success': true, 'key': 'npk_0123456789abcdef0123456789abcdef0123456789abcdef', 'phone': {'id': 0, 'label': 'P'}},
      ]) {
        await expectLater(
          gateway(201, body).addPhone(baseUrl: base, apiKey: key, label: 'P', userId: 'a', password: 'p'),
          throwsA(isA<PaystackException>().having((e) => e.message, 'message', contains('cannot read'))),
          reason: '$body',
        );
      }
    });

    test('the shop\'s refusals keep its own words (wrong password, locked, not an administrator, too many)', () async {
      for (final refusal in [
        (403, 'wrong_password', 'That password is not right.'),
        (429, 'locked', 'Too many wrong passwords. Wait 10 minutes and try again.'),
        (403, 'not_admin', 'Only an administrator of the shop can do this.'),
        (409, 'too_many', 'This shop already has 5 phones set up. Remove one first.'),
      ]) {
        final body = {'success': false, 'reason': refusal.$2, 'message': refusal.$3};
        await expectLater(
          gateway(refusal.$1, body).addPhone(baseUrl: base, apiKey: key, label: 'P', userId: 'a', password: 'p'),
          throwsA(isA<PaystackException>().having((e) => e.message, 'message', refusal.$3)),
        );
        await expectLater(
          gateway(refusal.$1, body).removePhone(baseUrl: base, apiKey: key, phoneId: 3, userId: 'a', password: 'p'),
          throwsA(isA<PaystackException>().having((e) => e.message, 'message', refusal.$3)),
        );
      }
    });

    test('removing a phone sends which phone, who asks and their password, and reads the phones left', () async {
      final left = await gateway(200, {'success': true, 'phones': [phoneJson(4, 'Spare')]})
          .removePhone(baseUrl: base, apiKey: key, phoneId: 3, userId: 'admin-1', password: 'pw');
      expect(requests.single.url.queryParameters, {'action': 'payment_inbox_remove_source'});
      expect(jsonDecode(requests.single.body), {'phone_id': 3, 'user_id': 'admin-1', 'password': 'pw'});
      expect(left.map((p) => p.id), [4]);
    });
  });

  group('archive', () {
    test('sends the code and whether to archive it, and reads when it was archived', () async {
      final archived = await gateway(200, {'success': true, 'payment': {...paymentJson('ARCH1VED11'), 'archived_at': '2026-11-18T09:00:00Z'}})
          .archive(baseUrl: base, apiKey: key, code: 'ARCH1VED11');
      expect(requests.single.method, 'POST');
      expect(requests.single.url.queryParameters, {'action': 'payment_inbox_archive'});
      expect(requests.single.headers['Authorization'], 'Bearer device-key');
      expect(jsonDecode(requests.single.body), {'code': 'ARCH1VED11', 'archived': true});
      expect(archived.isArchived, isTrue);
      expect(archived.archivedAt, DateTime.utc(2026, 11, 18, 9));
      final again = await gateway(200, {'success': true, 'payment': paymentJson('ARCH1VED11')})
          .archive(baseUrl: base, apiKey: key, code: 'ARCH1VED11', archived: false);
      expect(jsonDecode(requests.last.body), {'code': 'ARCH1VED11', 'archived': false});
      expect(again.isArchived, isFalse);
    });

    test('a list row says when a payment was archived', () async {
      final result = await gateway(200, {'success': true, 'phones': 1, 'payments': [{...paymentJson('ARCH1VED11'), 'archived_at': '2026-11-18T09:00:00Z'}, paymentJson('N0TARCH1VD')]})
          .list(baseUrl: base, apiKey: key);
      expect(result.payments.map((p) => p.isArchived), [true, false]);
    });

    test('an unknown code, an old server, an answer for another code are said plainly', () async {
      await expectLater(
        gateway(404, {'success': false, 'reason': 'not_found', 'message': 'x'}).archive(baseUrl: base, apiKey: key, code: 'ARCH1VED11'),
        throwsA(isA<PaystackException>().having((e) => e.message, 'message', 'The shop has no M-Pesa payment with this code.')),
      );
      await expectLater(
        gateway(404, {'success': false, 'message': 'Unknown action.'}).archive(baseUrl: base, apiKey: key, code: 'ARCH1VED11'),
        throwsA(isA<PaystackException>().having((e) => e.message, 'message', contains('cannot do M-Pesa till payments yet'))),
      );
      await expectLater(
        gateway(200, {'success': true, 'payment': paymentJson('OTHER1CODE')}).archive(baseUrl: base, apiKey: key, code: 'ARCH1VED11'),
        throwsA(isA<PaystackException>()),
      );
    });
  });

  group('release', () {
    test('gives the code back for that sale', () async {
      await gateway(200, {'success': true, 'released': true}).release(baseUrl: base, apiKey: key, code: 'SJK2TILL9X', saleId: 'sale-1');
      expect(requests.single.url.queryParameters, {'action': 'payment_inbox_release'});
      expect(jsonDecode(requests.single.body), {'code': 'SJK2TILL9X', 'sale_id': 'sale-1'});
    });

    test('never throws: a failure only leaves that code blocked', () async {
      await gateway(500, {'success': false, 'message': 'Server error.'}).release(baseUrl: base, apiKey: key, code: 'C0DE12345', saleId: 's');
      await PaymentInboxGateway(MockClient((_) async => throw http.ClientException('down')))
          .release(baseUrl: base, apiKey: key, code: 'C0DE12345', saleId: 's');
    });
  });
}
