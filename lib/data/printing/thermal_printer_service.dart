import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/secure_storage_provider.dart';
import 'thermal_printer_exception.dart';
import 'thermal_receipt_builder.dart';
import 'windows_print_spooler_native.dart'
    if (dart.library.js_interop) 'windows_print_spooler_stub.dart'
    as spooler;
import '../../features/checkout/receipt_screen.dart' show ReceiptData;

export 'thermal_printer_exception.dart' show ThermalPrinterException;

part 'thermal_printer_service.g.dart';

const _printerIpKey = 'nexapos.printer.networkIp';
const _connectionTypeKey = 'nexapos.printer.connectionType';
const _windowsPrinterNameKey = 'nexapos.printer.windowsPrinterName';

/// A network printer (existing) needs an IP address on the same LAN; a
/// Windows-connected printer (USB, or anything else with a driver
/// already installed in Windows) needs only its printer name - Windows'
/// own print spooler is what actually knows how to reach it, the same
/// way any other Windows app prints to it.
enum PrinterConnectionType {
  network,
  windowsUsb;

  static PrinterConnectionType fromStored(String? raw) =>
      raw == 'windowsUsb' ? PrinterConnectionType.windowsUsb : PrinterConnectionType.network;
}

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

  Future<PrinterConnectionType> loadConnectionType() async =>
      PrinterConnectionType.fromStored(await _storage.read(key: _connectionTypeKey));

  Future<void> saveConnectionType(PrinterConnectionType type) async {
    await _storage.write(key: _connectionTypeKey, value: type.name);
  }

  Future<String> loadWindowsPrinterName() async =>
      (await _storage.read(key: _windowsPrinterNameKey))?.trim() ?? '';

  Future<void> saveWindowsPrinterName(String name) async {
    await _storage.write(key: _windowsPrinterNameKey, value: name.trim());
  }

  /// Every printer Windows currently knows about (installed locally,
  /// which is how a USB thermal printer with a driver shows up, plus
  /// anything connected/redirected) - the raw material for a dropdown
  /// in General Settings. Empty (never throws) on any non-Windows
  /// platform or if the spooler call itself fails, since this is only
  /// ever used to populate a picker, not to gate whether printing works.
  List<String> listWindowsPrinters() => spooler.listWindowsPrinters();

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
    final type = await loadConnectionType();
    if (type == PrinterConnectionType.windowsUsb) {
      final printerName = await loadWindowsPrinterName();
      if (printerName.isEmpty) {
        throw const ThermalPrinterException(
          'Thermal printer not configured. Choose a printer in General Settings first.',
        );
      }
      await _sendViaWindowsSpooler(printerName, bytes);
      return;
    }
    final ip = await loadIpAddress();
    if (ip.isEmpty) {
      throw const ThermalPrinterException(
        'Thermal printer not configured. Set the printer\'s IP address first.',
      );
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

  /// Sends [bytes] straight through to a Windows-installed printer via
  /// the print spooler's RAW passthrough datatype - see
  /// windows_print_spooler_native.dart's doc for why this delegates
  /// through a conditional import instead of calling win32 directly.
  Future<void> _sendViaWindowsSpooler(String printerName, Uint8List bytes) =>
      spooler.sendViaWindowsSpooler(printerName, bytes);
}
