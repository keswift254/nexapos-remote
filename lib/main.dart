import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

/// Without this, an exception thrown outside Flutter's own build/layout
/// zone - e.g. inside a Timer.periodic callback, such as the Paystack
/// waiting screen's polling timer - has nowhere to go and can take the
/// whole process down on desktop instead of just failing that one tick.
void main() {
  runZonedGuarded(() {
    FlutterError.onError = FlutterError.presentError;
    runApp(const ProviderScope(child: NexaPosApp()));
  }, (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
  });
}
