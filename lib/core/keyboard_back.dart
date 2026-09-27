import 'package:go_router/go_router.dart';

/// Pop the top dialog or page, respecting PopScope/unsaved-change guards.
/// At the root, Escape is intentionally a no-op.
Future<void> keyboardBack(GoRouter router) async {
  await router.routerDelegate.navigatorKey.currentState?.maybePop();
}
