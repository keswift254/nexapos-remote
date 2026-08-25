import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/id_generator.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/user_repository.dart';
import '../local/database.dart' hide User;
import '../local/database.dart' as drift_db show User;
import '../local/daos/users_dao.dart';
import '../local/sync_metadata.dart';

part 'user_repository_impl.g.dart';

@Riverpod(keepAlive: true)
UserRepository userRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return UserRepositoryImpl(
    db,
    db.usersDao,
    ref.watch(syncMetadataProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
  );
}

class UserRepositoryImpl implements UserRepository {
  final AppDatabase _db;
  final UsersDao _dao;
  final SyncMetadataService _syncMeta;
  final Clock _clock;
  final IdGenerator _idGenerator;

  UserRepositoryImpl(this._db, this._dao, this._syncMeta, this._clock, this._idGenerator);

  User _toEntity(drift_db.User row) => User(
        id: row.id,
        role: UserRole.fromRoleId(row.roleId),
        name: row.name,
        username: row.username,
        email: row.email,
        passwordHash: row.passwordHash,
        phone: row.phone,
        status: row.status,
      );

  @override
  Future<bool> hasAnyUsers() => _dao.hasAnyUsers();

  @override
  Future<User?> findByUsername(String username) async {
    final row = await _dao.findByUsername(username);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<User?> findById(String id) async {
    final row = await _dao.findById(id);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<List<User>> getAll() async {
    final rows = await _dao.getAll();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<void> create(User user) async {
    await _db.transaction(() async {
      final now = _clock.now().toIso8601String();
      final rev = await _syncMeta.nextLocalRev();
      final deviceId = await _syncMeta.deviceId();
      await _dao.insertUser(UsersCompanion.insert(
        id: user.id.isEmpty ? _idGenerator.newId() : user.id,
        roleId: user.role.roleId,
        name: user.name,
        username: user.username,
        email: Value(user.email),
        passwordHash: user.passwordHash,
        phone: Value(user.phone),
        status: Value(user.status),
        createdAt: now,
        updatedAt: now,
        localRev: rev,
        createdByDeviceId: deviceId,
      ));
    });
  }

  @override
  Future<void> update(User user) async {
    await _db.transaction(() async {
      final now = _clock.now().toIso8601String();
      final rev = await _syncMeta.nextLocalRev();
      await _dao.updateUser(
        user.id,
        UsersCompanion(
          roleId: Value(user.role.roleId),
          name: Value(user.name),
          username: Value(user.username),
          email: Value(user.email),
          passwordHash: Value(user.passwordHash),
          phone: Value(user.phone),
          status: Value(user.status),
          updatedAt: Value(now),
          localRev: Value(rev),
        ),
      );
    });
  }
}
