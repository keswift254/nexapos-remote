/// Injected time source so domain services never call [DateTime.now]
/// directly - keeps unit tests deterministic and gives a future sync
/// engine exactly one place to intercept if a server-provided logical
/// clock is ever needed.
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

class FixedClock implements Clock {
  DateTime _current;

  FixedClock(this._current);

  @override
  DateTime now() => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }

  void set(DateTime value) {
    _current = value;
  }
}
