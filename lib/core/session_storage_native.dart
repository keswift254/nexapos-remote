import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_storage.dart';

/// Native has no "shared computer" risk the way a browser does, so the
/// session can safely live in the same secure storage as everything
/// else - a separate FlutterSecureStorage instance rather than reusing
/// secureStorageProvider's, purely to keep this class free of a Riverpod
/// Ref dependency (createSessionStorage() is called from a conditional
/// import, not a provider body).
SessionStorage createSessionStorage() => _NativeSessionStorage();

class _NativeSessionStorage implements SessionStorage {
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}
