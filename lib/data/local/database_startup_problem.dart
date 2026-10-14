enum DatabaseProblemKind {
  /// An encrypted database exists but its key cannot be found or read.
  keyMissing,

  /// The stored key does not open the encrypted database.
  keyDoesNotOpen,
}

/// Why the app must not simply start: opening it normally would create a new
/// empty database (or a new key) next to data that may still be recoverable.
class DatabaseStartupProblem {
  const DatabaseStartupProblem(this.kind, this.databasePath);

  final DatabaseProblemKind kind;
  final String databasePath;
}
