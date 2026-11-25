@TestOn('windows')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/secure_storage_guard_io.dart';
import 'package:nexapos_mobile/core/windows_dpapi.dart';
import 'package:path/path.dart' as p;

/// Real Windows DPAPI (this test runs on Windows only): the guard must read a key file exactly as
/// flutter_secure_storage_windows writes it - DPAPI for the current user, no entropy, around UTF-8 JSON - because on
/// 2026-11-25 the only copies of a shop's database key were such files set aside as "unreadable".
void main() {
  Uint8List storeBytes(Map<String, String> entries) => dpapiProtect(Uint8List.fromList(utf8.encode(jsonEncode(entries))));

  test('a key file locked by Windows is read back, every entry', () {
    final bytes = storeBytes({'nexapos.db.encryptionKey': 'f' * 64, 'nexapos.license.validUntil': '2027-01-01'});
    expect(bytes.length, greaterThan(100), reason: 'really encrypted, not the plain JSON');
    expect(decodeWindowsSecureStore(bytes), {'nexapos.db.encryptionKey': 'f' * 64, 'nexapos.license.validUntil': '2027-01-01'});
  });

  test('a torn file, plain text, or locked non-JSON reads as nothing - never throws', () {
    final bytes = storeBytes({'a': 'b'});
    expect(decodeWindowsSecureStore(Uint8List.sublistView(bytes, 0, bytes.length ~/ 2)), isNull);
    expect(decodeWindowsSecureStore(Uint8List.fromList(utf8.encode('{"a":"b"}'))), isNull);
    expect(decodeWindowsSecureStore(dpapiProtect(Uint8List.fromList(utf8.encode('not json')))), isNull);
    expect(decodeWindowsSecureStore(dpapiProtect(Uint8List.fromList(utf8.encode('["a list"]')))), isNull);
  });

  test('the guard finds the database key in a real set-aside copy and puts it back', () async {
    final dir = await Directory.systemTemp.createTemp('nexapos_dpapi_guard_');
    addTearDown(() => dir.delete(recursive: true));
    final guard = SecureStorageFileGuard(dir, protectedKeys: const ['nexapos.db.encryptionKey'], decode: decodeWindowsSecureStore);
    await guard.primary.writeAsBytes(storeBytes({'nexapos.license.validUntil': 'x'}));
    await guard.backup.writeAsBytes(storeBytes({'nexapos.license.validUntil': 'x'}));
    await File(p.join(dir.path, '$secureStorageFileName.corrupt-1795525341600'))
        .writeAsBytes(storeBytes({'nexapos.db.encryptionKey': 'KEY', 'nexapos.platform.apiKey': 'API'}));

    expect(await guard.holdsProtectedKeys(guard.primary), isFalse);
    final copy = await guard.findCopy((e) => e['nexapos.db.encryptionKey'] == 'KEY');
    expect(copy, isNotNull);
    await guard.installCopy(copy!);

    expect(decodeWindowsSecureStore(await guard.primary.readAsBytes())!['nexapos.db.encryptionKey'], 'KEY');
    expect(await guard.holdsProtectedKeys(guard.backup), isTrue);
  });
}
