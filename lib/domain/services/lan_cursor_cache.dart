import 'dart:async';

/// Keeps the answer to "what revisions does this device hold" between
/// announcements. Working it out reads every synced table, which is fine once
/// but not every 2 seconds; the answer only changes when the database is
/// written to, so it is kept until then.
///
/// Two things end a kept answer: the database's own change stream (see
/// [attach]), and age. The age limit is a backstop, not the mechanism: if some
/// write ever slipped past the change stream, the answer would otherwise stay
/// behind indefinitely and peers would not be told about the newest changes.
class LanCursorCache {
  LanCursorCache(
    this._compute, {
    this.maxAge = const Duration(seconds: 10),
    Duration Function()? elapsed,
  }) : _elapsed = elapsed ?? _stopwatchClock();

  final Future<Map<String, int>> Function() _compute;
  final Duration maxAge;
  final Duration Function() _elapsed;

  Map<String, int>? _value;
  Duration _computedAt = Duration.zero;
  int _version = 0;
  StreamSubscription<Object?>? _subscription;

  static Duration Function() _stopwatchClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  /// Forget the kept answer whenever [updates] fires (the database's own change
  /// stream).
  void attach(Stream<Object?> updates) {
    _subscription?.cancel();
    _subscription = updates.listen((_) => invalidate());
  }

  void invalidate() {
    _version++;
    _value = null;
  }

  Future<Map<String, int>> get() async {
    final kept = _value;
    if (kept != null && _elapsed() - _computedAt < maxAge) return kept;
    final startedAt = _version;
    final fresh = await _compute();
    // A write that landed while this was being worked out makes it stale before
    // it is even used: hand it to the caller (it is at worst a moment behind,
    // which the exchange tolerates) but do not keep it.
    if (startedAt == _version) {
      _value = fresh;
      _computedAt = _elapsed();
    }
    return fresh;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
