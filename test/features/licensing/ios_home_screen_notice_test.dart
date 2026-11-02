import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/result.dart';
import 'package:nexapos_mobile/data/licensing/license_gateway.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/data/update/update_gateway.dart';
import 'package:nexapos_mobile/domain/services/home_screen_install_service.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import 'package:nexapos_mobile/domain/services/update_service.dart';
import 'package:nexapos_mobile/features/licensing/activation_screen.dart';

import '../../support/fake_license_server.dart';
import '../../support/fake_secure_storage.dart';

class _FixedDevice extends SyncMetadataService {
  _FixedDevice(super.db);
  @override
  Future<String> deviceId() async => 'test-device';
}

class _NoUpdates implements UpdateService {
  @override
  Future<UpdateCheckResult> checkForUpdate() async =>
      const UpdateCheckResult(currentVersion: '1.0.76', updateAvailable: false);

  @override
  Future<Result<void>> install(
    LatestVersionInfo info, {
    void Function(double)? onProgress,
  }) async => const Result.ok(null);
}

/// The browser engine is replaced by a fixed answer about how NexaPOS was opened.
class _FakeInstall extends HomeScreenInstallNotifier {
  _FakeInstall(this._state);
  final HomeScreenInstallState _state;

  @override
  HomeScreenInstallState build() => _state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLicenseServer server;
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    installFakeSecureStorage();
    server = FakeLicenseServer();
  });

  Future<void> openScreen(
    WidgetTester tester,
    HomeScreenInstallState openedAs,
  ) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) => db),
        syncMetadataProvider.overrideWithValue(_FixedDevice(db)),
        licenseGatewayProvider.overrideWith(
          (ref) => LicenseGateway(server.client),
        ),
        updateServiceProvider.overrideWith((ref) => _NoUpdates()),
        homeScreenInstallProvider.overrideWith(() => _FakeInstall(openedAs)),
      ],
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ActivationScreen()),
        GoRoute(
          path: '/join-shop',
          builder: (_, _) => const Scaffold(body: Text('the join screen')),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await db.close();
  }

  const noticeKey = Key('ios-home-screen-notice');

  testWidgets(
    'opened from an iPhone Home Screen: says its data is separate and offers to join the shop',
    (tester) async {
      await openScreen(
        tester,
        const HomeScreenInstallState(
          isIosHomeScreenApp: true,
          isIosSafari: true,
        ),
      );

      expect(find.byKey(noticeKey), findsOneWidget);
      expect(find.text('Opened from your Home Screen?'), findsOneWidget);
      expect(find.textContaining('keeps its own data'), findsOneWidget);
      expect(
        find.textContaining('Settings > Sync & Invites > Invite a device'),
        findsOneWidget,
      );
      expect(find.text('Join my existing shop'), findsOneWidget);
      // Above the activation heading: it is the first thing to read.
      expect(
        tester.getTopLeft(find.byKey(noticeKey)).dy,
        lessThan(tester.getTopLeft(find.text('Activate NexaPOS')).dy),
      );

      await close(tester);
    },
  );

  testWidgets('the button goes straight to joining an existing shop', (
    tester,
  ) async {
    await openScreen(
      tester,
      const HomeScreenInstallState(isIosHomeScreenApp: true, isIosSafari: true),
    );

    await tester.tap(find.byKey(const Key('ios-home-screen-join')));
    await tester.pumpAndSettle();
    expect(find.text('the join screen'), findsOneWidget);

    await close(tester);
  });

  testWidgets(
    'it does not get in the way of paying, restoring or typing a key',
    (tester) async {
      await openScreen(
        tester,
        const HomeScreenInstallState(
          isIosHomeScreenApp: true,
          isIosSafari: true,
        ),
      );

      expect(find.byKey(const Key('restore-open')), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Activate'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Join an existing shop'),
        findsOneWidget,
      );

      await close(tester);
    },
  );

  testWidgets(
    'not shown in a Safari tab, on Android, or in the installed app',
    (tester) async {
      for (final state in const [
        HomeScreenInstallState(
          isStandalone: false,
          isIosSafari: true,
        ), // iPhone Safari tab
        HomeScreenInstallState(
          isStandalone: true,
        ), // Android home-screen app / native
        HomeScreenInstallState(), // the default
      ]) {
        await openScreen(tester, state);
        expect(find.byKey(noticeKey), findsNothing, reason: '$state');
        await close(tester);
      }
    },
  );
}
