/// A tiny key-value store for the logged-in user's session, deliberately
/// separate from [secureStorageProvider]'s [FlutterSecureStorage].
///
/// The two need different lifetimes: device/shop identity (api_key,
/// device_id) should survive a browser restart - that's what "remembers
/// the shop" means for the browser channel - but the *logged-in user*
/// must not, so a shared/borrowed browser doesn't stay logged in as
/// whoever last used it. On native platforms both concerns can safely
/// share the same secure storage (there's no equivalent "shared
/// computer" risk), so the native implementation just delegates to
/// FlutterSecureStorage; only the web implementation actually behaves
/// differently (sessionStorage, cleared when the tab closes).
abstract class SessionStorage {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}
