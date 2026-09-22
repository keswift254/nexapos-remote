import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/secure_storage_provider.dart';
import '../../data/payments/platform_onboarding_gateway.dart';
import 'lan_sync_service.dart';
import 'paystack_credentials_service.dart';
import 'sync_service.dart';

const _discoveryPort = 47824;
const _credentialStorageKey = 'nexapos.lanSync.credentials.v1';
const _protocolAad = 'nexapos-lan-sync-v1';

class _Credentials {
  final int shopId;
  final String deviceId;
  final List<int> secret;

  const _Credentials(this.shopId, this.deviceId, this.secret);
}

LanSyncService createLanSyncService(Ref ref) => NativeLanSyncService(ref);

class NativeLanSyncService implements LanSyncService {
  final Ref _ref;
  final Cipher _cipher = AesGcm.with256bits();
  RawDatagramSocket? _udp;
  ServerSocket? _server;
  StreamSubscription<RawSocketEvent>? _udpSubscription;
  StreamSubscription<Socket>? _serverSubscription;
  _Credentials? _credentials;
  DateTime? _lastCredentialRefresh;
  Future<void>? _inFlight;
  final Set<String> _connecting = {};
  final Set<String> _seenNonces = {};

  NativeLanSyncService(this._ref);

  @override
  Future<void> syncNow() =>
      _inFlight ??= _syncNow().whenComplete(() => _inFlight = null);

  Future<void> _syncNow() async {
    final credentials = await _loadCredentials();
    if (credentials == null) return;
    await _ensureListening();
    final server = _server;
    final udp = _udp;
    if (server == null || udp == null) return;
    final announcement = await _encrypt({
      'type': 'announce',
      'sender': credentials.deviceId,
      'port': server.port,
      'timestamp': DateTime.now().toUtc().millisecondsSinceEpoch,
    }, credentials);
    udp.send(
      utf8.encode(jsonEncode(announcement)),
      InternetAddress('255.255.255.255'),
      _discoveryPort,
    );
  }

  Future<_Credentials?> _loadCredentials() async {
    final now = DateTime.now();
    if (_credentials == null) {
      final raw = await _ref
          .read(secureStorageProvider)
          .read(key: _credentialStorageKey);
      if (raw != null) {
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          final secret = base64Decode(json['secret'] as String);
          if (secret.length == 32) {
            _credentials = _Credentials(
              json['shopId'] as int,
              json['deviceId'] as String,
              secret,
            );
          }
        } catch (_) {}
      }
    }

