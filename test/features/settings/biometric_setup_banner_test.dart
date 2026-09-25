import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/secure_storage_provider.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/app_security_service.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/features/settings/biometric_setup_banner.dart';

import '../../support/fake_secure_storage.dart';

class _Gateway implements DeviceAuthenticationGateway {
  bool supported = true;
  bool approve = true;
  int asked = 0;
  @override
  Future<bool> isSupported() async => supported;
  @override
  Future<bool> authenticate() async {
    asked++;
    return approve;
  }
}

User _user(String id) =>
    User(id: id, role: UserRole.cashier, name: id, username: id, passwordHash: '', status: 'active');

class _Session extends SessionNotifier {
  _Session(this._start);
  final User? _start;
  @override
  User? build() => _start;
  void signIn(User? user) => state = user;
}

void main() {
  late _Gateway gateway;
  late FixedClock clock;
  late ProviderContainer container;

  setUp(() {
    installFakeSecureStorage();
    gateway = _Gateway();
    clock = FixedClock(DateTime.utc(2026, 9, 26, 8));
  });

  Future<void> open(WidgetTester tester, {User? signedIn, Size size = const Size(800, 600)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final user = signedIn ?? _user('cashier-1');
    container = ProviderContainer(overrides: [
      deviceAuthenticationGatewayProvider.overrideWithValue(gateway),
      clockProvider.overrideWith((ref) => clock),
      sessionProvider.overrideWith(() => _Session(user)),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: BiometricSetupBanner()))),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  }

  Future<String?> stored(String key) => container.read(secureStorageProvider).read(key: key);

  testWidgets('a device that can do it, where nobody has set it up: the reminder shows, with a Dismiss button beside it', (tester) async {
    await open(tester);

    expect(find.byKey(const Key('biometric-setup-banner')), findsOneWidget);
    expect(find.textContaining('to set up biometrics for easier login'), findsOneWidget);
    expect(find.byKey(const Key('biometric-setup-dismiss')), findsOneWidget);
    // Beside it: the same row.
    final text = tester.getCenter(find.byKey(const Key('biometric-setup-tap')));
    final dismiss = tester.getCenter(find.byKey(const Key('biometric-setup-dismiss')));
    expect((text.dy - dismiss.dy).abs(), lessThan(20));
    expect(dismiss.dx, greaterThan(text.dx));

    await close(tester);
  });

  testWidgets('it says "Click" on a desktop and "Tap" on a phone', (tester) async {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await open(tester);
      expect(find.textContaining('Click here to set up biometrics'), findsOneWidget);
      await close(tester);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await open(tester);
      expect(find.textContaining('Tap here to set up biometrics'), findsOneWidget);
      await close(tester);
    } finally {
      // Before the test ends: the framework checks this before any tearDown runs.
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a device that cannot do it (no biometrics, web, Windows 7/8) is never nagged', (tester) async {
    gateway.supported = false;
    await open(tester);

    expect(find.byKey(const Key('biometric-setup-banner')), findsNothing);
    await close(tester);
  });

  testWidgets('once quick sign in is set up on this device the reminder is gone', (tester) async {
    await open(tester);
    await container.read(appSecurityServiceProvider).enableFor(_user('cashier-1'));
    await close(tester);

    await open(tester);
    // (the fake storage is per test, kept across the reopen)
    expect(find.byKey(const Key('biometric-setup-banner')), findsNothing);
    await close(tester);
  });

  testWidgets('someone else already set it up on this device: this user is not invited to take it over', (tester) async {
    await open(tester);
    await container.read(appSecurityServiceProvider).enableFor(_user('the-owner'));
    await close(tester);

    await open(tester, signedIn: _user('a-cashier'));

    expect(find.byKey(const Key('biometric-setup-banner')), findsNothing);
    await close(tester);
  });

  testWidgets('nobody signed in: nothing to remind', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(overrides: [
      deviceAuthenticationGatewayProvider.overrideWithValue(gateway),
      clockProvider.overrideWith((ref) => clock),
      sessionProvider.overrideWith(() => _Session(null)),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: BiometricSetupBanner())),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('biometric-setup-banner')), findsNothing);
    await close(tester);
  });

  group('tapping the message', () {
    testWidgets('sets it up right there: the device asks once, the reminder goes, and it says so', (tester) async {
      await open(tester);

      await tester.tap(find.byKey(const Key('biometric-setup-tap')));
      await tester.pumpAndSettle();

      expect(gateway.asked, 1);
      expect(find.byKey(const Key('biometric-setup-banner')), findsNothing);
      expect(find.textContaining('sign in is on'), findsOneWidget);
      expect(await stored('nexapos.security.biometricUserId'), 'cashier-1');
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await close(tester);
    });

    testWidgets('a cancelled prompt leaves the reminder and says what happened', (tester) async {
      gateway.approve = false;
      await open(tester);

      await tester.tap(find.byKey(const Key('biometric-setup-tap')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('biometric-setup-banner')), findsOneWidget);
      expect(find.byKey(const Key('biometric-setup-error')), findsOneWidget);
      expect(find.textContaining('cancelled'), findsOneWidget);
      expect(await stored('nexapos.security.biometricUserId'), isNull);

      await close(tester);
    });

    testWidgets('a device with nothing enrolled is told what to do first', (tester) async {
      await open(tester);
      gateway.supported = false; // it became unsupported between the reminder showing and the tap

      await tester.tap(find.byKey(const Key('biometric-setup-tap')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Set up fingerprint, face recognition, or Windows Hello on this device first'), findsOneWidget);

      await close(tester);
    });
  });

  group('Dismiss', () {
    testWidgets('hides it at once, and it stays away for 72 hours', (tester) async {
      await open(tester);

      await tester.tap(find.byKey(const Key('biometric-setup-dismiss')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('biometric-setup-banner')), findsNothing);
      expect(gateway.asked, 0, reason: 'dismissing does not start the setup');
      expect(
        await stored('nexapos.security.biometricRemindAfter.cashier-1'),
        clock.now().add(const Duration(hours: 72)).toIso8601String(),
      );

      // 71 hours later, opened again: still quiet.
      await close(tester);
      clock.advance(const Duration(hours: 71));
      await open(tester);
      expect(find.byKey(const Key('biometric-setup-banner')), findsNothing);
      await close(tester);
    });

    testWidgets('after 72 hours it comes back', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('biometric-setup-dismiss')));
      await tester.pumpAndSettle();
      await close(tester);

      clock.advance(const Duration(hours: 72, seconds: 1));
      await open(tester);

      expect(find.byKey(const Key('biometric-setup-banner')), findsOneWidget);
      await close(tester);
    });

    testWidgets('and again every 72 hours after each dismissal', (tester) async {
      for (var round = 0; round < 3; round++) {
        await open(tester);
        expect(find.byKey(const Key('biometric-setup-banner')), findsOneWidget, reason: 'round $round');
        await tester.tap(find.byKey(const Key('biometric-setup-dismiss')));
        await tester.pumpAndSettle();
        await close(tester);
        clock.advance(const Duration(hours: 72, minutes: 1));
      }
    });

    testWidgets('a dashboard left open for days brings it back without anyone leaving the screen', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('biometric-setup-dismiss')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('biometric-setup-banner')), findsNothing);

      clock.advance(const Duration(hours: 73));
      await tester.pump(const Duration(minutes: 10));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('biometric-setup-banner')), findsOneWidget);
      await close(tester);
    });

    testWidgets('it is per person: one user dismissing does not silence it for the next', (tester) async {
      await open(tester, signedIn: _user('user-a'));
      await tester.tap(find.byKey(const Key('biometric-setup-dismiss')));
      await tester.pumpAndSettle();
      await close(tester);

      await open(tester, signedIn: _user('user-b'));

      expect(find.byKey(const Key('biometric-setup-banner')), findsOneWidget);
      await close(tester);
    });

    testWidgets('signing in as somebody else while it is showing re-decides for them', (tester) async {
      await open(tester, signedIn: _user('user-a'));
      await container.read(appSecurityServiceProvider).dismissBiometricReminder(_user('user-b'));

      (container.read(sessionProvider.notifier) as _Session).signIn(_user('user-b'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('biometric-setup-banner')), findsNothing);
      await close(tester);
    });
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('fits a ${width.toInt()}-pixel-wide phone, also with an error showing', (tester) async {
      gateway.approve = false;
      await open(tester, size: Size(width, 700));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('biometric-setup-tap')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('biometric-setup-error')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  }

  group('the rule itself (AppSecurityService)', () {
    test('no reminder when a stored reminder time is unreadable - it just counts as none', () async {
      installFakeSecureStorage();
      final c = ProviderContainer(overrides: [
        deviceAuthenticationGatewayProvider.overrideWithValue(gateway),
        clockProvider.overrideWith((ref) => clock),
      ]);
      addTearDown(c.dispose);
      await c.read(secureStorageProvider).write(key: 'nexapos.security.biometricRemindAfter.u', value: 'not a date');

      expect(await c.read(appSecurityServiceProvider).shouldRemindBiometricSetup(_user('u')), isTrue);
    });

    test('any failure reading storage or asking the device means no reminder, never an error', () async {
      final broken = _Broken();
      final c = ProviderContainer(overrides: [
        deviceAuthenticationGatewayProvider.overrideWithValue(broken),
        clockProvider.overrideWith((ref) => clock),
      ]);
      addTearDown(c.dispose);

      expect(await c.read(appSecurityServiceProvider).shouldRemindBiometricSetup(_user('u')), isFalse);
    });

    test('the reminder interval is 72 hours', () {
      expect(biometricReminderEvery, const Duration(hours: 72));
    });
  });
}

class _Broken implements DeviceAuthenticationGateway {
  @override
  Future<bool> isSupported() async => throw StateError('the plugin fell over');
  @override
  Future<bool> authenticate() async => false;
}
