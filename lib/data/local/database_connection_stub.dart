import 'package:drift/drift.dart';

/// Selected instead of database_connection_native.dart when compiling
/// for web (see database.dart's conditional import) - a real web
/// connection opener (encryption key storage strategy, sqlite3mc.wasm
/// wiring) doesn't exist yet, so AppDatabase.defaults() isn't callable
/// on web today. This exists purely so database.dart itself - and
/// everything that imports it, like domain services and their tests -
/// can still compile for web; code that only ever constructs
/// AppDatabase directly (passing its own DatabaseConnection, as the
/// drift-web spike test does) never calls this at all.
DatabaseConnection openConnection() {
  throw UnsupportedError(
    'AppDatabase.defaults() has no web implementation yet - construct AppDatabase with an explicit web DatabaseConnection instead.',
  );
}
