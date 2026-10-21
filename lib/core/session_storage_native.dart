import 'session_storage.dart';

/// Login sessions last only as long as the native process. Device identity,
/// licence, database keys and lock preferences remain in their own persistent
/// secure storage. Closing/reopening the app must not silently restore a
/// cashier or owner session from disk, including on Windows.
SessionStorage createSessionStorage() => _NativeSessionStorage();

class _NativeSessionStorage implements SessionStorage {
  static final Map<String, String> _session = {};

  @override
  Future<String?> read({required String key}) async => _session[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _session[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _session.remove(key);
  }
}
