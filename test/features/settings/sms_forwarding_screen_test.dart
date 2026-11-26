import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/data/payments/sms_forwarding.dart';
import 'package:nexapos_mobile/features/settings/sms_forwarding_screen.dart';

/// "M-Pesa messages from this phone" (Android): the owner asked, 2026-11-25, for Android phones to pass the till's
/// payment messages on too, like the iPhone Shortcut. The screen checks the key with the shop, asks Android for the
/// SMS permission, and only then switches passing on on.

const _key = 'npk_e58e0eec8584c2e192fb25f8515a2634430be62c0295a5c8';
const _address = 'https://sync.test/index.php?action=payment_inbox_ingest';

/// The native side, in memory.
class _FakeForwarding implements SmsForwarding {
  bool enabled = false;
  bool permission = false;
  bool grantOnAsk = true;
  String? key;
  String? address;
  String? lastResult;
  int waiting = 0;
  final calls = <String>[];

  @override
  Future<SmsForwardingStatus> status() async {
    calls.add('status');
    return SmsForwardingStatus(
      enabled: enabled,
      permission: permission,
      keyEnd: key?.substring(key!.length - 4),
      lastAt: lastResult == null ? null : DateTime(2026, 11, 25, 14, 15),
      lastSender: lastResult == null ? null : 'MPESA',
      lastResult: lastResult,
      passedOn: lastResult == 'recorded' ? 1 : 0,
      waiting: waiting,
      sdk: 34,
    );
  }

  @override
  Future<bool> enable({required String key, required String address}) async {
    calls.add('enable');
    this.key = key;
    this.address = address;
    enabled = true;
    return true;
  }

  @override
  Future<void> disable() async {
    calls.add('disable');
    enabled = false;
  }

  @override
  Future<bool> requestPermission() async {
    calls.add('requestPermission');
    if (grantOnAsk) permission = true;
    return permission;
  }

  @override
  Future<bool> openAppSettings() async {
    calls.add('openAppSettings');
    return true;
  }
}

