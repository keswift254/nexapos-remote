import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nexapos_mobile/core/keyboard_back.dart';

void main() {
  testWidgets('Escape closes the dialog first, then the page, and stays at home', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Home'))),
      GoRoute(path: '/page', builder: (_, _) => const Scaffold(body: Text('Page'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router,
      builder: (_, child) => CallbackShortcuts(bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => keyboardBack(router),
      }, child: child!)));
    await tester.pumpAndSettle();
    router.push('/page');
    await tester.pumpAndSettle();
    showDialog<void>(context: router.routerDelegate.navigatorKey.currentContext!,
      builder: (_) => const AlertDialog(content: Text('Dialog')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Dialog'), findsNothing);
    expect(find.text('Page'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}
