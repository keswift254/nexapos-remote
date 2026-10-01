import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/app_security_service.dart';
import 'package:nexapos_mobile/domain/services/auth_service.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/features/auth/login_screen.dart';

import '../../support/fake_secure_storage.dart';

/// A real report: Windows 11 can open the Windows Hello dialog BEHIND the
/// maximized POS window, so the app appears to hang on "Sign in" with no
/// visible prompt. These pin the taskbar hint that tells a stuck user what
/// to do - windows-only (web has no such OS-level prompt to hide; other
/// platforms don't render a taskbar the user could look at).
///
/// Deliberately never calls pumpAndSettle(): this screen's "Use fingerprint..."
/// button is driven by a FutureBuilder whose `future:` is built fresh on every
/// rebuild (`ref.read(...).canUseBiometricLogin()` called straight from
/// build()), which pumpAndSettle() can chase forever as each resolution
/// triggers a rebuild that hands it a brand new, not-yet-resolved Future - an
/// existing issue in this screen, unrelated to the one line this file tests, so
/// left alone here (confirmed: these tests hung for the full 10-minute runner
/// timeout with pumpAndSettle() before being rewritten this way). A short,
/// bounded pump() sequence resolves the fake, instant-settling services this
/// test actually uses without that risk.
///
/// `authenticate()` is called TWICE in the real flow this test drives - once
/// by AppSecurityService.enableFor() during enrollment (setUp, before the
/// widget is even pumped) and again by the actual login attempt this test
/// means to hold pending. One shared Completer for both deadlocks setUp
/// itself (it awaits the first call, which this test does not complete until
/// long after setUp has already returned) - [pending] only governs calls
/// from the second one onward.
class _DeviceAuthentication implements DeviceAuthenticationGateway {
  final Completer<bool> pending = Completer<bool>();
  int calls = 0;

  @override
  Future<bool> authenticate() {
    calls++;
    return calls == 1 ? Future.value(true) : pending.future;
  }

  @override
  Future<bool> isSupported() async => true;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUp(installFakeSecureStorage);

  Future<ProviderContainer> buildSignedOutContainer(_DeviceAuthentication device) async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceAuthenticationGatewayProvider.overrideWithValue(device),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final created = await container.read(authServiceProvider).createUser(
          name: 'Felix', username: 'felix', password: 'secret123', role: UserRole.admin,
        );
    final user = created.when(ok: (value) => value, failure: (message) => throw StateError(message));
    await container.read(appSecurityServiceProvider).enableFor(user);
    return container;
  }

  testWidgets('on Windows, the taskbar hint appears only while the prompt is pending, then clears', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final device = _DeviceAuthentication();
    final container = await buildSignedOutContainer(device);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: LoginScreen()),
    ));
    await _settle(tester);
    expect(find.byKey(const Key('windows-hello-taskbar-hint')), findsNothing,
        reason: 'not shown before the prompt starts');

    await tester.tap(find.text('Use fingerprint, face, or Windows Hello'));
    await tester.pump();

    expect(find.byKey(const Key('windows-hello-taskbar-hint')), findsOneWidget,
        reason: 'shown while Windows Hello is pending, in case its dialog opened behind the app');
    expect(find.textContaining('select the Windows Security icon'), findsOneWidget);

    device.pending.complete(true);
    await _settle(tester);

    expect(find.byKey(const Key('windows-hello-taskbar-hint')), findsNothing,
        reason: 'cleared once the prompt resolves');
    expect(container.read(sessionProvider)?.username, 'felix');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the hint never appears off Windows, even while the prompt is pending', (tester) async {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS]) {
      debugDefaultTargetPlatformOverride = platform;
      final device = _DeviceAuthentication();
      final container = await buildSignedOutContainer(device);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LoginScreen()),
      ));
      await _settle(tester);
      await tester.tap(find.text('Use fingerprint, face, or Windows Hello'));
      await tester.pump();

      expect(find.byKey(const Key('windows-hello-taskbar-hint')), findsNothing, reason: '$platform has no such taskbar');

      device.pending.complete(true);
      await _settle(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a cancelled prompt on Windows clears the hint and shows the real error, not silently', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final device = _DeviceAuthentication();
    final container = await buildSignedOutContainer(device);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: LoginScreen()),
    ));
    await _settle(tester);
    await tester.tap(find.text('Use fingerprint, face, or Windows Hello'));
    await tester.pump();
    expect(find.byKey(const Key('windows-hello-taskbar-hint')), findsOneWidget);

    device.pending.complete(false);
    await _settle(tester);

    expect(find.byKey(const Key('windows-hello-taskbar-hint')), findsNothing);
    expect(find.textContaining('could not verify you'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
