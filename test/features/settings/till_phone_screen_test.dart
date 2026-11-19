import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/payments/payment_inbox_gateway.dart';
import 'package:nexapos_mobile/data/payments/platform_http_client.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/paystack_credentials_service.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/features/settings/till_phone_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Settings > M-Pesa Till Phone in the apps: the same page as the Lite till's - set a phone up with your own password
/// (checked by the shop), get its key once with a code to scan, remove a phone, see the payments that arrived, and suggest
/// an archived one again.
class _Session extends SessionNotifier {
  _Session(this.role);
  final UserRole role;
  @override
  User? build() => User(id: 'admin-1', role: role, name: 'Owner', username: 'owner', passwordHash: 'x', status: 'active');
}

class _Credentials implements PaystackCredentialsService {
  _Credentials(this.connected);
  final bool connected;
  @override
  Future<PaystackCredentials> load() async => PaystackCredentials(
        baseUrl: connected ? 'https://sync.test/index.php' : '',
        apiKey: connected ? 'device-key' : '',
        currency: 'KES',
        defaultEmail: 'x@y.z',
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _key = 'npk_0123456789abcdef0123456789abcdef0123456789abcdef';

class _Inbox extends PaymentInboxGateway {
  List<TillPhone> phoneList = [
    TillPhone(id: 3, label: "Mama's iPhone", addedBy: 'owner', addedAt: DateTime.utc(2026, 11, 17, 11, 16), lastMessageAt: DateTime.utc(2026, 11, 17, 11, 52)),
  ];
  List<TillPayment> payments = [
    TillPayment(code: 'NEW1PAYM3N', messageReceived: true, amount: const Money(61000), payerName: 'JACINTA OMWENGA', paidAtText: '17/11/26 7:20 PM', phoneLabel: "Mama's iPhone"),
    TillPayment(code: 'ARCH1VED11', messageReceived: true, amount: const Money(10000), payerName: 'JEFSON OTIENO JOMBO', archivedAt: DateTime.utc(2026, 11, 18)),
    const TillPayment(code: 'USED1PAYM3', messageReceived: true, amount: Money(50000), payerName: 'HENRY OMWEGA', usedOnSaleNumber: 'ABC-1', usedAmount: Money(50000)),
    const TillPayment(code: 'TYP3DCODE1', messageReceived: false, usedOnSaleNumber: 'ABC-2', usedAmount: Money(300)),
  ];
  final added = <({String label, String userId, String password})>[];
  final removed = <({int phoneId, String userId, String password})>[];
  final archivedCalls = <({String code, bool archived})>[];
  Object? addFails;
  Object? removeFails;

  @override
  Future<({List<TillPhone> phones, int max})> phones({required String baseUrl, required String apiKey}) async => (phones: phoneList, max: 5);

  @override
  Future<({List<TillPayment> payments, int phones})> list({required String baseUrl, required String apiKey, int hours = 24}) async =>
      (payments: payments, phones: phoneList.length);

  @override
  Future<TillPhoneKey> addPhone({required String baseUrl, required String apiKey, required String label, required String userId, required String password}) async {
    added.add((label: label, userId: userId, password: password));
    if (addFails != null) throw addFails!;
    final phone = TillPhone(id: 9, label: label, addedBy: 'owner', addedAt: DateTime.utc(2026, 11, 19));
    phoneList = [...phoneList, phone];
    return TillPhoneKey(key: _key, phone: phone, address: '$baseUrl?action=payment_inbox_ingest');
  }

  @override
  Future<List<TillPhone>> removePhone({required String baseUrl, required String apiKey, required int phoneId, required String userId, required String password}) async {
    removed.add((phoneId: phoneId, userId: userId, password: password));
    if (removeFails != null) throw removeFails!;
    phoneList = [for (final p in phoneList) if (p.id != phoneId) p];
    return phoneList;
  }

  @override
  Future<TillPayment> archive({required String baseUrl, required String apiKey, required String code, bool archived = true}) async {
    archivedCalls.add((code: code, archived: archived));
    payments = [
      for (final p in payments)
        if (p.code == code) TillPayment(code: p.code, messageReceived: true, amount: p.amount, payerName: p.payerName) else p,
    ];
    return payments.firstWhere((p) => p.code == code);
  }
}

void main() {
  late _Inbox inbox;
  String? copied;

  Future<void> pump(WidgetTester tester, {UserRole role = UserRole.admin, bool connected = true}) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    inbox = _Inbox();
    copied = null;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => _Session(role)),
        paystackCredentialsServiceProvider.overrideWithValue(_Credentials(connected)),
        paymentInboxGatewayProvider.overrideWithValue(inbox),
      ],
      child: const MaterialApp(home: TillPhoneScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('only an administrator gets the page', (tester) async {
    await pump(tester, role: UserRole.cashier);
    expect(find.text('Only an administrator of the shop can set up the M-Pesa till phone.'), findsOneWidget);
    expect(find.byKey(const Key('till-phone-set-up')), findsNothing);
  });

  testWidgets('the phones are listed with when each last passed a message on', (tester) async {
    await pump(tester);
    expect(find.text("Mama's iPhone"), findsWidgets);
    expect(find.textContaining('Added by owner'), findsOneWidget);
    expect(find.textContaining('Last message:'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Remove'), findsOneWidget);
  });

  testWidgets('the payments received say what became of each; an archived one can be suggested again', (tester) async {
    await pump(tester);
    expect(find.text('JACINTA OMWENGA'), findsOneWidget);
    expect(find.textContaining('Not used on a sale yet'), findsOneWidget);
    expect(find.textContaining('Used on sale ABC-1'), findsOneWidget);
    expect(find.textContaining('Archived: not suggested at checkout'), findsOneWidget);
    expect(find.text('Code typed at a till'), findsOneWidget);
    expect(find.byKey(const Key('till-suggest-ARCH1VED11')), findsOneWidget);
    expect(find.byKey(const Key('till-suggest-NEW1PAYM3N')), findsNothing, reason: 'only archived ones');
    await tester.tap(find.byKey(const Key('till-suggest-ARCH1VED11')));
    await tester.pumpAndSettle();
    expect(inbox.archivedCalls.single, (code: 'ARCH1VED11', archived: false));
    expect(find.text('JEFSON OTIENO JOMBO is suggested at checkout again.'), findsOneWidget);
    expect(find.byKey(const Key('till-suggest-ARCH1VED11')), findsNothing);
  });

  testWidgets('setting a phone up sends the name, who asks and their password, and shows the key once, with a code to scan', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('till-phone-set-up')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('till-phone-label')), 'Shop iPhone');
    await tester.enterText(find.byKey(const Key('till-phone-password')), 'my-own-password');
    await tester.tap(find.byKey(const Key('till-phone-create')));
    await tester.pumpAndSettle();
    expect(inbox.added.single, (label: 'Shop iPhone', userId: 'admin-1', password: 'my-own-password'));
    expect(find.byKey(const Key('till-phone-key-card')), findsOneWidget);
    expect(find.text('Set up "Shop iPhone"'), findsOneWidget);
    expect(find.text(_key), findsOneWidget);
    expect(find.text('https://sync.test/index.php?action=payment_inbox_ingest'), findsOneWidget);
    final qr = tester.widget<QrImageView>(find.byKey(const Key('till-phone-qr')));
    expect(qr, isNotNull);
    await tester.tap(find.byKey(const Key('till-phone-copy-key')));
    await tester.pumpAndSettle();
    expect(copied, _key);
    await tester.tap(find.byKey(const Key('till-phone-copy-address')));
    await tester.pumpAndSettle();
    expect(copied, 'https://sync.test/index.php?action=payment_inbox_ingest');
    // hiding asks first, then the key is gone for good
    await tester.tap(find.byKey(const Key('till-phone-hide-key')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Keep it on screen'));
    await tester.pumpAndSettle();
    expect(find.text(_key), findsOneWidget);
    await tester.tap(find.byKey(const Key('till-phone-hide-key')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hide the key'));
    await tester.pumpAndSettle();
    expect(find.text(_key), findsNothing);
    expect(find.byKey(const Key('till-phone-key-card')), findsNothing);
  });

  testWidgets('the scan code opens the phone set-up page with the key after the #', (tester) async {
    const key = TillPhoneKey(key: _key, phone: TillPhone(id: 1, label: 'P'), address: 'x');
    expect(key.setupPageLink, 'https://nexapos.cc/lite/phone.html#k=$_key');
  });

  testWidgets('without a password nothing is sent; a refusal from the shop is shown in its own words', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('till-phone-set-up')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('till-phone-create')));
    await tester.pumpAndSettle();
    expect(inbox.added, isEmpty, reason: 'an empty password is not sent');
    inbox.addFails = const PaystackException('That password is not right.', statusCode: 403);
    await tester.enterText(find.byKey(const Key('till-phone-password')), 'wrong');
    await tester.tap(find.byKey(const Key('till-phone-create')));
    await tester.pumpAndSettle();
    expect(find.text('That password is not right.'), findsOneWidget);
    expect(find.byKey(const Key('till-phone-key-card')), findsNothing);
  });

  testWidgets('removing a phone asks for your password, and the phone goes', (tester) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Remove "Mama\'s iPhone"?'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('till-phone-remove-password')), 'my-own-password');
    await tester.tap(find.byKey(const Key('till-phone-remove-confirm')));
    await tester.pumpAndSettle();
    expect(inbox.removed.single, (phoneId: 3, userId: 'admin-1', password: 'my-own-password'));
    expect(find.text('Phone removed. Its key no longer works.'), findsOneWidget);
    expect(find.text('No phone is set up yet.'), findsOneWidget);
  });