void main() {
  late _FakeForwarding forwarding;
  late List<http.Request> checks;

  Future<void> pump(
    WidgetTester tester, {
    int keyStatus = 200,
    bool offline = false,
    String? initialKey,
    bool supported = true,
  }) async {
    checks = [];
    final client = MockClient((request) async {
      checks.add(request);
      if (offline) throw http.ClientException('offline');
      return http.Response('{"success":true,"reason":"not_a_payment"}', keyStatus);
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [smsForwardingProvider.overrideWithValue(forwarding)],
      child: MaterialApp(
        home: SmsForwardingScreen(address: _address, httpClient: client, initialKey: initialKey, supported: supported),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapTurnOn(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('sms-turn-on')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sms-turn-on')));
    await tester.pumpAndSettle();
  }

  setUp(() => forwarding = _FakeForwarding());

  testWidgets('pasting the set-up link and turning on: key checked, permission asked, then switched on', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('sms-status-off')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('sms-key-field')), 'https://nexapos.cc/lite/phone.html#k=$_key');
    await tapTurnOn(tester);

    expect(checks, hasLength(1), reason: 'the key is checked with the shop first');
    expect(checks.single.url.toString(), _address);
    expect(forwarding.calls.where((c) => c != 'status'), ['requestPermission', 'enable'], reason: 'permission before switching on');
    expect(forwarding.key, _key, reason: 'the key, not the whole link');
    expect(forwarding.address, _address);
    expect(find.byKey(const Key('sms-status-on')), findsOneWidget);
    expect(find.text('On: payment messages are passed on'), findsOneWidget);
    expect(find.byKey(const Key('sms-problem')), findsNothing);
  });

  testWidgets('a key the shop does not know: nothing is asked or switched on, and the person is told', (tester) async {
    await pump(tester, keyStatus: 401);
    await tester.enterText(find.byKey(const Key('sms-key-field')), _key);
    await tapTurnOn(tester);
    expect(forwarding.calls, isNot(contains('requestPermission')));
    expect(forwarding.calls, isNot(contains('enable')));
    expect(find.textContaining('The shop does not know this key'), findsOneWidget);
  });

  testWidgets('Android says no: nothing is switched on, and the restricted-settings steps are shown', (tester) async {
    forwarding.grantOnAsk = false;
    await pump(tester);
    await tester.enterText(find.byKey(const Key('sms-key-field')), _key);
    await tapTurnOn(tester);
    expect(forwarding.calls, isNot(contains('enable')));
    expect(find.byKey(const Key('sms-permission-help')), findsOneWidget);
    expect(find.textContaining('Allow restricted settings'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('sms-open-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sms-open-settings')));
    await tester.pumpAndSettle();
    expect(forwarding.calls, contains('openAppSettings'));
  });

  testWidgets('no internet to check the key: it is switched on anyway, and the messages wait', (tester) async {
    await pump(tester, offline: true);
    await tester.enterText(find.byKey(const Key('sms-key-field')), _key);
    await tapTurnOn(tester);
    expect(forwarding.calls, contains('enable'));
    expect(find.byKey(const Key('sms-note')), findsOneWidget);
  });

  testWidgets('something that is not a key: nothing is sent anywhere', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('sms-key-field')), 'my password');
    await tapTurnOn(tester);
    expect(checks, isEmpty);
    expect(forwarding.calls.where((c) => c != 'status'), isEmpty);
    expect(find.byKey(const Key('sms-problem')), findsOneWidget);
  });

  testWidgets('a key handed over by "Use this phone" is filled in', (tester) async {
    await pump(tester, initialKey: _key);
    expect(find.text(_key), findsOneWidget);
  });

  testWidgets('on: the last message, what the shop said, what is waiting; turning off asks first', (tester) async {
    forwarding
      ..enabled = true
      ..permission = true
      ..key = _key
      ..lastResult = 'recorded'
      ..waiting = 2;
    await pump(tester);
    expect(find.text('Key ending ...a5c8'), findsOneWidget);
    expect(find.text('25 Nov, 14:15 from MPESA'), findsOneWidget);
    expect(find.text('Recorded as a payment received.'), findsOneWidget);
    expect(find.text('2 messages are waiting for internet.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sms-turn-off')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep it on'));
    await tester.pumpAndSettle();
    expect(forwarding.calls, isNot(contains('disable')));

    await tester.tap(find.byKey(const Key('sms-turn-off')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sms-turn-off-confirm')));
    await tester.pumpAndSettle();
    expect(forwarding.calls, contains('disable'));
    expect(find.byKey(const Key('sms-status-off')), findsOneWidget);
  });

  testWidgets('switched on but the permission was taken away: it says so and offers to allow it again', (tester) async {
    forwarding
      ..enabled = true
      ..permission = false
      ..key = _key;
    await pump(tester);
    expect(find.text('On, but Android does not let it receive messages'), findsOneWidget);
    expect(find.byKey(const Key('sms-permission-help')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sms-allow-again')));
    await tester.pumpAndSettle();
    expect(forwarding.calls, contains('requestPermission'));
    expect(find.text('On: payment messages are passed on'), findsOneWidget);
  });

  testWidgets('not an Android phone: it says how an iPhone does it, and touches nothing', (tester) async {
    await pump(tester, supported: false);
    expect(find.byKey(const Key('sms-not-android')), findsOneWidget);
    expect(find.byKey(const Key('sms-turn-on')), findsNothing);
    expect(forwarding.calls, isEmpty);
  });

  testWidgets('it fits a 360-pixel-wide phone', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    forwarding.grantOnAsk = false;
    await pump(tester);
    await tester.enterText(find.byKey(const Key('sms-key-field')), _key);
    await tapTurnOn(tester);
    expect(tester.takeException(), isNull);
  });
}
