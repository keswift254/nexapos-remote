/// Split out of thermal_printer_service.dart so the Windows-only spooler
/// code (windows_print_spooler_native.dart) can throw this without
/// importing that file back - thermal_printer_service.dart already
/// conditionally imports the spooler code, and a cycle there would defeat
/// the whole point of the split (keeping dart:ffi/win32 out of the web
/// compile graph).
class ThermalPrinterException implements Exception {
  final String message;
  const ThermalPrinterException(this.message);
  @override
  String toString() => message;
}
