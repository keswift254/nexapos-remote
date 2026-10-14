import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/data/local/database_startup_problem.dart';
import 'package:nexapos_mobile/features/recovery/database_recovery_app.dart';

const _missing = DatabaseStartupProblem(DatabaseProblemKind.keyMissing, r'C:\Users\Shop\Documents\nexapos.sqlite');

Future<void> pump(
  WidgetTester tester, {
  DatabaseStartupProblem problem = _missing,
  VoidCallback? onFinished,
  Future<DatabaseStartupProblem?> Function()? recheck,
  Future<String> Function(String)? setAside,
  VoidCallback? exitApp,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    DatabaseRecoveryApp(
      problem: problem,
      onFinished: onFinished ?? () {},
      recheck: recheck ?? () async => problem,
      setAside: setAside ?? (_) async => r'C:\Users\Shop\Documents\NexaPOS-held-20261015-010203',
      exitApp: exitApp ?? () {},
    ),
  );
}

void main() {
  testWidgets('explains the problem and says nothing was deleted', (tester) async {
    await pump(tester);
    expect(find.text("NexaPOS can't open its saved data"), findsOneWidget);
    expect(find.textContaining('has NOT been deleted'), findsOneWidget);
    expect(find.textContaining('cannot read the security key'), findsOneWidget);
  });

  testWidgets('a key that does not open the data gets its own wording', (tester) async {
    await pump(tester, problem: const DatabaseStartupProblem(DatabaseProblemKind.keyDoesNotOpen, 'x'));
    expect(find.textContaining('does not unlock the saved data'), findsOneWidget);
  });

  testWidgets('Try again starts the app when the data opens after all', (tester) async {
    var finished = 0;
    await pump(tester, onFinished: () => finished++, recheck: () async => null);
    await tester.tap(find.byKey(const Key('recovery-try-again')));
    // pump, not pumpAndSettle: the busy spinner animates forever here because
    // real startup replaces this whole screen once onFinished runs.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(finished, 1);
  });

  testWidgets('Try again keeps the screen and says so when it still fails', (tester) async {
    var finished = 0;
    await pump(tester, onFinished: () => finished++);
    await tester.tap(find.byKey(const Key('recovery-try-again')));
    await tester.pumpAndSettle();
    expect(finished, 0);
    expect(find.text('Still cannot open the saved data.'), findsOneWidget);
  });

  testWidgets('Start fresh asks first; cancelling moves nothing', (tester) async {
    final moved = <String>[];
    await pump(tester, setAside: (path) async {
      moved.add(path);
      return 'folder';
    });
    await tester.tap(find.byKey(const Key('recovery-start-fresh')));
    await tester.pumpAndSettle();
    expect(find.text('Start fresh?'), findsOneWidget);
    expect(find.textContaining('not deleted'), findsOneWidget);
    await tester.tap(find.byKey(const Key('recovery-cancel')));
    await tester.pumpAndSettle();
    expect(moved, isEmpty);
    expect(find.byKey(const Key('recovery-start-fresh')), findsOneWidget);
  });

  testWidgets('confirming sets the old data aside, shows where, and Continue starts the app', (tester) async {
    final moved = <String>[];
    var finished = 0;
    await pump(
      tester,
      onFinished: () => finished++,
      setAside: (path) async {
        moved.add(path);
        return r'C:\Users\Shop\Documents\NexaPOS-held-20261015-010203';
      },
    );
    await tester.tap(find.byKey(const Key('recovery-start-fresh')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recovery-confirm')));
    await tester.pumpAndSettle();

    expect(moved, [_missing.databasePath]);
    expect(find.textContaining('NexaPOS-held-20261015-010203'), findsOneWidget);
    expect(finished, 0, reason: 'the person must see where the old data went before continuing');

    await tester.tap(find.byKey(const Key('recovery-continue')));
    await tester.pumpAndSettle();
    expect(finished, 1);
  });

  testWidgets('if moving fails, nothing is claimed and the choices stay available', (tester) async {
    var finished = 0;
    await pump(
      tester,
      onFinished: () => finished++,
      setAside: (_) async => throw const FormatException('disk is read-only'),
    );
    await tester.tap(find.byKey(const Key('recovery-start-fresh')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recovery-confirm')));
    await tester.pumpAndSettle();

    expect(find.textContaining('nothing was changed'), findsOneWidget);
    expect(find.textContaining('disk is read-only'), findsOneWidget);
    expect(find.byKey(const Key('recovery-start-fresh')), findsOneWidget);
    expect(finished, 0);
  });

  testWidgets('Close NexaPOS exits without touching anything', (tester) async {
    var exited = 0;
    final moved = <String>[];
    await pump(tester, exitApp: () => exited++, setAside: (path) async {
      moved.add(path);
      return 'x';
    });
    await tester.tap(find.byKey(const Key('recovery-close')));
    await tester.pump();
    expect(exited, 1);
    expect(moved, isEmpty);
  });
}
