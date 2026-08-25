import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../core/result.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../entities/user.dart';
import '../entities/user_role.dart';
import 'auth_service.dart';

part 'session_service.g.dart';

const _storedUserIdKey = 'nexapos.session.userId';

/// Current logged-in user as reactive state, persisted via
/// flutter_secure_storage so app resume behaves like PHP's session
/// cookie. Role checks are enforced here at the use-case boundary, not
/// just by hiding buttons - on a phone there's no separate server tier
/// to fall back on the way Auth::requireRole() protects a PHP route
/// even if the UI is bypassed. go_router's redirect guard calls [can]
/// too, so there is exactly one source of truth for "who can do what".
@Riverpod(keepAlive: true)
class SessionNotifier extends _$SessionNotifier {
  @override
  User? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    final storage = ref.read(secureStorageProvider);
    final userId = await storage.read(key: _storedUserIdKey);
    if (userId == null) return;
    final repo = ref.read(userRepositoryProvider);
    final user = await repo.findById(userId);
    if (user != null && user.isActive) {
      state = user;
    } else {
      await storage.delete(key: _storedUserIdKey);
    }
  }

  Future<Result<User>> login(String username, String password) async {
    final result = await ref.read(authServiceProvider).login(username, password);
    return result.when(
      ok: (user) {
        state = user;
        ref.read(secureStorageProvider).write(key: _storedUserIdKey, value: user.id);
        return Result.ok(user);
      },
      failure: (message) => Result.failure(message),
    );
  }

  Future<void> logout() async {
    state = null;
    await ref.read(secureStorageProvider).delete(key: _storedUserIdKey);
  }

  bool get isLoggedIn => state != null;

  bool can(Set<UserRole> allowedRoles) {
    final user = state;
    if (user == null) return false;
    return user.role.isAtLeast(allowedRoles);
  }
}
