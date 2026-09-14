import 'package:web/web.dart' as web;

import 'session_storage.dart';

/// Backed by window.sessionStorage, not localStorage - the entire point
/// is that it clears when the tab closes, so a shared/borrowed browser
/// never stays logged in as whoever used it last. Device/shop identity
/// (secureStorageProvider, backed by flutter_secure_storage_web, which
/// does persist) is deliberately a separate store from this one - see
/// session_storage.dart's class doc.
SessionStorage createSessionStorage() => _WebSessionStorage();

class _WebSessionStorage implements SessionStorage {
  @override
  Future<String?> read({required String key}) async =>
      web.window.sessionStorage.getItem(key);

  @override
  Future<void> write({required String key, required String value}) async =>
      web.window.sessionStorage.setItem(key, value);

  @override
  Future<void> delete({required String key}) async =>
      web.window.sessionStorage.removeItem(key);
}