    if (_lastCredentialRefresh == null ||
        now.difference(_lastCredentialRefresh!) >= const Duration(minutes: 2)) {
      _lastCredentialRefresh = now;
      try {
        final platform = await _ref
            .read(paystackCredentialsServiceProvider)
            .load();
        if (platform.isConfigured) {
          final fresh = await _ref
              .read(platformOnboardingGatewayProvider)
              .getLanSyncCredentials(
                baseUrl: platform.baseUrl,
                apiKey: platform.apiKey,
              );
          final secret = base64Decode(fresh.secret);
          if (fresh.shopId > 0 &&
              fresh.deviceId.isNotEmpty &&
              secret.length == 32) {
            _credentials = _Credentials(fresh.shopId, fresh.deviceId, secret);
            await _ref
                .read(secureStorageProvider)
                .write(
                  key: _credentialStorageKey,
                  value: jsonEncode({
                    'shopId': fresh.shopId,
                    'deviceId': fresh.deviceId,
                    'secret': fresh.secret,
                  }),
                );
          }
        }
      } catch (_) {
        // Offline is the exact case LAN sync exists for; retain the last
        // server-issued key already protected by OS secure storage.
      }
    }
    return _credentials;
  }

  Future<void> _ensureListening() async {
    if (_server == null) {
      _server = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        0,
        shared: true,
      );
      _serverSubscription = _server!.listen(_handleConnection);
    }
    if (_udp == null) {
      try {
        _udp = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          _discoveryPort,
          reuseAddress: true,
        );
        _udp!.broadcastEnabled = true;
        _udpSubscription = _udp!.listen(_handleDatagramEvent);
      } catch (_) {
        // A blocked UDP listener must not affect cloud sync or checkout.
        _udp?.close();
        _udp = null;
      }
    }
  }

  void _handleDatagramEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _udp == null) return;
    Datagram? datagram;
    while ((datagram = _udp!.receive()) != null) {
      final current = datagram!;
      unawaited(_handleAnnouncement(current));
    }
  }

  Future<void> _handleAnnouncement(Datagram datagram) async {
    final credentials = _credentials;
    if (credentials == null) return;
    try {
      final envelope =
          jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
      final message = await _decrypt(envelope, credentials);
      if (message['type'] != 'announce' || !_fresh(message['timestamp'])) {
        return;
      }
      final sender = message['sender'] as String? ?? '';
      final port = (message['port'] as num? ?? 0).toInt();
      if (sender.isEmpty ||
          sender == credentials.deviceId ||
          port < 1 ||
          port > 65535) {
        return;
      }
      final peer = '${datagram.address.address}:$port:$sender';
      if (!_connecting.add(peer)) return;
      try {
        await _pullFromPeer(datagram.address, port, sender, credentials);
      } finally {
        _connecting.remove(peer);
      }
    } catch (_) {}
  }

  Future<void> _pullFromPeer(
    InternetAddress address,
    int port,
    String expectedSender,
    _Credentials credentials,
  ) async {
    final socket = await Socket.connect(
      address,
      port,
      timeout: const Duration(seconds: 3),
    );
    try {
      final request = await _encrypt({
        'type': 'pull',
        'sender': credentials.deviceId,
        'timestamp': DateTime.now().toUtc().millisecondsSinceEpoch,
        'known': await _ref.read(syncServiceProvider).lanRevisionCursors(),
      }, credentials);
      socket.add(utf8.encode('${jsonEncode(request)}\n'));
      await socket.flush();
      final line = await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 8));
      final response = await _decrypt(
        jsonDecode(line) as Map<String, dynamic>,
        credentials,
      );
      if (response['type'] != 'changes' ||
          response['sender'] != expectedSender ||
          !_fresh(response['timestamp'])) {
        return;
      }
      final raw = response['changes'] as List? ?? const [];
      final changes = raw
          .whereType<Map>()
          .map((item) => LanSyncChange.fromJson(item.cast<String, dynamic>()))
          .toList();
      await _ref.read(syncServiceProvider).applyLanChanges(changes);
    } finally {
      await socket.close();
    }
  }

  Future<void> _handleConnection(Socket socket) async {
    final credentials = _credentials;
    if (credentials == null) {
      await socket.close();
      return;
    }
    try {
      final line = await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 8));
      final request = await _decrypt(
        jsonDecode(line) as Map<String, dynamic>,
        credentials,
      );
      if (request['type'] != 'pull' || !_fresh(request['timestamp'])) return;
      final sender = request['sender'] as String? ?? '';
      if (sender.isEmpty || sender == credentials.deviceId) return;
      final knownRaw =
          (request['known'] as Map?)?.cast<String, dynamic>() ?? const {};
      final known = knownRaw.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      );
      final changes = await _ref
          .read(syncServiceProvider)
          .exportLanChanges(known);
      final response = await _encrypt({
        'type': 'changes',
        'sender': credentials.deviceId,
        'timestamp': DateTime.now().toUtc().millisecondsSinceEpoch,
        'changes': changes.map((change) => change.toJson()).toList(),
      }, credentials);
      socket.add(utf8.encode('${jsonEncode(response)}\n'));
      await socket.flush();
    } catch (_) {
      // Malformed, unauthenticated and abruptly-disconnected peers are ignored.
    } finally {
      await socket.close();
    }
  }

  Future<Map<String, dynamic>> _encrypt(
    Map<String, dynamic> payload,
    _Credentials credentials,
  ) async {
    final nonce = _cipher.newNonce();
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: SecretKey(credentials.secret),
      nonce: nonce,
      aad: utf8.encode('$_protocolAad|${credentials.shopId}'),
    );
    return {
      'version': 1,
      'shop': credentials.shopId,
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
  }

  Future<Map<String, dynamic>> _decrypt(
    Map<String, dynamic> envelope,
    _Credentials credentials,
  ) async {
    if (envelope['version'] != 1 || envelope['shop'] != credentials.shopId) {
      throw const FormatException('Wrong LAN sync protocol or shop.');
    }
    final nonceText = envelope['nonce'] as String? ?? '';
    if (nonceText.isEmpty || !_seenNonces.add(nonceText)) {
      throw const FormatException('Replayed LAN message.');
    }
    if (_seenNonces.length > 2048) _seenNonces.remove(_seenNonces.first);
    final clear = await _cipher.decrypt(
      SecretBox(
        base64Decode(envelope['ciphertext'] as String),
        nonce: base64Decode(nonceText),
        mac: Mac(base64Decode(envelope['mac'] as String)),
      ),
      secretKey: SecretKey(credentials.secret),
      aad: utf8.encode('$_protocolAad|${credentials.shopId}'),
    );
    return (jsonDecode(utf8.decode(clear)) as Map).cast<String, dynamic>();
  }

  bool _fresh(Object? value) {
    final millis = (value as num?)?.toInt();
    if (millis == null) return false;
    return DateTime.now()
            .toUtc()
            .difference(
              DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true),
            )
            .abs() <
        const Duration(minutes: 5);
  }

  @override
  Future<void> dispose() async {
    await _udpSubscription?.cancel();
    await _serverSubscription?.cancel();
    _udp?.close();
    await _server?.close();
  }
}
