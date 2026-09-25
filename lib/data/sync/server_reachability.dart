import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

/// Whether this device can open a connection to the sync server right now -
/// asked before a cloud sync cycle starts, in a few seconds at most.
///
/// Why it exists: a cloud cycle runs inside SyncService's exclusive queue, and
/// changes arriving over the shop's own network have to wait in that same queue.
/// With no internet (a shop working on its LAN alone) every cycle would sit in
/// the queue for as long as the failing request took to give up, and every sale
/// made on another till would wait behind it. Asking first means a cycle that
/// cannot succeed never enters the queue at all.
///
/// A false "no" costs nothing much (the next cycle asks again a few seconds
/// later); a false "yes" is just what happened before. Anything unexpected
/// answers "yes" and lets the real request decide. Always "yes" in a browser,
/// which cannot open sockets and has its own network handling.
Future<bool> serverReachable(
  String baseUrl, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  if (kIsWeb) return true;
  final uri = Uri.tryParse(baseUrl);
  if (uri == null || uri.host.isEmpty) return true;
  final port = uri.hasPort ? uri.port : (uri.scheme == 'http' ? 80 : 443);
  final connecting = Socket.connect(uri.host, port, timeout: timeout);
  try {
    // The connect's own timeout may not cover a name lookup that hangs.
    final socket = await connecting.timeout(timeout + const Duration(seconds: 1));
    socket.destroy();
    return true;
  } on TimeoutException {
    // Whatever the attempt was still doing, do not leave a socket behind.
    unawaited(connecting.then((socket) => socket.destroy(), onError: (Object _) {}));
    return false;
  } on SocketException {
    return false;
  } catch (_) {
    return true;
  }
}
