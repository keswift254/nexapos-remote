import 'package:bcrypt/bcrypt.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../core/result.dart';
import '../../core/utils/id_generator.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../entities/user.dart';
import '../entities/user_role.dart';
import '../repositories/user_repository.dart';

part 'auth_service.g.dart';

@Riverpod(keepAlive: true)
AuthService authService(Ref ref) {
  return AuthService(ref.watch(userRepositoryProvider), ref.watch(idGeneratorProvider));
}

/// Local bcrypt login and first-run admin creation. There is no server
/// tier here to fall back on the way PHP's Auth::requireLogin() does -
/// this class and [SessionService]'s role checks ARE the enforcement
/// point.
class AuthService {
  final UserRepository _userRepository;
  final IdGenerator _idGenerator;

  AuthService(this._userRepository, this._idGenerator);

  Future<bool> hasAnyUsers() => _userRepository.hasAnyUsers();

  Future<Result<User>> login(String username, String password) async {
    final user = await _userRepository.findByUsername(username.trim());
    if (user == null) {
      return const Result.failure('Incorrect username or password.');
    }
    if (!user.isActive) {
      return const Result.failure('This account has been disabled.');
    }
    final matches = BCrypt.checkpw(password, user.passwordHash);
    if (!matches) {
      return const Result.failure('Incorrect username or password.');
    }
    return Result.ok(user);
  }

  /// Creates the first admin account during the setup wizard. Callers
  /// must have already confirmed hasAnyUsers() is false - this does not
  /// re-check, so it can also be reused for admin-created users later
  /// (Step 3's users CRUD) by passing a non-admin role.
  Future<Result<User>> createUser({
    required String name,
    required String username,
    required String password,
    required UserRole role,
    String? email,
    String? phone,
  }) async {
    if (name.trim().isEmpty) return const Result.failure('Enter a name.');
    if (username.trim().isEmpty) return const Result.failure('Enter a username.');
    if (password.length < 6) {
      return const Result.failure('Password must be at least 6 characters.');
    }
    final existing = await _userRepository.findByUsername(username.trim());
    if (existing != null) {
      return const Result.failure('That username is already taken.');
    }

    final hash = BCrypt.hashpw(password, BCrypt.gensalt());
    final user = User(
      id: _idGenerator.newId(),
      role: role,
      name: name.trim(),
      username: username.trim(),
      email: email?.trim().isEmpty ?? true ? null : email!.trim(),
      passwordHash: hash,
      phone: phone?.trim().isEmpty ?? true ? null : phone!.trim(),
      status: 'active',
    );
    await _userRepository.create(user);
    return Result.ok(user);
  }

  Future<List<User>> getAllUsers() => _userRepository.getAll();

  /// Edits name/username/role/contact details, and optionally the
  /// password (pass null to keep the existing hash). Mirrors PHP's
  /// update_user route - admin-only, enforced by the caller checking
  /// SessionService.can before ever reaching this screen.
  Future<Result<User>> updateUser({
    required String id,
    required String name,
    required String username,
    required UserRole role,
    String? email,
    String? phone,
    String? newPassword,
  }) async {
    if (name.trim().isEmpty) return const Result.failure('Enter a name.');
    if (username.trim().isEmpty) return const Result.failure('Enter a username.');
    if (newPassword != null && newPassword.isNotEmpty && newPassword.length < 6) {
      return const Result.failure('Password must be at least 6 characters.');
    }

    final existing = await _userRepository.findById(id);
    if (existing == null) return const Result.failure('User not found.');

    final usernameOwner = await _userRepository.findByUsername(username.trim());
    if (usernameOwner != null && usernameOwner.id != id) {
      return const Result.failure('That username is already taken.');
    }

    final hash = (newPassword == null || newPassword.isEmpty)
        ? existing.passwordHash
        : BCrypt.hashpw(newPassword, BCrypt.gensalt());

    final updated = existing.copyWith(
      name: name.trim(),
      username: username.trim(),
      role: role,
      email: email?.trim().isEmpty ?? true ? null : email!.trim(),
      phone: phone?.trim().isEmpty ?? true ? null : phone!.trim(),
      passwordHash: hash,
    );
    await _userRepository.update(updated);
    return Result.ok(updated);
  }

  /// Refuses to let an admin disable their own account - there would be
  /// no way back in afterward since a fresh install never re-seeds a
  /// default admin.
  Future<Result<void>> setUserActive(
    String id, {
    required bool active,
    required String currentUserId,
  }) async {
    if (id == currentUserId && !active) {
      return const Result.failure('You cannot disable your own account.');
    }
    final existing = await _userRepository.findById(id);
    if (existing == null) return const Result.failure('User not found.');
    await _userRepository.update(existing.copyWith(status: active ? 'active' : 'disabled'));
    return const Result.ok(null);
  }
}
