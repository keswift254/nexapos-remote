import '../entities/user.dart';

abstract class UserRepository {
  /// True once any user row exists. Drives the first-run setup wizard:
  /// unlike PHP's install SQL, no default admin is ever seeded, so a
  /// fresh install genuinely has zero users until setup runs.
  Future<bool> hasAnyUsers();

  Future<User?> findByUsername(String username);

  Future<User?> findById(String id);

  Future<List<User>> getAll();

  /// Inserts the first admin during setup, or any user via the
  /// admin-only "Users & Roles" screen (Step 3 build sequence).
  Future<void> create(User user);

  Future<void> update(User user);
}
