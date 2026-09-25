import 'dart:async';
import 'dart:io' show InternetAddress, InternetAddressType;

/// Sends a LAN announcement soon after something changed on this device, instead
/// of waiting for the next tick of the 2-second heartbeat.
///
/// The heartbeat alone means a sale made just after a tick sits for up to 2
/// seconds before the other tills even hear about it. Announcing on the change
/// itself makes that a fraction of a second. A burst of writes (a sale writes
/// several tables) becomes one announcement after [delay], and a change that
/// happens WHILE an announcement is being built - which may already have missed
/// it - schedules one more, so the newest state is always announced.
class LanAnnounceScheduler {
  LanAnnounceScheduler(
    this._announce, {
    this.delay = const Duration(milliseconds: 120),
  });

  final Future<void> Function() _announce;
  final Duration delay;

  Timer? _timer;
  bool _running = false;
  bool _again = false;
  bool _disposed = false;

  /// Something worth announcing changed.
  void changed() {
    if (_disposed) return;
    if (_running) {
      _again = true;
      return;
    }
    _timer?.cancel();
    _timer = Timer(delay, _run);
  }

  Future<void> _run() async {
    if (_disposed) return;
    _running = true;
    try {
      do {
        _again = false;
        try {
          await _announce();
        } catch (_) {
          // A missed announcement is made up for by the heartbeat.
        }
      } while (_again && !_disposed);
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}

/// Where to send a LAN announcement so it reaches the other devices on EVERY
/// network this one is attached to. The "limited" broadcast address
/// (255.255.255.255) leaves through only one network adapter - on a PC with
/// several (Ethernet plus Wi-Fi, a VPN, a virtual switch) that may not be the
/// shop's network at all. Each adapter's own broadcast address (assuming the usual
/// /24 of a shop router) is added, so the packet goes out where the till is
/// actually connected. The limited broadcast stays as well, for bigger subnets.
List<InternetAddress> lanBroadcastTargets(Iterable<InternetAddress> localAddresses) {
  final targets = <String, InternetAddress>{};
  for (final address in localAddresses) {
    if (address.type != InternetAddressType.IPv4) continue;
    final octets = address.rawAddress;
    if (octets.length != 4 || !_isPrivateOrLinkLocal(octets)) continue;
    final broadcast = '${octets[0]}.${octets[1]}.${octets[2]}.255';
    if (broadcast == address.address) continue; // this host IS .255; nothing sensible to add
    targets[broadcast] = InternetAddress(broadcast);
  }
  targets['255.255.255.255'] = InternetAddress('255.255.255.255');
  return targets.values.toList();
}

bool _isPrivateOrLinkLocal(List<int> o) {
  if (o[0] == 10) return true;
  if (o[0] == 172 && o[1] >= 16 && o[1] <= 31) return true;
  if (o[0] == 192 && o[1] == 168) return true;
  return false;
}
