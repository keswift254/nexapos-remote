import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Windows DPAPI for the current user, called exactly as flutter_secure_storage_windows calls it (no entropy, no
/// prompt), so NexaPOS can look inside a copy of its secure-storage file: the backup, or a copy set aside as unreadable.
/// Windows only.

/// Unlocks [data] with the signed-in user's DPAPI key. Throws [WindowsException] when Windows cannot.
Uint8List dpapiUnprotect(Uint8List data) => _dpapi(data, protect: false);

/// Locks [data] for the signed-in user (used to build real copies in tests).
Uint8List dpapiProtect(Uint8List data) => _dpapi(data, protect: true);

Uint8List _dpapi(Uint8List data, {required bool protect}) {
  return using((alloc) {
    final input = alloc<Uint8>(data.isEmpty ? 1 : data.length);
    input.asTypedList(data.length).setAll(0, data);
    final inBlob = alloc.allocate<CRYPT_INTEGER_BLOB>(sizeOf<CRYPT_INTEGER_BLOB>());
    inBlob.ref.cbData = data.length;
    inBlob.ref.pbData = input;
    final outBlob = alloc.allocate<CRYPT_INTEGER_BLOB>(sizeOf<CRYPT_INTEGER_BLOB>());
    final Win32Result(value: ok, error: error) = protect
        ? CryptProtectData(inBlob, null, null, null, 0, outBlob)
        : CryptUnprotectData(inBlob, null, null, null, 0, outBlob);
    if (!ok) {
      throw WindowsException(error.toHRESULT(), message: protect ? 'CryptProtectData failed' : 'CryptUnprotectData failed');
    }
    if (outBlob.ref.pbData.address == NULL) {
      throw WindowsException(ERROR_OUTOFMEMORY.toHRESULT(), message: 'DPAPI returned no data');
    }
    try {
      return Uint8List.fromList(outBlob.ref.pbData.asTypedList(outBlob.ref.cbData));
    } finally {
      LocalFree(HLOCAL(outBlob.ref.pbData.cast()));
    }
  });
}

/// The entries of a flutter_secure_storage_windows file (DPAPI around UTF-8 JSON), or null when it cannot be read as
/// one: another Windows user, a torn write, not JSON. Never throws.
Map<String, String>? decodeWindowsSecureStore(Uint8List bytes) {
  try {
    final decoded = jsonDecode(utf8.decode(dpapiUnprotect(bytes)));
    if (decoded is! Map) return null;
    return {
      for (final entry in decoded.entries)
        if (entry.key is String && entry.value is String) entry.key as String: entry.value as String,
    };
  } on Object {
    return null;
  }
}
