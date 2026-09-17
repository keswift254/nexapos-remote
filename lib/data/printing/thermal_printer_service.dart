import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:win32/win32.dart';
import '../../core/secure_storage_provider.dart';
import 'thermal_receipt_builder.dart';
import '../../features/checkout/receipt_screen.dart' show ReceiptData;

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
  List<String> listWindowsPrinters() {
    if (!Platform.isWindows) return const [];
    const flags = PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS;
    const level = 4;
    final neededBytes = calloc<Uint32>();
    final returned = calloc<Uint32>();
    try {
      // First call with no buffer just asks how many bytes the real
      // call below will need - the standard two-call Win32 enumeration
      // pattern (the printer list's size isn't known ahead of time).
      EnumPrinters(flags, null, level, nullptr, 0, neededBytes, returned);
      final bufferSize = neededBytes.value;
      if (bufferSize == 0) return const [];
      final buffer = calloc<Uint8>(bufferSize);
      try {
        final result = EnumPrinters(
          flags,
          null,
          level,
          buffer,
          bufferSize,
          neededBytes,
          returned,
        );
        if (!result.value) return const [];
        final names = <String>[];
        final array = buffer.cast<PRINTER_INFO_4>();
        for (var i = 0; i < returned.value; i++) {
          final info = (array + i).ref;
          final name = info.pPrinterName.toDartString().trim();
          if (name.isNotEmpty) names.add(name);
        }
        return names;
      } finally {
        calloc.free(buffer);
      }
    } catch (_) {
      // Best-effort enumeration only - a spooler service that's
      // stopped/misbehaving shouldn't crash the settings screen, just
      // leave the picker empty (the admin can still type a name that
      // isn't listed, e.g. one on a different session's spooler view).
      return const [];
    } finally {
      calloc.free(neededBytes);
      calloc.free(returned);
    }
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
  /// the print spooler's RAW passthrough datatype - the standard way to
  /// hand a printer driver already-formatted bytes (here, ESC/POS
  /// commands) instead of asking Windows' own GDI printing pipeline to
  /// interpret them as a document. This is the same mechanism a USB
  /// thermal printer with a Windows driver installed already accepts
  /// print jobs through; the spooler, not this app, is what actually
  /// knows how to reach the physical device (USB, a redirected port,
  /// etc.), exactly like any other Windows application printing to it.
  Future<void> _sendViaWindowsSpooler(String printerName, Uint8List bytes) async {
    if (!Platform.isWindows) {
      throw const ThermalPrinterException(
        'USB printing is only available on Windows.',
      );
    }
    final printerNamePtr = printerName.toNativeUtf16();
    // OpenPrinter's out-parameter is a plain Pointer<Pointer> - the
    // PRINTER_HANDLE every other spooler call below actually wants is a
    // separate extension type over Pointer (see structs.g.dart), not
    // something OpenPrinter fills in directly, so the raw pointer read
    // back here needs wrapping before being passed on.
    final handlePtr = calloc<Pointer>();
    try {
      final opened = OpenPrinter(PCWSTR(printerNamePtr), handlePtr, null);
      if (!opened.value) {
        throw ThermalPrinterException(
          'Could not open the printer "$printerName" - check it\'s still connected and its name in General Settings.',
        );
      }
      final handle = PRINTER_HANDLE(handlePtr.value);
      try {
        final docNamePtr = 'NexaPOS receipt'.toNativeUtf16();
        final dataTypePtr = 'RAW'.toNativeUtf16();
        final docInfo = calloc<DOC_INFO_1>();
        try {
          docInfo.ref
            ..pDocName = PWSTR(docNamePtr)
            ..pOutputFile = PWSTR(nullptr)
            ..pDatatype = PWSTR(dataTypePtr);
          final job = StartDocPrinter(handle, 1, docInfo);
          if (job == 0) {
            throw ThermalPrinterException(
              'Could not start a print job on "$printerName".',
            );
          }
          try {
            if (!StartPagePrinter(handle)) {
              throw ThermalPrinterException(
                'Could not start printing on "$printerName".',
              );
            }
            try {
              final buffer = calloc<Uint8>(bytes.length);
              final writtenPtr = calloc<Uint32>();
              try {
                buffer.asTypedList(bytes.length).setAll(0, bytes);
                final wrote = WritePrinter(handle, buffer.cast<Void>(), bytes.length, writtenPtr);
                if (!wrote || writtenPtr.value != bytes.length) {
                  throw ThermalPrinterException(
                    'The printer "$printerName" did not accept the full receipt.',
                  );
                }
              } finally {
                calloc.free(buffer);
                calloc.free(writtenPtr);
              }
            } finally {
              EndPagePrinter(handle);
            }
          } finally {
            EndDocPrinter(handle);
          }
        } finally {
          calloc.free(docInfo);
          calloc.free(docNamePtr);
          calloc.free(dataTypePtr);
        }
      } finally {
        ClosePrinter(handle);
      }
    } finally {
      calloc.free(printerNamePtr);
      calloc.free(handlePtr);
    }
  }
}

class ThermalPrinterException implements Exception {
  final String message;
  const ThermalPrinterException(this.message);
  @override
  String toString() => message;
}
