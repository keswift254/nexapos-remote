import '../local/database.dart';

/// Selected instead of scratch_database_native.dart when compiling for
/// web - see that file's doc for why a real web implementation isn't
/// built yet. Local shop-archive import/export isn't exposed on web at
/// all currently (no UI path reaches ShopArchive.validate() there), so
/// this throwing unconditionally is safe for now.
AppDatabase createScratchDatabase() => throw UnsupportedError(
  'Shop archive import/export is not available on web yet.',
);
