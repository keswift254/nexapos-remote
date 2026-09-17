import 'dart:typed_data';

import 'thermal_printer_exception.dart';

/// Selected instead of windows_print_spooler_native.dart when compiling
/// for web - unreachable in practice, since both callers
/// (ThermalPrinterService.listWindowsPrinters/_sendViaWindowsSpooler)
/// only ever take this path when Platform.isWindows is true, which is
/// always false on web.
List<String> listWindowsPrinters() => const [];

Future<void> sendViaWindowsSpooler(String printerName, Uint8List bytes) async {
  throw const ThermalPrinterException(
    'USB printing is only available on Windows.',
  );
}
