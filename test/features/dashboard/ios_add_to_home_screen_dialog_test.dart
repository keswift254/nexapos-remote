import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/home_screen_install_state.dart';
import 'package:nexapos_mobile/features/dashboard/ios_add_to_home_screen_dialog.dart';

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const IosAddToHomeScreenDialog(),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'tells an iPhone user to switch "Open as Web App" off to keep the shop',
    (tester) async {
      await _open(tester);

      expect(find.byKey(const Key('ios-add-to-home-dialog')), findsOneWidget);
      expect(find.textContaining('"Add to Home Screen"'), findsOneWidget);
      expect(find.textContaining('"Open as Web App"'), findsWidgets);
      expect(find.textContaining('switch it OFF'), findsOneWidget);
      expect(
        find.textContaining('with this shop and all its data'),
        findsOneWidget,
      );
    },
  );

  testWidgets('and what to do if it was left on: join with an invite code', (
    tester,
  ) async {
    await _open(tester);

    expect(find.textContaining('separate copy of NexaPOS'), findsOneWidget);
    expect(find.textContaining('"Join an existing shop"'), findsOneWidget);
    expect(
      find.textContaining('Settings > Sync & Invites > Invite a device'),
      findsOneWidget,
    );
  });

  testWidgets('Got it closes it', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ios-add-to-home-dialog')), findsNothing);
  });

  group('HomeScreenInstallState.isIosHomeScreenApp', () {
    test('is off unless something turns it on', () {
      expect(const HomeScreenInstallState().isIosHomeScreenApp, isFalse);
      expect(
        const HomeScreenInstallState(
          isStandalone: false,
          isIosSafari: true,
        ).isIosHomeScreenApp,
        isFalse,
      );
    });

    test('survives copyWith, and can be changed by it', () {
      const on = HomeScreenInstallState(isIosHomeScreenApp: true);
      expect(on.copyWith(isDismissed: true).isIosHomeScreenApp, isTrue);
      expect(
        on.copyWith(isIosHomeScreenApp: false).isIosHomeScreenApp,
        isFalse,
      );
    });

    test('a Home Screen copy is never offered "add to home screen" again', () {
      const state = HomeScreenInstallState(
        isIosHomeScreenApp: true,
        isIosSafari: true,
      );
      expect(state.shouldOffer, isFalse);
    });
  });
}
