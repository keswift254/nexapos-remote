import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/users_table.dart';

part 'users_dao.g.dart';

@DriftAccessor(tables: [Users])
class UsersDao extends DatabaseAccessor<AppDatabase> with _$UsersDaoMixin {
  UsersDao(super.db);

  Future<bool> hasAnyUsers() async {
    final row = await (select(users)
          ..where((u) => u.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  Future<User?> findByUsername(String username) {
    return (select(users)
          ..where((u) => u.username.equals(username) & u.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
  }

  Future<User?> findById(String id) {
    return (select(users)
          ..where((u) => u.id.equals(id) & u.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<User>> getAll() {
    return (select(users)..where((u) => u.deletedAt.isNull())).get();
  }

  Future<void> insertUser(UsersCompanion companion) {
    return into(users).insert(companion);
  }

  Future<void> updateUser(String id, UsersCompanion companion) {
    return (update(users)..where((u) => u.id.equals(id))).write(companion);
  }
}
