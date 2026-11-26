import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/data/payments/sms_forwarding.dart';

/// An Android phone passing the till's payment messages on (the native side is android/.../SmsForwarding.kt).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = 'npk_e58e0eec8584c2e192fb25f8515a2634430be62c0295a5c8';
  const channel = MethodChannel('com.nexapos/sms_forwarding');

  test('the key is taken from the key itself or from the set-up link the PC shows', () {
    expect(tillPhoneKeyFrom(key), key);
    expect(tillPhoneKeyFrom('  $key\n'), key);
    expect(tillPhoneKeyFrom('https://nexapos.cc/lite/phone.html#k=$key'), key);
    expect(tillPhoneKeyFrom('npk_'), isNull);
    expect(tillPhoneKeyFrom('hello'), isNull);
    expect(tillPhoneKeyFrom(''), isNull);
  });

  test('messages go where the iPhone Shortcut sends them', () {
    expect(paymentIngestAddress(), 'https://sync.nexapos.cc/index.php?action=payment_inbox_ingest');
    expect(paymentIngestAddress('https://sync.test/index.php'), 'https://sync.test/index.php?action=payment_inbox_ingest');
  });

  test('only an Android device passes messages on', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(smsForwardingSupported, isTrue);
    for (final other in [TargetPlatform.iOS, TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux]) {
      debugDefaultTargetPlatformOverride = other;
      expect(smsForwardingSupported, isFalse, reason: '$other');
    }
    debugDefaultTargetPlatformOverride = null;
  });

  group('the native side, through its channel', () {
    final calls = <MethodCall>[];
    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'status' => <String, Object?>{
              'enabled': true,
              'permission': true,
              'keyEnd': '5a5c8',
              'lastAt': DateTime(2026, 11, 25, 14, 15).millisecondsSinceEpoch,
              'lastSender': 'MPESA',
              'lastResult': 'recorded',
              'passedOn': 3,
              'waiting': 1,
              'sdk': 34,
            },
          'enable' || 'requestPermission' || 'openAppSettings' => true,
          _ => null,
        };
      });
    });
    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    test('the status is read in full', () async {
      final status = await const SmsForwarding().status();
      expect(status.enabled, isTrue);
      expect(status.permission, isTrue);
      expect(status.working, isTrue);
      expect(status.keyEnd, '5a5c8');
      expect(status.lastAt, DateTime(2026, 11, 25, 14, 15));
      expect(status.lastSender, 'MPESA');
      expect(status.lastResult, 'recorded');
      expect(status.passedOn, 3);
      expect(status.waiting, 1);
      expect(status.sdk, 34);
    });

    test('switching on sends the key and the address; the other calls go through by name', () async {
      const forwarding = SmsForwarding();
      expect(await forwarding.enable(key: key, address: 'https://sync.test/index.php?action=payment_inbox_ingest'), isTrue);
      await forwarding.disable();
      expect(await forwarding.requestPermission(), isTrue);
      expect(await forwarding.openAppSettings(), isTrue);
      expect(calls.map((c) => c.method), ['enable', 'disable', 'requestPermission', 'openAppSettings']);
      expect(calls.first.arguments, {'key': key, 'address': 'https://sync.test/index.php?action=payment_inbox_ingest'});
    });

    test('an empty answer is "off, not allowed"', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async => null);
      final status = await const SmsForwarding().status();
      expect(status.enabled, isFalse);
      expect(status.permission, isFalse);
      expect(status.working, isFalse);
      expect(await const SmsForwarding().requestPermission(), isFalse);
    });
  });

  group('checking a key with the shop', () {
    const address = 'https://sync.test/index.php?action=payment_inbox_ingest';

    test('a known key: the shop answers "not a payment" for the check message', () async {
      http.Request? sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response('{"success":true,"recorded":false,"reason":"not_a_payment"}', 200);
      });
      expect(await checkTillPhoneKey(client, address: address, key: key), TillKeyCheck.works);
      expect(sent!.method, 'POST');
      expect(sent!.url.toString(), address);
      final body = jsonDecode(sent!.body) as Map;
      expect(body['key'], key);
      expect(body['sender'], 'NexaPOS', reason: 'a named sender - never a phone number');
      expect(body['text'], isNot(contains('Ksh')), reason: 'the check message is never taken for a payment');
    });

    test('an unknown key is refused; no internet or a server error is "unknown"', () async {
      expect(await checkTillPhoneKey(MockClient((_) async => http.Response('', 401)), address: address, key: key), TillKeyCheck.refused);
      expect(await checkTillPhoneKey(MockClient((_) async => http.Response('', 403)), address: address, key: key), TillKeyCheck.refused);
      expect(await checkTillPhoneKey(MockClient((_) async => http.Response('', 500)), address: address, key: key), TillKeyCheck.unknown);
      expect(await checkTillPhoneKey(MockClient((_) async => throw http.ClientException('offline')), address: address, key: key),
          TillKeyCheck.unknown);
    });
  });

  test('every result is put in words', () {
    for (final result in ['recorded', 'already_have_it', 'not_a_payment', 'from_a_person', 'no_sender', 'waiting', 'key_refused', 'gave_up']) {
      expect(smsForwardingResultWords(result), isNot(startsWith('The shop answered')), reason: result);
    }
    expect(smsForwardingResultWords(null), 'Nothing passed on yet.');
    expect(smsForwardingResultWords('refused_400'), 'The shop answered: refused_400.');
  });
}
