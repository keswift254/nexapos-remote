import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/result.dart';
import 'package:nexapos_mobile/data/update/update_gateway.dart';
import 'package:nexapos_mobile/domain/services/update_service.dart';
import 'package:nexapos_mobile/features/settings/update_screen.dart';
import 'package:nexapos_mobile/features/settings/web_update_controller.dart';

const _latest = LatestVersionInfo(version: '1.0.69', androidUrl: '');
const _available = UpdateCheckResult(
  currentVersion: '1.0.68',
  updateAvailable: true,
  latest: _latest,
);

/// The browser's update, under the test's control.
class _Browser {
  int calls = 0;
  Completer<String?> done = Completer<String?>();
  void Function(double?, String)? onProgress;

  Future<String?> call({void Function(double?, String)? onProgress}) {
    calls++;
    this.onProgress = onProgress;
    done = Completer<String?>();
    return done.future;
  }
}

/// The server's answer, which a test can hold back to keep a check "in flight".
class _Server implements UpdateService {
  int checks = 0;
  UpdateCheckResult answer = _available;
  Completer<void>? hold;

  @override
  Future<UpdateCheckResult> checkForUpdate() async {
    checks++;
    final wait = hold;
    if (wait != null) await wait.future;
    return answer;
  }

  @override
  Future<Result<void>> install(
    LatestVersionInfo info, {
    void Function(double)? onProgress,
  }) async => const Result.failure('not on the web');
}

