import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/secure_storage_provider.dart';
import 'package:nexapos_mobile/data/licensing/license_gateway.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/domain/services/license_purchase_service.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import 'package:nexapos_mobile/features/licensing/activation_screen.dart';

import '../../support/fake_license_server.dart';
import '../../support/fake_secure_storage.dart';

class _FixedDevice extends SyncMetadataService {
  _FixedDevice(super.db);
  @override
  Future<String> deviceId() async => 'test-device';
}

class _LongDevice extends SyncMetadataService {
  _LongDevice(super.db);
  @override
  Future<String> deviceId() async => '3f2b8c1e-9d4a-4e6b-a7c3-1f5e8d2b9a04';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLicenseServer server;
  late AppDatabase db;
  late ProviderContainer container;
  late List<Uri> opened;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    installFakeSecureStorage();
    server = FakeLicenseServer();
    opened = [];
  });

  /// Opens the activation screen against the scripted server. [beforeOpen] runs
  /// once the app's storage exists but before the screen does.
  Future<void> openScreen(
    WidgetTester tester, {
    Future<void> Function()? beforeOpen,
    Size size = const Size(1000, 3000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
      syncMetadataProvider.overrideWithValue(_FixedDevice(db)),
      licenseGatewayProvider.overrideWith((ref) => LicenseGateway(server.client)),
      urlOpenerProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return true;
      }),
    ]);
    if (beforeOpen != null) await beforeOpen();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ActivationScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await db.close();
  }

  /// Time passing while a dialog with a moving progress bar is open (which
  /// pumpAndSettle would wait on forever).
  Future<void> pass(WidgetTester tester, Duration total) async {
    for (var elapsed = Duration.zero; elapsed < total; elapsed += const Duration(milliseconds: 500)) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  /// Taps a plan, gives an email, and lets the checkout start.
  Future<void> buy(WidgetTester tester, String planId, {String email = 'buyer@example.com'}) async {
    await tester.tap(find.byKey(Key('pay-$planId')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('purchase-email')), email);
    await tester.tap(find.byKey(const Key('purchase-continue')));
    await pass(tester, const Duration(seconds: 1));
  }

  group('the plans', () {
    testWidgets('are listed with the server\'s prices, per-month cost, and the best value marked - and no trial', (tester) async {
      await openScreen(tester);

      expect(find.text('Choose a plan'), findsOneWidget);
      expect(find.text('3 months'), findsOneWidget);
      expect(find.text('6 months'), findsOneWidget);
      expect(find.text('1 year'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'KSh 1,500'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'KSh 3,000'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'KSh 4,800'), findsOneWidget);
      expect(find.text('KSh 500 a month'), findsNWidgets(2));
      expect(find.text('KSh 400 a month'), findsOneWidget);
      expect(find.text('Best value'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const Key('plan-m12')), matching: find.text('Best value')),
        findsOneWidget,
        reason: 'the cheapest per month is the year',
      );
      expect(find.textContaining(RegExp('trial', caseSensitive: false)), findsNothing);
      // The license key is still right there.
      expect(find.text('or enter a license key'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Activate'), findsOneWidget);

      await close(tester);
    });

    testWidgets('a changed price on the server shows without any app change', (tester) async {
      server.plans = [
        {'id': 'm3', 'label': '3 months', 'months': 3, 'amount_kes': 1800},
      ];
      await openScreen(tester);

      expect(find.widgetWithText(FilledButton, 'KSh 1,800'), findsOneWidget);
      expect(find.text('Best value'), findsNothing, reason: 'nothing to compare with');

      await close(tester);
    });

    testWidgets('before the payment account is set up they are listed but cannot be paid for', (tester) async {
      server.purchasingEnabled = false;
      await openScreen(tester);

      expect(find.byKey(const Key('payments-unavailable')), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('pay-m6'))).onPressed, isNull);

      await tester.tap(find.byKey(const Key('plan-m6')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(server.startCalls, 0);
      expect(find.widgetWithText(FilledButton, 'Activate'), findsOneWidget, reason: 'the key still works');

      await close(tester);
    });

    testWidgets('with no internet they say so, can be retried, and the key field is unaffected', (tester) async {
      server.offline = true;
      await openScreen(tester);

      expect(find.byKey(const Key('plans-error')), findsOneWidget);
      expect(find.textContaining('check your internet connection'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Activate'), findsOneWidget);

      server.offline = false;
      await tester.tap(find.byKey(const Key('retry-plans')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('plans-error')), findsNothing);
      expect(find.widgetWithText(FilledButton, 'KSh 3,000'), findsOneWidget);

      await close(tester);
    });
  });

  group('buying', () {
    testWidgets('asks for an email first, checking it', (tester) async {
      await openScreen(tester);

      await tester.tap(find.byKey(const Key('pay-m6')));
      await tester.pumpAndSettle();
      expect(find.text('6 months - KSh 3,000'), findsOneWidget);

      await tester.tap(find.byKey(const Key('purchase-continue')));
      await tester.pump();
      expect(find.text('Enter your email address'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('purchase-email')), 'not-an-email');
      await tester.tap(find.byKey(const Key('purchase-continue')));
      await tester.pump();
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(server.startCalls, 0, reason: 'nothing is started until the email is fine');

      await close(tester);
    });

    testWidgets('cancelling the email prompt starts nothing', (tester) async {
      await openScreen(tester);

      await tester.tap(find.byKey(const Key('pay-m6')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(server.startCalls, 0);
      expect(find.byKey(const Key('payment-dialog')), findsNothing);

      await close(tester);
    });

    testWidgets('paying: opens the payment page, waits, and activates by itself when the payment is confirmed', (tester) async {
      server.statusScript = [
        {'success': true, 'status': 'pending'},
        {'success': true, 'status': 'pending'},
        {'success': true, 'status': 'issued', 'code': FakeLicenseServer.licenseCode},
      ];
      await openScreen(tester);

      await buy(tester, 'm6');

      // The server was asked for the plan chosen, for this device, with the email.
      expect(server.lastStart, {'device_id': 'test-device', 'plan_id': 'm6', 'email': 'buyer@example.com'});
      // Paystack's page opened by itself.
      expect(opened, [Uri.parse('https://checkout.paystack.com/test0001')]);
      // And the screen is waiting.
      expect(find.byKey(const Key('payment-dialog')), findsOneWidget);
      expect(find.text('Waiting for your payment'), findsOneWidget);
      expect(find.text('KSh 3,000 - 6 months'), findsOneWidget);
      expect(server.activateCalls, 0);

      // Not paid yet at the next look either...
      await pass(tester, const Duration(seconds: 3));
      expect(find.byKey(const Key('payment-dialog')), findsOneWidget);
      expect(server.activateCalls, 0);

      // ...then the payment is confirmed and this device activates.
      await pass(tester, const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(server.activatedCodes, [FakeLicenseServer.licenseCode]);
      expect(find.byKey(const Key('payment-dialog')), findsNothing);
      expect(await container.read(licenseServiceProvider).hasValidCachedLicense(), isTrue);
      expect(await container.read(licensePurchaseServiceProvider).pending(), isNull);

      await close(tester);
    });

    testWidgets('the payment page can be opened again, and checked on demand', (tester) async {
      await openScreen(tester);
      await buy(tester, 'm3');
      expect(opened, hasLength(1));
      final checksBefore = server.statusCalls;

      await tester.tap(find.byKey(const Key('open-payment-page')));
      await tester.pump();
      expect(opened, hasLength(2));
      expect(opened.last, opened.first);

      await tester.tap(find.byKey(const Key('check-now')));
      await pass(tester, const Duration(milliseconds: 500));
      expect(server.statusCalls, greaterThan(checksBefore));

      await close(tester);
    });

    testWidgets('a start the server refuses is explained in its words, and nothing is left half-started', (tester) async {
      server.startAnswer = http.Response(
        jsonEncode({'success': false, 'message': 'Too many payment attempts from this device. Try again in a little while.'}),
        429,
      );
      await openScreen(tester);

      await buy(tester, 'm6');

      expect(find.byKey(const Key('purchase-error')), findsOneWidget);
      expect(find.textContaining('Too many payment attempts'), findsOneWidget);
      expect(find.byKey(const Key('payment-dialog')), findsNothing);
      expect(opened, isEmpty);
      expect(await container.read(licensePurchaseServiceProvider).pending(), isNull);
      expect(tester.widget<FilledButton>(find.byKey(const Key('pay-m6'))).onPressed, isNotNull, reason: 'can try again');

      await close(tester);
    });

    testWidgets('with no internet at the moment of paying it says so', (tester) async {
      await openScreen(tester);
      server.offline = true;

      await buy(tester, 'm6');

      expect(find.textContaining('Could not reach the server'), findsOneWidget);
      expect(find.byKey(const Key('payment-dialog')), findsNothing);

      await close(tester);
    });
  });

  group('a payment that does not complete', () {
    testWidgets('failed: says so, stops asking, and lets the customer choose again', (tester) async {
      server.statusScript = [
        {'success': true, 'status': 'failed', 'message': 'The payment did not go through. You have not been charged for a license - try again.'},
      ];
      await openScreen(tester);

      await buy(tester, 'm6');

      expect(find.text('Payment not completed'), findsOneWidget);
      expect(find.textContaining('did not go through'), findsOneWidget);
      final asked = server.statusCalls;
      await pass(tester, const Duration(seconds: 9));
      expect(server.statusCalls, asked, reason: 'it does not keep asking about a payment that failed');

      await tester.tap(find.byKey(const Key('close-payment')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('payment-dialog')), findsNothing);
      expect(find.byKey(const Key('purchase-in-progress')), findsNothing);
      expect(tester.widget<FilledButton>(find.byKey(const Key('pay-m3'))).onPressed, isNotNull);
      expect(server.activateCalls, 0);

      await close(tester);
    });

    testWidgets('closing the waiting box does not lose the payment: it comes back as "Payment in progress"', (tester) async {
      await openScreen(tester);
      await buy(tester, 'm6');

      await tester.tap(find.byKey(const Key('close-payment')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('purchase-in-progress')), findsOneWidget);
      expect(find.textContaining('KSh 3,000 for 6 months'), findsOneWidget);
      // While one is in progress another cannot be started on top of it.
      expect(tester.widget<FilledButton>(find.byKey(const Key('pay-m12'))).onPressed, isNull);

      // Tapping Check payment goes back to waiting - without opening the page again.
      final openedBefore = opened.length;
      server.statusScript = [{'success': true, 'status': 'issued', 'code': FakeLicenseServer.licenseCode}];
      await tester.tap(find.byKey(const Key('check-payment')));
      await pass(tester, const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(opened.length, openedBefore);
      expect(server.activatedCodes, [FakeLicenseServer.licenseCode]);
      expect(await container.read(licenseServiceProvider).hasValidCachedLicense(), isTrue);

      await close(tester);
    });

    testWidgets('a payment left in progress when the app was closed is offered again when the screen opens', (tester) async {
      await openScreen(tester, beforeOpen: () async {
        await container.read(licensePurchaseServiceProvider).start(
          const PurchasePlan(id: 'm12', label: '1 year', months: 12, amountKes: 4800),
          'buyer@example.com',
        );
      });

      expect(find.byKey(const Key('purchase-in-progress')), findsOneWidget);
      expect(find.textContaining('KSh 4,800 for 1 year'), findsOneWidget);

      await close(tester);
    });

    testWidgets('"Forget it" asks first, and shows the reference in case help is needed', (tester) async {
      await openScreen(tester);
      await buy(tester, 'm6');
      await tester.tap(find.byKey(const Key('close-payment')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('forget-payment')));
      await tester.pumpAndSettle();
      expect(find.text('Forget this payment?'), findsOneWidget);
      expect(find.textContaining('nxl-test0001'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Keep it'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('purchase-in-progress')), findsOneWidget, reason: 'kept');

      await tester.tap(find.byKey(const Key('forget-payment')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Forget it')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('purchase-in-progress')), findsNothing);
      expect(await container.read(secureStorageProvider).read(key: 'nexapos.purchase.pending'), isNull);

      await close(tester);
    });
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('everything fits a ${width.toInt()}-pixel-wide phone: the plans, the email prompt and the waiting box', (tester) async {
      await openScreen(tester, size: Size(width, 2400));

      expect(find.widgetWithText(FilledButton, 'KSh 4,800'), findsOneWidget);
      expect(find.text('Best value'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'no overflow on the plan cards');

      await tester.tap(find.byKey(const Key('pay-m12')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'no overflow in the email prompt');

      await tester.enterText(find.byKey(const Key('purchase-email')), 'buyer@example.com');
      await tester.tap(find.byKey(const Key('purchase-continue')));
      await pass(tester, const Duration(seconds: 1));
      expect(find.byKey(const Key('payment-dialog')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'no overflow in the waiting box');

      await close(tester);
    });
  }

  group('restoring after a reinstall', () {
    Future<void> openRestore(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const Key('restore-open')));
      await tester.tap(find.byKey(const Key('restore-open')));
      await tester.pumpAndSettle();
    }

    Future<void> sendCode(WidgetTester tester, {String email = 'me@shop.co.ke'}) async {
      await tester.enterText(find.byKey(const Key('restore-email')), email);
      await tester.tap(find.byKey(const Key('restore-send-code')));
      await tester.pumpAndSettle();
    }

    testWidgets('is offered on the activation screen, next to the plans', (tester) async {
      await openScreen(tester);

      expect(find.byKey(const Key('restore-open')), findsOneWidget);
      expect(find.text('Already paid? Restore my license'), findsOneWidget);
      expect(find.byKey(const Key('restore-dialog')), findsNothing);

      await close(tester);
    });

    testWidgets('asks for the email first, checking it, and says what it does and does not bring back', (tester) async {
      await openScreen(tester);
      await openRestore(tester);

      expect(find.byKey(const Key('restore-dialog')), findsOneWidget);
      expect(find.textContaining('Reinstalled NexaPOS or changed phone?'), findsOneWidget);
      expect(find.textContaining('Your shop data is not part of it'), findsOneWidget);

      await tester.tap(find.byKey(const Key('restore-send-code')));
      await tester.pumpAndSettle();
      expect(find.text('Enter the email address you paid with.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('restore-email')), 'not-an-email');
      await tester.tap(find.byKey(const Key('restore-send-code')));
      await tester.pumpAndSettle();
      expect(find.text('Enter the email address you paid with.'), findsOneWidget);
      expect(server.restoreStartCalls, 0, reason: 'nothing is sent until the email looks right');

      await close(tester);
    });

    testWidgets('the whole trip: email, emailed code, and this device is licensed', (tester) async {
      await openScreen(tester);
      await openRestore(tester);

      await sendCode(tester);

      expect(server.lastRestoreStart, {'device_id': 'test-device', 'email': 'me@shop.co.ke'});
      expect(find.byKey(const Key('restore-info')), findsOneWidget);
      expect(find.textContaining('6-digit code is on its way'), findsOneWidget);
      expect(find.textContaining('Sent to me@shop.co.ke'), findsOneWidget);
      expect(find.byKey(const Key('restore-code')), findsOneWidget);
      expect(server.activateCalls, 0);

      await tester.enterText(find.byKey(const Key('restore-code')), '123456');
      await tester.tap(find.byKey(const Key('restore-confirm')));
      await tester.pumpAndSettle();

      expect(server.lastRestoreConfirm, {'device_id': 'test-device', 'email': 'me@shop.co.ke', 'code': '123456'});
      expect(server.activatedCodes, [FakeLicenseServer.restoredLicenseCode]);
      expect(find.byKey(const Key('restore-dialog')), findsNothing);
      expect(await container.read(licenseServiceProvider).hasValidCachedLicense(), isTrue);

      await close(tester);
    });

    testWidgets('a wrong code is explained and can be retried; nothing is activated', (tester) async {
      await openScreen(tester);
      await openRestore(tester);
      await sendCode(tester);

      await tester.enterText(find.byKey(const Key('restore-code')), '999999');
      await tester.tap(find.byKey(const Key('restore-confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('restore-error')), findsOneWidget);
      expect(find.textContaining('not right'), findsOneWidget);
      expect(find.byKey(const Key('restore-dialog')), findsOneWidget, reason: 'stays open to try again');
      expect(server.activateCalls, 0);

      await tester.enterText(find.byKey(const Key('restore-code')), '123456');
      await tester.tap(find.byKey(const Key('restore-confirm')));
      await tester.pumpAndSettle();
      expect(server.activatedCodes, [FakeLicenseServer.restoredLicenseCode]);

      await close(tester);
    });

    testWidgets('a code that is not 6 digits is not sent', (tester) async {
      await openScreen(tester);
      await openRestore(tester);
      await sendCode(tester);

      await tester.enterText(find.byKey(const Key('restore-code')), '12');
      await tester.tap(find.byKey(const Key('restore-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Enter the 6-digit code from the email.'), findsOneWidget);
      expect(server.restoreConfirmCalls, 0);

      await close(tester);
    });

    testWidgets('only digits can be typed into the code box', (tester) async {
      await openScreen(tester);
      await openRestore(tester);
      await sendCode(tester);

      await tester.enterText(find.byKey(const Key('restore-code')), '1a2b3c4d5e6f7');

      expect(tester.widget<TextField>(find.byKey(const Key('restore-code'))).controller!.text, '123456');

      await close(tester);
    });

    testWidgets('a new code can be asked for, and a different email tried', (tester) async {
      await openScreen(tester);
      await openRestore(tester);
      await sendCode(tester);
      expect(server.restoreStartCalls, 1);

      await tester.tap(find.byKey(const Key('restore-resend')));
      await tester.pumpAndSettle();
      expect(server.restoreStartCalls, 2);

      await tester.tap(find.byKey(const Key('restore-other-email')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('restore-email')), findsOneWidget);
      await sendCode(tester, email: 'other@shop.co.ke');
      expect(server.lastRestoreStart, {'device_id': 'test-device', 'email': 'other@shop.co.ke'});

      await close(tester);
    });

    testWidgets('the server refusing (too many tries) is shown in its words', (tester) async {
      server.restoreStartAnswer = http.Response(
        jsonEncode({'success': false, 'message': 'Too many attempts. Wait a little while, then try again.'}),
        429,
      );
      await openScreen(tester);
      await openRestore(tester);

      await sendCode(tester);

      expect(find.textContaining('Too many attempts'), findsOneWidget);
      expect(find.byKey(const Key('restore-code')), findsNothing, reason: 'no code was sent, so no code box');

      await close(tester);
    });

    testWidgets('no internet says so', (tester) async {
      await openScreen(tester);
      await openRestore(tester);
      server.offline = true;

      await sendCode(tester);

      expect(find.textContaining('Could not reach the server'), findsOneWidget);

      await close(tester);
    });

    testWidgets('cancelling changes nothing', (tester) async {
      await openScreen(tester);
      await openRestore(tester);

      await tester.tap(find.byKey(const Key('restore-cancel')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('restore-dialog')), findsNothing);
      expect(server.restoreStartCalls, 0);
      expect(server.activateCalls, 0);

      await close(tester);
    });

    testWidgets('offers the email last used', (tester) async {
      await openScreen(tester, beforeOpen: () async {
        await container.read(secureStorageProvider).write(key: 'nexapos.purchase.email', value: 'me@shop.co.ke');
      });
      await openRestore(tester);

      expect(find.widgetWithText(TextField, 'me@shop.co.ke'), findsOneWidget);

      await close(tester);
    });

    testWidgets('a typed key that "belongs to another device" points the customer at Restore', (tester) async {
      server.activateAnswer = http.Response(
        jsonEncode({'success': false, 'message': 'This license belongs to another device. Contact support with your device ID.'}),
        422,
      );
      await openScreen(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'License key'), 'ABCDE23456');
      await tester.tap(find.widgetWithText(FilledButton, 'Activate'));
      await tester.pumpAndSettle();

      expect(find.textContaining('belongs to another device'), findsOneWidget);
      expect(find.textContaining('Restore my license'), findsWidgets);
      expect(find.textContaining('Reinstalled or changed phone?'), findsOneWidget);

      await close(tester);
    });

    for (final width in [320.0, 360.0]) {
      testWidgets('fits a ${width.toInt()}-pixel-wide phone, both steps', (tester) async {
        await openScreen(tester, size: Size(width, 2400));
        expect(tester.takeException(), isNull, reason: 'no overflow on the activation screen');

        await openRestore(tester);
        expect(tester.takeException(), isNull, reason: 'no overflow asking for the email');

        await sendCode(tester);
        expect(find.byKey(const Key('restore-code')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'no overflow asking for the code');

        await tester.enterText(find.byKey(const Key('restore-code')), '999999');
        await tester.tap(find.byKey(const Key('restore-confirm')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('restore-error')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'no overflow with an error showing');

        await close(tester);
      });
    }
  });

  group('the device ID on the activation screen', () {
    testWidgets('is shown, so a customer can give it to support', (tester) async {
      await openScreen(tester);

      expect(find.byKey(const Key('device-id')), findsOneWidget);
      expect(find.text('test-device'), findsOneWidget);
      expect(find.textContaining('Give support this device ID'), findsOneWidget);

      await close(tester);
    });

    testWidgets('can be copied', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await openScreen(tester);

      await tester.ensureVisible(find.byKey(const Key('copy-device-id')));
      await tester.tap(find.byKey(const Key('copy-device-id')));
      await tester.pump();

      expect(copied, 'test-device');
      expect(find.text('Device ID copied'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await close(tester);
    });

    for (final width in [320.0, 360.0]) {
      testWidgets('a long ID still fits a ${width.toInt()}-pixel-wide phone', (tester) async {
        tester.view.physicalSize = Size(width, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        db = AppDatabase(NativeDatabase.memory());
        container = ProviderContainer(overrides: [
          appDatabaseProvider.overrideWith((ref) => db),
          syncMetadataProvider.overrideWithValue(_LongDevice(db)),
          licenseGatewayProvider.overrideWith((ref) => LicenseGateway(server.client)),
        ]);
        await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ActivationScreen()),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('device-id')), findsOneWidget);
        expect(tester.takeException(), isNull);

        await close(tester);
      });
    }
  });

  testWidgets('the email last used is offered next time', (tester) async {
    await openScreen(tester, beforeOpen: () async {
      await container.read(secureStorageProvider).write(key: 'nexapos.purchase.email', value: 'me@shop.co.ke');
    });

    await tester.tap(find.byKey(const Key('pay-m3')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'me@shop.co.ke'), findsOneWidget);

    await close(tester);
  });
}
