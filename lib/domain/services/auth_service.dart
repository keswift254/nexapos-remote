import 'package:bcrypt/bcrypt.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../core/result.dart';
import '../../core/utils/id_generator.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../entities/user.dart';
import '../entities/user_role.dart';
import '../repositories/user_repository.dart';
import 'login_throttle.dart';

part 'auth_service.g.dart';

@Riverpod(keepAlive: true)
AuthService authService(Ref ref) {
  return AuthService(
    ref.watch(userRepositoryProvider),
    ref.watch(idGeneratorProvider),
    throttle: LoginThrottle(ref.watch(appDatabaseProvider), ref.watch(clockProvider)),
  );
}

/// Local bcrypt login and first-run admin creation. There is no server
/// tier here to fall back on the way PHP's Auth::requireLogin() does -
/// this class and [SessionService]'s role checks ARE the enforcement
/// point.
class AuthService {
  final UserRepository _userRepository;
  final IdGenerator _idGenerator;
  // Optional so a caller that only needs createUser/etc. (and older tests)
  // can build one without a database behind it; the real provider always
  // supplies it, so the app itself always throttles.
  final LoginThrottle? _throttle;

  AuthService(this._userRepository, this._idGenerator, {LoginThrottle? throttle})
      // A named parameter can't be a private initializing formal, so the
      // lint's suggestion doesn't apply here.
      // ignore: prefer_initializing_formals
      : _throttle = throttle;

  Future<bool> hasAnyUsers() => _userRepository.hasAnyUsers();

  Future<Result<User>> login(String username, String password) async {
    final typed = username.trim();
    // Checked before the (deliberately slow) bcrypt compare, so a locked
    // username costs nothing to refuse and even the right password is
    // turned away until the wait is over.
    final locked = await _throttle?.remainingLock(typed);
    if (locked != null) {
      return Result.failure(
        'Too many failed attempts. Try again in ${LoginThrottle.describe(locked)}.',
      );
    }
    final user = await _userRepository.findByUsername(typed);
    if (user == null) {
      await _throttle?.recordFailure(typed);
      return const Result.failure('Incorrect username or password.');
    }
    if (!user.isActive) {
      return const Result.failure('This account has been disabled.');
    }
    final matches = BCrypt.checkpw(password, user.passwordHash);
    if (!matches) {
      await _throttle?.recordFailure(typed);
      return const Result.failure('Incorrect username or password.');
    }
    await _throttle?.reset(typed);
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
    if (username.trim().toLowerCase() == 'nexapos-support') {
      return const Result.failure('This username is reserved for support recovery.');
    }
    if (password.length < 8) {
      return const Result.failure('Password must be at least 8 characters.');
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

  /// Support recovery changes only the password, preserving the latest account details.
  Future<Result<void>> resetUserPassword(String id, String password) async {
    if (password.length < 8) {
      return const Result.failure('Password must be at least 8 characters.');
    }
    final updated = await _userRepository.updatePassword(id, BCrypt.hashpw(password, BCrypt.gensalt()));
    if (!updated) {
      return const Result.failure('The account is unavailable or disabled.');
    }
    return const Result.ok(null);
  }

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
    if (newPassword != null && newPassword.isNotEmpty && newPassword.length < 8) {
      return const Result.failure('Password must be at least 8 characters.');
    }

    final existing = await _userRepository.findById(id);
    if (existing == null) return const Result.failure('User not found.');
    if (username.trim().toLowerCase() == 'nexapos-support') {
      return const Result.failure('This username is reserved for support recovery.');
    }

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
