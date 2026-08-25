import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A shop server (baseUrl + invite code) seen advertising itself on the
/// local network, ready to be joined without typing anything.
class DiscoveredHost {
  final String deviceLabel;
  final String baseUrl;
  final String code;
  final DateTime lastSeen;

  const DiscoveredHost({
    required this.deviceLabel,
    required this.baseUrl,
    required this.code,
    required this.lastSeen,
  });

  DiscoveredHost copyWith({DateTime? lastSeen}) => DiscoveredHost(
        deviceLabel: deviceLabel,
        baseUrl: baseUrl,
        code: code,
        lastSeen: lastSeen ?? this.lastSeen,
      );
}

/// UDP broadcast, not mDNS/Bonjour: `dart:io`'s RawDatagramSocket needs no
/// platform channel or third-party plugin on either Windows or Android, at
/// the cost of only reaching devices on the exact same broadcast domain
/// (which "join a shop's sync" already requires today, via a manually-typed
/// LAN IP - this just automates finding that address). A router with
/// AP/client isolation enabled will block this like it blocks any other
/// device-to-device LAN traffic; there is no fallback for that case beyond
/// the manual-entry path callers should keep offering alongside this.
const _discoveryPort = 47823;
const _protocolTag = 'nexapos_sync_v1';

/// Broadcasts this shop's join details every [_interval] while [start] is
/// running, so any [LanHostScanner] on the same network picks it up within
/// a couple of seconds - stops the moment [stop] is called (invite expiry
/// or the host screen closing), rather than lingering and inviting a join
/// against a code that's already gone.
class LanHostAdvertiser {
  static const _interval = Duration(seconds: 1, milliseconds: 500);

  RawDatagramSocket? _socket;
  Timer? _timer;

  Future<void> start({required String deviceLabel, required String baseUrl, required String code}) async {
    await stop();
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    _socket = socket;
    final payload = utf8.encode(jsonEncode({
      'app': _protocolTag,
      'deviceLabel': deviceLabel,
      'baseUrl': baseUrl,
      'code': code,
    }));
    void send() => socket.send(payload, InternetAddress('255.255.255.255'), _discoveryPort);
    send();
    _timer = Timer.periodic(_interval, (_) => send());
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _socket?.close();
    _socket = null;
  }
}

/// Listens for [LanHostAdvertiser] broadcasts and surfaces currently-live
/// hosts - "currently-live" meaning seen within [_staleAfter], since a host
/// that stopped broadcasting (invite expired, screen closed) should drop
/// out of the list on its own rather than sit there as a dead entry a user
/// could tap into a stale/expired code.
class LanHostScanner {
  static const _staleAfter = Duration(seconds: 5);

  RawDatagramSocket? _socket;
  Timer? _pruneTimer;
  final _hosts = <String, DiscoveredHost>{};
  final _controller = StreamController<List<DiscoveredHost>>.broadcast();

  Stream<List<DiscoveredHost>> get hosts => _controller.stream;

  Future<void> start() async {
    await stop();
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _discoveryPort, reuseAddress: true);
    _socket = socket;
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      _handle(datagram.data);
    });
    _pruneTimer = Timer.periodic(const Duration(seconds: 1), (_) => _prune());
  }

  void _handle(List<int> bytes) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (json['app'] != _protocolTag) return;
    final baseUrl = (json['baseUrl'] as String?)?.trim() ?? '';
    final code = (json['code'] as String?)?.trim() ?? '';
    final deviceLabel = (json['deviceLabel'] as String?)?.trim() ?? '';
    if (baseUrl.isEmpty || code.isEmpty) return;
    _hosts['$baseUrl|$code'] = DiscoveredHost(
      deviceLabel: deviceLabel,
      baseUrl: baseUrl,
      code: code,
      lastSeen: DateTime.now(),
    );
    _emit();
  }

  void _prune() {
    final cutoff = DateTime.now().subtract(_staleAfter);
    final before = _hosts.length;
    _hosts.removeWhere((_, host) => host.lastSeen.isBefore(cutoff));
    if (_hosts.length != before) _emit();
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(_hosts.values.toList(growable: false));
  }

  Future<void> stop() async {
    _pruneTimer?.cancel();
    _pruneTimer = null;
    _socket?.close();
    _socket = null;
    _hosts.clear();
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
