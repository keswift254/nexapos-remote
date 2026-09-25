/// Decides whether a LAN announcement from another device is worth a pull.
///
/// Devices on a shop's network announce themselves every couple of seconds so a
/// sale made on one till reaches the others almost at once. If every
/// announcement made every peer open a connection and ask for changes, a shop
/// with a handful of devices would spend most of its time answering "nothing
/// new". So an announcement carries a small summary of what its sender holds (the
/// highest revision it has for each source device - the same numbers a pull is
/// asked with), and a peer only pulls when that summary is ahead of its own.
///
/// Three rules keep this safe:
///  * an announcement with no summary (an older version of the app) is always
///    pulled, exactly as before;
///  * the same summary that was already pulled against is not pulled again -
///    otherwise a summary that runs ahead of what can actually be exported
///    (revisions kept only as receipts) would cause a pull every 2 seconds
///    forever;
///  * every peer is pulled at least every [safetyInterval] regardless, which
///    also carries the things that ride along with a pull (the shop's license
///    time) and picks up anything a failed exchange left behind.
class LanPullPolicy {
  LanPullPolicy({this.safetyInterval = const Duration(seconds: 30)});

  final Duration safetyInterval;

  final Map<String, Map<String, int>> _lastAnnounced = {};
  final Map<String, Duration> _lastPulledAt = {};

  /// [peer] is the announcing device's id, [announced] its summary (null when
  /// it sent none), [mine] this device's own summary, [now] a monotonic time
  /// (see MonotonicClock) - a wall clock that gets changed must not be able to
  /// stop the safety pulls.
  bool shouldPull({
    required String peer,
    required Map<String, int>? announced,
    required Map<String, int> mine,
    required Duration now,
  }) {
    if (announced == null) return true;
    final last = _lastPulledAt[peer];
    if (last == null || now - last >= safetyInterval) return true;
    final ahead = announced.entries.any((e) => e.value > (mine[e.key] ?? 0));
    return ahead && !_sameSummary(announced, _lastAnnounced[peer]);
  }

  /// Call after a pull from [peer] went through. A failed pull is NOT recorded,
  /// so the next announcement tries again.
  void pulled({
    required String peer,
    required Map<String, int>? announced,
    required Duration now,
  }) {
    _lastPulledAt[peer] = now;
    if (announced != null) _lastAnnounced[peer] = Map.of(announced);
  }

  static bool _sameSummary(Map<String, int> a, Map<String, int>? b) {
    if (b == null || a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
