import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'thermal_printer_exception.dart';

/// Split out of thermal_printer_service.dart - the only part of that file
/// that touched win32/ffi (hence dart:ffi), which dart2js refuses to
/// compile at all (win32's own transitive dependencies use `external`
/// FFI bindings the web compiler rejects outright). Selected via a
/// conditional import keyed on dart.library.js_interop in
/// thermal_printer_service.dart, the same split update_service.dart
/// already uses for its own Windows-only installer-launch code; only
/// ever actually called when Platform.isWindows is true, so the web
/// stub's empty/error behavior is unreachable in practice.
///
/// Every printer Windows currently knows about (installed locally, which
/// is how a USB thermal printer with a driver shows up, plus anything
/// connected/redirected) - the raw material for a dropdown in General
/// Settings. Empty (never throws) on any non-Windows platform or if the
/// spooler call itself fails, since this is only ever used to populate a
/// picker, not to gate whether printing works.
List<String> listWindowsPrinters() {
  if (!Platform.isWindows) return const [];
  const flags = PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS;
  const level = 4;
  final neededBytes = calloc<Uint32>();
  final returned = calloc<Uint32>();
  try {
    // First call with no buffer just asks how many bytes the real call
    // below will need - the standard two-call Win32 enumeration pattern
    // (the printer list's size isn't known ahead of time).
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

/// Sends [bytes] straight through to a Windows-installed printer via the
/// print spooler's RAW passthrough datatype - the standard way to hand a
/// printer driver already-formatted bytes (here, ESC/POS commands)
/// instead of asking Windows' own GDI printing pipeline to interpret
/// them as a document. This is the same mechanism a USB thermal printer
/// with a Windows driver installed already accepts print jobs through;
/// the spooler, not this app, is what actually knows how to reach the
/// physical device (USB, a redirected port, etc.), exactly like any
/// other Windows application printing to it.
Future<void> sendViaWindowsSpooler(String printerName, Uint8List bytes) async {
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
              final wrote = WritePrinter(
                handle,
                buffer.cast<Void>(),
                bytes.length,
                writtenPtr,
              );
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
