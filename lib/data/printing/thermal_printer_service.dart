import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import 'thermal_receipt_builder.dart';
import '../../features/checkout/receipt_screen.dart' show ReceiptData;

part 'thermal_printer_service.g.dart';

const _printerIpKey = 'nexapos.printer.networkIp';

/// Which physical printer to use for "Print Receipt" is inherently a
/// per-device/per-counter fact (a shop with 3 tills has 3 different
/// printers), never a shop-wide fact - so this lives in the same
/// device-local secure storage as the sync/Paystack baseUrl and api_key,
/// never in the synced business_settings table.
@Riverpod(keepAlive: true)
ThermalPrinterService thermalPrinterService(Ref ref) {
  return ThermalPrinterService(ref.watch(secureStorageProvider));
}

class ThermalPrinterService {
  final FlutterSecureStorage _storage;

  ThermalPrinterService(this._storage);

  Future<String> loadIpAddress() async => (await _storage.read(key: _printerIpKey))?.trim() ?? '';

  Future<void> saveIpAddress(String ip) async {
    await _storage.write(key: _printerIpKey, value: ip.trim());
  }

  /// Raw ESC/POS over TCP port 9100 - the de facto standard "just send
  /// bytes" port nearly every network/WiFi thermal printer listens on,
  /// needing nothing beyond a plain socket (no driver, no vendor SDK).
  Future<void> printReceipt(ReceiptData data) async {
    await _send(await buildThermalReceipt(data));
  }

  Future<void> printTestPage(int paperWidthMm) async {
    await _send(await buildTestTicket(paperWidthMm));
  }

  Future<void> _send(Uint8List bytes) async {
    final ip = await loadIpAddress();
    if (ip.isEmpty) {
      throw const ThermalPrinterException('No printer configured. Set the printer\'s IP address first.');
    }
    Socket socket;
    try {
      // Socket.connect's own `timeout:` parameter turned out not to bound
      // a connect attempt to an address with nothing listening on this
      // machine - it took 20+ seconds to surface an error, presumably
      // Windows' own TCP retry/backoff running underneath before Dart
      // ever gets a chance to time it out from the inside. Wrapping the
      // whole future in .timeout() enforces the cutoff from the outside
      // instead, regardless of what the OS socket layer is still doing.
      socket = await Socket.connect(ip, 9100).timeout(const Duration(seconds: 4));
    } on TimeoutException {
      throw ThermalPrinterException('Timed out connecting to the printer at $ip. Check it\'s powered on and on the same network.');
    } on SocketException {
      throw ThermalPrinterException('Could not reach the printer at $ip. Check it\'s powered on and on the same network.');
    }
    try {
      socket.add(bytes);
      await socket.flush();
    } finally {
      await socket.close();
    }
  }
}

class ThermalPrinterException implements Exception {
  final String message;
  const ThermalPrinterException(this.message);
  @override
  String toString() => message;
}
