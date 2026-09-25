import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/result.dart';
import 'package:nexapos_mobile/data/licensing/license_gateway.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/data/update/update_gateway.dart';
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

const _available = UpdateCheckResult(
  currentVersion: '1.0.47',
  updateAvailable: true,
  latest: LatestVersionInfo(
    version: '1.0.49',
    androidUrl: 'https://downloads.example/NexaPOS-1.0.49.apk',
    windowsInstallerUrl: 'https://downloads.example/NexaPOS-Setup-1.0.49.exe',
    // What was once typed into the publish form's notes box.
    releaseNotes: 'https://downloads.example/NexaPOS-Setup-1.0.46.exe',
  ),
);
const _none = UpdateCheckResult(currentVersion: '1.0.49', updateAvailable: false);

class _Updates implements UpdateService {
  _Updates(this.result);

  UpdateCheckResult result;
  int checks = 0;
  final List<LatestVersionInfo> installs = [];

  /// When set, install() waits for it (so a test can look at the screen mid-download).
  Completer<Result<void>>? hold;
  Result<void> answer = const Result.ok(null);

  @override
  Future<UpdateCheckResult> checkForUpdate() async {
    checks++;
    return result;
  }

  @override
  Future<Result<void>> install(LatestVersionInfo info, {void Function(double)? onProgress}) async {
    installs.add(info);
    onProgress?.call(0.4);
    final waiting = hold;
    if (waiting != null) return waiting.future;
    return answer;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLicenseServer server;
  late AppDatabase db;
  late ProviderContainer container;
  late _Updates updates;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    installFakeSecureStorage();
    server = FakeLicenseServer();
  });

  Future<void> openScreen(WidgetTester tester, UpdateCheckResult result, {Size size = const Size(1000, 3000)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    updates = _Updates(result);
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
      syncMetadataProvider.overrideWithValue(_FixedDevice(db)),
      licenseGatewayProvider.overrideWith((ref) => LicenseGateway(server.client)),
      updateServiceProvider.overrideWith((ref) => updates),
    ]);
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

  testWidgets('with no update, the screen says nothing about updates - but did ask', (tester) async {
    await openScreen(tester, _none);

    expect(find.byKey(const Key('activation-update')), findsNothing);
    expect(find.textContaining('Update available'), findsNothing);
    expect(updates.checks, greaterThanOrEqualTo(1), reason: 'opening the screen asks right away, not two minutes later');

    await close(tester);
  });

  testWidgets('an available update is announced with only its version - on a device that has no license', (tester) async {
    await openScreen(tester, _available);

    expect(find.byKey(const Key('activation-update')), findsOneWidget);
    expect(find.text('Update available: 1.0.49'), findsOneWidget);
    expect(find.textContaining('does not need a license'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Download & Install'), findsOneWidget);
    // No download link and none of the release-notes text anywhere.
    expect(find.textContaining('https://'), findsNothing);
    expect(find.textContaining('.exe'), findsNothing);
    expect(find.textContaining('.apk'), findsNothing);
    // At the very top, above the activation heading.
    expect(
      tester.getTopLeft(find.byKey(const Key('activation-update'))).dy,
      lessThan(tester.getTopLeft(find.text('Activate NexaPOS')).dy),
    );

    await close(tester);
  });

  testWidgets('it does not get in the way of paying, restoring or typing a key', (tester) async {
    await openScreen(tester, _available);

    expect(find.byKey(const Key('pay-m6')), findsOneWidget);
    expect(find.byKey(const Key('restore-open')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Activate'), findsOneWidget);

    await close(tester);
  });

  testWidgets('one tap runs the update right there, with progress, and says when the installer opened', (tester) async {
    await openScreen(tester, _available);
    updates.hold = Completer<Result<void>>();

    await tester.tap(find.byKey(const Key('activation-update-install')));
    await tester.pump();

    expect(updates.installs.map((i) => i.version), ['1.0.49']);
    expect(find.byKey(const Key('activation-update-install')), findsNothing, reason: 'no second tap while it downloads');
    expect(find.text('Downloading... 40%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsWidgets);

    updates.hold!.complete(const Result.ok(null));
    await tester.pump();
    await tester.pump();

    expect(find.text('Installer opened - finish the install there, then reopen NexaPOS.'), findsOneWidget);
    expect(find.byKey(const Key('activation-update-error')), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await close(tester);
  });

  testWidgets('a failed download says why and lets the customer try again', (tester) async {
    await openScreen(tester, _available);
    updates.answer = const Result.failure('Not enough free space to download the update.');

    await tester.tap(find.byKey(const Key('activation-update-install')));
    await tester.pumpAndSettle();

    expect(find.text('Not enough free space to download the update.'), findsOneWidget);
    expect(find.byKey(const Key('activation-update-install')), findsOneWidget, reason: 'can try again');

    updates.answer = const Result.ok(null);
    await tester.tap(find.byKey(const Key('activation-update-install')));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(updates.installs, hasLength(2));
    expect(find.byKey(const Key('activation-update-error')), findsNothing, reason: 'the old error is gone');

    await close(tester);
  });

  testWidgets('an update the background check finds later appears by itself, and one that is gone disappears', (tester) async {
    await openScreen(tester, _none);
    expect(find.byKey(const Key('activation-update')), findsNothing);

    container.read(updateAvailabilityProvider.notifier).applyResult(_available);
    await tester.pump();
    expect(find.text('Update available: 1.0.49'), findsOneWidget);

    container.read(updateAvailabilityProvider.notifier).applyResult(_none);
    await tester.pump();
    expect(find.byKey(const Key('activation-update')), findsNothing);

    await close(tester);
  });

  testWidgets('an unreachable update server leaves the screen exactly as it was', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
      syncMetadataProvider.overrideWithValue(_FixedDevice(db)),
      licenseGatewayProvider.overrideWith((ref) => LicenseGateway(server.client)),
      updateServiceProvider.overrideWith((ref) => _Broken()),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ActivationScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activation-update')), findsNothing);
    expect(find.text('Activate NexaPOS'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await close(tester);
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('fits a ${width.toInt()}-pixel-wide phone: announced, downloading and failed', (tester) async {
      await openScreen(tester, _available, size: Size(width, 2600));
      expect(tester.takeException(), isNull, reason: 'no overflow when announced');

      updates.hold = Completer<Result<void>>();
      await tester.tap(find.byKey(const Key('activation-update-install')));
      await tester.pump();
      expect(find.text('Downloading... 40%'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'no overflow while downloading');

      updates.hold!.complete(const Result.failure('The downloaded update failed an integrity check and was not installed. Try again, or contact support if it keeps happening.'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byKey(const Key('activation-update-error')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'no overflow with a long error');

      await close(tester);
    });
  }
}

class _Broken implements UpdateService {
  @override
  Future<UpdateCheckResult> checkForUpdate() async => throw const UpdateOfflineException();

  @override
  Future<Result<void>> install(LatestVersionInfo info, {void Function(double)? onProgress}) async =>
      const Result.failure('not used');
}