  testWidgets('a refused removal keeps the phone and says why', (tester) async {
    await pump(tester);
    inbox.removeFails = const PaystackException('Too many wrong passwords. Wait 10 minutes and try again.', statusCode: 429);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Remove'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('till-phone-remove-password')), 'x');
    await tester.tap(find.byKey(const Key('till-phone-remove-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Too many wrong passwords. Wait 10 minutes and try again.'), findsOneWidget);
    expect(find.byKey(const Key('till-phone-3')), findsOneWidget);
  });

  testWidgets('with five phones no more can be set up', (tester) async {
    await pump(tester);
    inbox.phoneList = [for (var i = 1; i <= 5; i++) TillPhone(id: i, label: 'Phone $i')];
    await tester.tap(find.byKey(const Key('till-phone-refresh')));
    await tester.pumpAndSettle();
    expect(find.textContaining('which is the most'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('till-phone-set-up'))).onPressed, isNull);
  });

  testWidgets('it fits a 360-pixel-wide phone, key card and all', (tester) async {
    await pump(tester);
    tester.view.physicalSize = const Size(360, 3000);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('till-phone-set-up')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('till-phone-password')), 'pw');
    await tester.tap(find.byKey(const Key('till-phone-create')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('till-phone-key-card')), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'nothing overflows');
  });

  testWidgets('a device not connected to the shop says so', (tester) async {
    await pump(tester, connected: false);
    expect(find.byKey(const Key('till-phone-problem')), findsOneWidget);
    expect(find.textContaining('not connected to the shop sync service'), findsOneWidget);
  });
}
