import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/checkout_return_bridge.dart';
import 'core/secure_storage_guard.dart';
import 'core/tls_trusted_roots.dart';
import 'data/local/database_startup_check.dart';
import 'features/recovery/database_recovery_app.dart';

/// Without this, an exception thrown outside Flutter's own build/layout
/// zone - e.g. inside a Timer.periodic callback, such as the Paystack
/// waiting screen's polling timer - has nowhere to go and can take the
/// whole process down on desktop instead of just failing that one tick.
void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = FlutterError.presentError;
      // Before any connection: trust the Let's Encrypt roots even on a PC (an old
      // Windows 7 one, typically) whose own certificate store lacks them.
      installExtraTrustedRoots();
      // Before anything reads a secret: keeps a second copy of the Windows
      // secure-storage file so one bad read cannot lose the database key.
      await installSecureStorageGuard();
      await CheckoutReturnBridge.initialize();
      void startApp() => runApp(const ProviderScope(child: NexaPosApp()));
      // An encrypted database whose key is gone must never be silently
      // replaced - let a person decide instead of minting a new key.
      final problem = await checkDatabaseStartup();
      if (problem != null) {
        runApp(DatabaseRecoveryApp(problem: problem, onFinished: startApp));
        return;
      }
      startApp();
    },
    (error, stack) {
      debugPrint('Uncaught error: $error\n$stack');
    },
  );
}
