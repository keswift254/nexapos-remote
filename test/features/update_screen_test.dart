import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/core/result.dart';
import 'package:nexapos_mobile/data/update/update_gateway.dart';
import 'package:nexapos_mobile/domain/services/update_service.dart';
import 'package:nexapos_mobile/features/settings/update_screen.dart';

class _Updates implements UpdateService {
  _Updates(this.result);

  final UpdateCheckResult result;

  @override
  Future<UpdateCheckResult> checkForUpdate() async => result;

  @override
  Future<Result<void>> install(LatestVersionInfo info, {void Function(double)? onProgress}) async =>
      const Result.failure('Installation is disabled in this test.');
}

void main() {
  Future<ProviderContainer> open(WidgetTester tester, UpdateCheckResult result) async {
    final container = ProviderContainer(overrides: [
      updateServiceProvider.overrideWith((ref) => _Updates(result)),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: UpdateScreen()),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> close(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  }

  testWidgets('an available update says only "Update available" and the version', (tester) async {
    final container = await open(
      tester,
      const UpdateCheckResult(
        currentVersion: '1.0.46',
        updateAvailable: true,
        latest: LatestVersionInfo(
          version: '1.0.47',
          androidUrl: 'https://downloads.example/NexaPOS-1.0.47.apk',
          windowsInstallerUrl: 'https://downloads.example/NexaPOS-Setup-1.0.47.exe',
          // What was once typed into the publish form's notes box.
          releaseNotes: 'https://nexapos-downloads.condojuniur.workers.dev/NexaPOS-Setup-1.0.46.exe',
        ),
      ),
    );

    expect(find.text('Update available: 1.0.47'), findsOneWidget);
    expect(find.text('Installed version'), findsOneWidget);
    expect(find.text('1.0.46'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Download & Install'), findsOneWidget);
    // No download link, and none of the release-notes text, anywhere on the screen.
    expect(find.textContaining('https://'), findsNothing);
    expect(find.textContaining('.exe'), findsNothing);
    expect(find.textContaining('.apk'), findsNothing);

    await close(tester, container);
  });

  testWidgets('real release notes are not shown here either - just the version', (tester) async {
    final container = await open(
      tester,
      const UpdateCheckResult(
        currentVersion: '1.0.46',
        updateAvailable: true,
        latest: LatestVersionInfo(
          version: '1.0.47',
          androidUrl: '',
          releaseNotes: 'License time can no longer be changed by changing the date.',
        ),
      ),
    );

    expect(find.text('Update available: 1.0.47'), findsOneWidget);
    expect(find.textContaining('License time'), findsNothing);

    await close(tester, container);
  });

  testWidgets('when there is no update it says so and shows no update card', (tester) async {
    final container = await open(
      tester,
      const UpdateCheckResult(currentVersion: '1.0.47', updateAvailable: false),
    );

    expect(find.text("You're on the latest version."), findsOneWidget);
    expect(find.textContaining('Update available'), findsNothing);

    await close(tester, container);
  });
}
