import 'database_startup_problem.dart';

/// The browser build has no encrypted database file to protect.
Future<DatabaseStartupProblem?> checkDatabaseStartup() async => null;

Future<String> setAsideDatabaseFiles(String databasePath) async =>
    throw UnsupportedError('Not available in the browser build.');
