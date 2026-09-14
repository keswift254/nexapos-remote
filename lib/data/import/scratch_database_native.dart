import 'package:drift/native.dart';

import '../local/database.dart';

/// A throwaway in-memory database ShopArchive.validate() uses to check
/// an imported backup's rows against the real schema (foreign keys,
/// column names) before ever touching the real AppDatabase. Split out
/// so shop_archive.dart itself doesn't unconditionally import
/// package:drift/native.dart (native-FFI-only, via package:sqlite3) -
/// selected via a conditional import in shop_archive.dart.
///
/// A real web implementation is possible later (this project's own
/// drift-web spike proved the same schema works fine against
/// WasmDatabase.open()) - not done here because it needs the WASM/
/// worker assets to be served with the deployed app and is async,
/// unlike this synchronous native constructor; validate() calling this
/// synchronously would need to become async first. Not worth doing
/// until shop-archive import/export on web is actually prioritized.
AppDatabase createScratchDatabase() => AppDatabase(NativeDatabase.memory());