void main() {
  late _Browser browser;
  late _Server server;
  late ProviderContainer container;

  setUp(() {
    browser = _Browser();
    server = _Server();
    container = ProviderContainer(
      overrides: [
        isWebPlatformProvider.overrideWithValue(true),
        webRefreshProvider.overrideWithValue(browser.call),
        updateServiceProvider.overrideWith((ref) => server),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: UpdateScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapDownload(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Download & Install'));
    await tester.pump();
  }

  double? barValue(WidgetTester tester) => tester
      .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
      .value;

  group('the update itself', () {
    test(
      'progress only ever moves forward, and unknown progress keeps the last',
      () async {
        final started = container.read(webUpdateProvider.notifier).start();
        browser.onProgress!(0.5, 'Downloading');
        browser.onProgress!(0.2, 'Downloading');
        expect(container.read(webUpdateProvider).progress, 0.5);
        browser.onProgress!(null, 'Looking');
        expect(container.read(webUpdateProvider).progress, 0.5);
        browser.done.complete(null);
        await started;
        expect(
          container.read(webUpdateProvider).running,
          isTrue,
          reason: 'the page is restarting',
        );
        expect(container.read(webUpdateProvider).progress, 1);
      },
    );

    test(
      'a second tap while it runs does not start a second download',
      () async {
        final notifier = container.read(webUpdateProvider.notifier);
        final first = notifier.start();
        await notifier.start();
        await notifier.start();
        expect(browser.calls, 1);
        browser.done.complete(null);
        await first;
      },
    );

    test(
      'a failure keeps the reason, stops running, and can be retried',
      () async {
        final notifier = container.read(webUpdateProvider.notifier);
        final first = notifier.start();
        browser.done.complete(
          'The download stopped. Check your internet connection and try again.',
        );
        await first;
        final state = container.read(webUpdateProvider);
        expect(state.running, isFalse);
        expect(
          state.error,
          'The download stopped. Check your internet connection and try again. Your shop data is safe.',
        );
        final second = notifier.start();
        expect(container.read(webUpdateProvider).error, isNull);
        expect(browser.calls, 2);
        browser.done.complete(null);
        await second;
      },
    );

    test('a crash in the browser code is reported, not thrown', () async {
      final crashing = ProviderContainer(
        overrides: [
          webRefreshProvider.overrideWithValue(
            ({onProgress}) async => throw StateError('boom'),
          ),
        ],
      );
      addTearDown(crashing.dispose);
      await crashing.read(webUpdateProvider.notifier).start();
      final state = crashing.read(webUpdateProvider);
      expect(state.running, isFalse);
      expect(state.error, contains('Check your internet connection'));
      expect(state.error, isNot(contains('boom')));
    });
  });

  group('the Software Update screen on the web', () {
    testWidgets('Download & Install shows a real percentage and a moving bar', (
      tester,
    ) async {
      await openScreen(tester);
      await tapDownload(tester);

      expect(browser.calls, 1);
      expect(
        barValue(tester),
        isNull,
        reason: 'nothing known yet: indeterminate',
      );
      expect(find.widgetWithText(FilledButton, 'Updating…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Updating…'),
            )
            .onPressed,
        isNull,
      );

      browser.onProgress!(0.4, 'Downloading the new version…');
      await tester.pump();
      expect(barValue(tester), 0.4);
      expect(find.text('Downloading the new version… 40%'), findsOneWidget);

      browser.onProgress!(0.85, 'Downloading the new version…');
      await tester.pump();
      expect(find.text('Downloading the new version… 85%'), findsOneWidget);
      expect(find.textContaining('Keep this page open'), findsOneWidget);
    });

    testWidgets(
      'Check for Updates in the middle of an update does not stop it',
      (tester) async {
        await openScreen(tester);
        await tapDownload(tester);
        browser.onProgress!(0.4, 'Downloading the new version…');
        await tester.pump();

        // The check is still waiting for the server...
        server.hold = Completer<void>();
        server.answer = const UpdateCheckResult(
          currentVersion: '1.0.69',
          updateAvailable: false,
          latest: _latest,
        );
        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Check for Updates'),
        );
        await tester.pump();
        expect(server.checks, 2);
        expect(
          find.text('Downloading the new version… 40%'),
          findsOneWidget,
          reason: 'progress stays on screen',
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Checking…'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(FilledButton, 'Download & Install'),
          findsNothing,
        );

        // ...and when it answers "nothing newer" (the new files are what it reads), the
        // update carries on and keeps its card.
        server.hold!.complete();
        await tester.pump();
        await tester.pump();
        expect(find.text('Downloading the new version… 40%'), findsOneWidget);
        expect(find.text("You're on the latest version."), findsNothing);
        expect(find.text('Updating to 1.0.69'), findsOneWidget);
        expect(find.textContaining('Update available'), findsNothing);
        expect(
          find.widgetWithText(OutlinedButton, 'Check for Updates'),
          findsOneWidget,
        );

        browser.onProgress!(0.7, 'Downloading the new version…');
        await tester.pump();
        expect(find.text('Downloading the new version… 70%'), findsOneWidget);
        expect(
          browser.calls,
          1,
          reason: 'the check never started or restarted a download',
        );
        expect(container.read(webUpdateProvider).running, isTrue);

        browser.done.complete(null);
        await tester.pump();
        expect(find.text('Restarting… 100%'), findsOneWidget);
      },
    );

    testWidgets(
      'leaving the screen and coming back keeps the progress, with no new check',
      (tester) async {
        await openScreen(tester);
        await tapDownload(tester);
        browser.onProgress!(0.3, 'Downloading the new version…');
        await tester.pump();
        final checksBefore = server.checks;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SizedBox()),
          ),
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: UpdateScreen()),
          ),
        );
        await tester.pump();

        expect(find.text('Downloading the new version… 30%'), findsOneWidget);
        expect(server.checks, checksBefore);
        expect(browser.calls, 1);
      },
    );

    testWidgets('a failed update says why and offers Try again', (
      tester,
    ) async {
      await openScreen(tester);
      await tapDownload(tester);
      browser.done.complete(
        'The download stopped. Check your internet connection and try again.',
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'The download stopped. Check your internet connection and try again. Your shop data is safe.',
        ),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
      await tester.pump();
      expect(browser.calls, 2);
      expect(find.widgetWithText(FilledButton, 'Updating…'), findsOneWidget);
    });
  });
}
