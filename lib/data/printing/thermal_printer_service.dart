import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/secure_storage_provider.dart';
import '../../domain/entities/business_settings.dart';
import '../../domain/services/reports_service.dart';
import 'thermal_printer_exception.dart';
import 'thermal_receipt_builder.dart';
import 'thermal_report_builder.dart';
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

  static PrinterConnectionType fromStored(String? raw) => raw == 'windowsUsb'
      ? PrinterConnectionType.windowsUsb
      : PrinterConnectionType.network;
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

  Future<String> loadIpAddress() async =>
      (await _storage.read(key: _printerIpKey))?.trim() ?? '';

  Future<void> saveIpAddress(String ip) async {
    await _storage.write(key: _printerIpKey, value: ip.trim());
  }

  Future<PrinterConnectionType> loadConnectionType() async =>
      PrinterConnectionType.fromStored(
        await _storage.read(key: _connectionTypeKey),
      );

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

  /// Searches only this device's private IPv4 /24 LAN(s) for printers that
  /// accept raw ESC/POS on TCP 9100. A printer shared from another Windows PC
  /// is not a raw-IP printer; it appears in [listWindowsPrinters] after the
  /// Windows share is connected on this PC.
  Future<List<String>> discoverNetworkPrinters() async {
    if (kIsWeb) return const [];
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    ).timeout(const Duration(seconds: 3));
    final prefixes = <String>{};
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        final parts = address.address.split('.');
        if (parts.length != 4) continue;
        final octets = parts.map(int.tryParse).toList();
        if (octets.any((part) => part == null || part < 0 || part > 255)) {
          continue;
        }
        final first = octets[0]!;
        final second = octets[1]!;
        final isPrivate =
            first == 10 ||
            (first == 172 && second >= 16 && second <= 31) ||
            (first == 192 && second == 168);
        if (isPrivate) prefixes.add('${parts[0]}.${parts[1]}.${parts[2]}');
        if (prefixes.length >= 2) break;
      }
      if (prefixes.length >= 2) break;
    }
    final found = <String>{};
    final targets = [
      for (final prefix in prefixes)
        for (var n = 1; n < 255; n++) '$prefix.$n',
    ];
    // Bounded parallelism prevents a slow printer or unreachable host from
    // holding up the settings screen or flooding a small shop network.
    for (var offset = 0; offset < targets.length; offset += 16) {
      final batch = targets.skip(offset).take(16);
      await Future.wait(
        batch.map((ip) async {
          final pending = Socket.connect(ip, 9100);
          // Socket.connect itself may finish after our deadline on Windows.
          // Release any late socket instead of leaving a connection behind.
          unawaited(
            pending.then((socket) => socket.destroy(), onError: (Object _) {}),
          );
          try {
            await pending.timeout(const Duration(milliseconds: 450));
            found.add(ip);
          } catch (_) {}
        }),
      );
    }
    return found.toList()..sort();
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

  Future<void> printReport({
    required ReportData data,
    required String reportTitle,
    required String periodLabel,
    required bool isMonthlyReport,
    required DateFormat timeFormat,
    required BusinessSettings settings,
    required String generatedByName,
  }) async {
    await _send(
      await buildThermalReport(
        data: data,
        reportTitle: reportTitle,
        periodLabel: periodLabel,
        isMonthlyReport: isMonthlyReport,
        timeFormat: timeFormat,
        settings: settings,
        generatedByName: generatedByName,
      ),
    );
  }

  Future<void> _send(Uint8List bytes) async {
    final type = await loadConnectionType();
    if (type == PrinterConnectionType.windowsUsb) {
      final printerName = await loadWindowsPrinterName();
      if (printerName.isEmpty) {
        throw const ThermalPrinterException(
          'Thermal printer not configured. Choose a printer in Business, Receipts & Themes first.',
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
      socket = await Socket.connect(
        ip,
        9100,
      ).timeout(const Duration(seconds: 4));
    } on TimeoutException {
      throw ThermalPrinterException(
        'Timed out connecting to the printer at $ip. Check it\'s powered on and on the same network.',
      );
    } on SocketException {
      throw ThermalPrinterException(
        'Could not reach the printer at $ip. Check it\'s powered on and on the same network.',
      );
    }
    try {
      socket.setOption(SocketOption.tcpNoDelay, true);
      socket.add(bytes);
      await socket.flush().timeout(const Duration(seconds: 8));
      try {
        await socket.close().timeout(const Duration(seconds: 3));
      } on TimeoutException {
        // The whole job was handed to the socket; do not retry automatically
        // because a second copy may already be printing.
      }
    } on TimeoutException {
      throw ThermalPrinterException(
        'Timed out sending the print job to $ip. Check for a partial print before trying again.',
      );
    } on SocketException {
      throw ThermalPrinterException(
        'Connection to the printer at $ip was interrupted.',
      );
    } finally {
      // close() is bounded above; release a stalled socket afterward.
      socket.destroy();
    }
  }

  /// Sends [bytes] straight through to a Windows-installed printer via
  /// the print spooler's RAW passthrough datatype - see
  /// windows_print_spooler_native.dart's doc for why this delegates
  /// through a conditional import instead of calling win32 directly.
  Future<void> _sendViaWindowsSpooler(String printerName, Uint8List bytes) =>
      spooler.sendViaWindowsSpooler(printerName, bytes);
}
