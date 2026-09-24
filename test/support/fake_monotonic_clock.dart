import 'package:nexapos_mobile/core/utils/monotonic_clock.dart';

/// A stopwatch the test moves by hand. Together with a FixedClock this lets a
/// test say exactly what really happened: time passing moves both, a change to
/// the device's date moves only the FixedClock.
class FakeMonotonicClock implements MonotonicClock {
  Duration _elapsed = Duration.zero;

  @override
  Duration elapsed() => _elapsed;

  void advance(Duration duration) => _elapsed += duration;
}
