import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/data/payments/platform_onboarding_gateway.dart';
import 'package:nexapos_mobile/features/settings/device_sync_screen.dart';

import '../support/fake_secure_storage.dart';

/// The join screen already told a device "This device was already registered as
/// ... for ..." and then offered only an invite-code field. These pin what the
/// person now sees on that screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  setUp(() {
    installFakeSecureStorage();
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<void> openJoinScreen(WidgetTester tester, {required http.Response Function(String action) answer}) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          platformOnboardingGatewayProvider.overrideWithValue(
            PlatformOnboardingGateway(
              MockClient((request) async => answer(request.url.queryParameters['action'] ?? '')),
            ),
          ),
        ],
        child: const MaterialApp(home: DeviceSyncScreen(joinOnly: true)),
      ),
    );
    await tester.pumpAndSettle();
  }

  http.Response known({bool disabled = false, bool isOwner = false}) => http.Response(
    jsonEncode({
      'success': true,
      'device_label': 'iPhone test',
      'business_name': 'NEXAPOS_PILOT_TEST',
      'is_disabled': disabled,
      'is_owner': isOwner,
    }),
    200,
  );

  testWidgets('a device the shop already knows gets a Reconnect button - no invite code needed', (tester) async {
    await openJoinScreen(tester, answer: (action) => action == 'registration_lookup' ? known() : http.Response('{}', 404));

    expect(find.text('Reconnect to "NEXAPOS_PILOT_TEST"'), findsOneWidget);
    expect(find.textContaining('Tap Reconnect to go straight back in'), findsOneWidget);
    // Joining a DIFFERENT shop with a code is still there, below it.
    expect(find.text('Invite code'), findsOneWidget);
    expect(find.text('Or join a different shop with an invite code'), findsOneWidget);
    // The name the shop knows this device by is filled in, ready to reuse.
    expect(find.widgetWithText(TextField, 'iPhone test'), findsOneWidget);
  });

  testWidgets(
    'a device that is the OWNER of its own shop is pointed at its license key, not offered Reconnect',
    (tester) async {
      await openJoinScreen(
        tester,
        answer: (action) => action == 'registration_lookup' ? known(isOwner: true) : http.Response('{}', 404),
      );

      expect(find.textContaining('Reconnect to'), findsNothing);
      expect(find.textContaining('it was set up with a license key'), findsOneWidget);
      expect(find.text('Enter my license key'), findsOneWidget);
      // Joining a DIFFERENT shop with a code is still available.
      expect(find.text('Invite code'), findsOneWidget);
      expect(find.text('Or join a different shop with an invite code'), findsOneWidget);
    },
  );

  testWidgets('a device the shop DISABLED is not offered Reconnect', (tester) async {
    await openJoinScreen(tester, answer: (action) => action == 'registration_lookup' ? known(disabled: true) : http.Response('{}', 404));

    expect(find.textContaining('Reconnect to'), findsNothing);
    expect(find.textContaining('was disabled by'), findsOneWidget);
  });

  testWidgets('a device nobody knows sees the normal join form, no Reconnect', (tester) async {
    await openJoinScreen(
      tester,
      answer: (action) => http.Response(jsonEncode({'success': false, 'message': 'Not registered yet.'}), 404),
    );

    expect(find.textContaining('Reconnect'), findsNothing);
    expect(find.text('Invite code'), findsOneWidget);
    expect(find.text('Join'), findsOneWidget);
    // Nothing to reset for a device that was never registered anywhere.
    expect(find.textContaining('Reset this device'), findsNothing);
  });

  testWidgets(
    'stuck as the owner: Reset gives this device a fresh identity so it can join a different shop',
    (tester) async {
      await openJoinScreen(
        tester,
        answer: (action) => action == 'registration_lookup' ? known(isOwner: true) : http.Response('{}', 404),
      );
      expect(find.text('Enter my license key'), findsOneWidget);

      await tester.tap(find.text('Reset this device and join a different shop'));
      await tester.pumpAndSettle();
      // The confirmation dialog - keeping local data is the safe default for
      // this escape hatch, so pick that option rather than the erase-data one.
      expect(find.text('Reset this device\'s identity?'), findsOneWidget);
      await tester.tap(find.text('Reset identity only'));
      await tester.pumpAndSettle();

      // The owner banner and its "enter my license key" dead end are gone -
      // this is now an unregistered identity, free to join any shop.
      expect(find.text('Enter my license key'), findsNothing);
      expect(find.textContaining('was already registered'), findsNothing);
      expect(find.text('Invite code'), findsOneWidget);
      expect(find.text('Join'), findsOneWidget);
    },
  );

  testWidgets('a DISABLED device can also reset and join a different shop instead of reinstalling', (tester) async {
    await openJoinScreen(
      tester,
      answer: (action) => action == 'registration_lookup' ? known(disabled: true) : http.Response('{}', 404),
    );

    await tester.tap(find.text('Reset this device and join a different shop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset identity only'));
    await tester.pumpAndSettle();

    expect(find.textContaining('was disabled by'), findsNothing);
    expect(find.text('Invite code'), findsOneWidget);
  });
}
