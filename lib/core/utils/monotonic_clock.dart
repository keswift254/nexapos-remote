import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Time that only ever moves forward, and that nobody can change from the
/// device's date-and-time settings: how long this app process has been
/// running. Not a date - it starts from zero every time the app starts - so it
/// can only answer "how much time passed since I last looked", which is
/// exactly what a countdown needs (see LeaseCountdown).
abstract class MonotonicClock {
  Duration elapsed();
}

class SystemMonotonicClock implements MonotonicClock {
  SystemMonotonicClock() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  Duration elapsed() => _stopwatch.elapsed;
}

/// One per app (the stopwatch must not restart while the app runs).
final monotonicClockProvider = Provider<MonotonicClock>(
  (ref) => SystemMonotonicClock(),
);
