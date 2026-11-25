import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

/// Behaves like flutter_secure_storage_windows: one file holding every
/// secret, and - the part that destroyed a shop's data - the file is DELETED
/// the moment it cannot be parsed, before the error is rethrown. Plain JSON
/// stands in for DPAPI (see [decodePlainStore]).
class PluginLikePlatform extends FlutterSecureStoragePlatform {
  PluginLikePlatform(this.file);

  final File file;
  int reads = 0;

  Map<String, String> _load() {
    if (!file.existsSync()) return {};
    try {
      final decoded = jsonDecode(file.readAsStringSync()) as Map;
      return decoded.map((key, value) => MapEntry(key as String, value as String));
    } on Object {
      file.deleteSync();
      rethrow;
    }
  }

  void _save(Map<String, String> data) => file.writeAsStringSync(jsonEncode(data), flush: true);

  @override
  Future<String?> read({required String key, required Map<String, String> options}) async {
    reads++;
    return _load()[key];
  }

  @override
  Future<void> write({required String key, required String value, required Map<String, String> options}) async =>
      _save({..._load(), key: value});

  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) async =>
      _load().containsKey(key);

  @override
  Future<void> delete({required String key, required Map<String, String> options}) async =>
      _save(_load()..remove(key));

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async => _load();

  @override
  Future<void> deleteAll({required Map<String, String> options}) async => _save({});
}

/// The test stand-in for DPAPI + JSON: reads a [PluginLikePlatform] file; null when it is not one.
Map<String, String>? decodePlainStore(Uint8List bytes) {
  try {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) return null;
    return decoded.map((key, value) => MapEntry(key as String, value as String));
  } on Object {
    return null;
  }
}

/// Writes [entries] as a store file the way [PluginLikePlatform] would.
void writePlainStore(File file, Map<String, String> entries) => file.writeAsStringSync(jsonEncode(entries), flush: true);
