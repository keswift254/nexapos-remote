import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:otp/otp.dart';

import '../../core/providers.dart';
import '../../core/utils/clock.dart';
import '../entities/user_role.dart';
import 'auth_service.dart';
import 'session_service.dart';

final sensitiveActionProvider = Provider<SensitiveActionService>(
  (ref) => SensitiveActionService(
    ref.watch(authServiceProvider),
    ref.watch(secureStorageProvider),
    ref.watch(clockProvider),
    () => ref.read(sessionProvider)?.id,
  ),
);

class ActionApproval {
  final String userId;
  final String action;
  final DateTime expires;
  bool _used = false;
  ActionApproval._(this.userId, this.action, this.expires);
}

/// Device-local second factor, never exported or shared through shop sync.
class SensitiveActionService {
  final AuthService auth;
  final FlutterSecureStorage storage;
  final Clock clock;
  final String? Function() currentUserId;
  SensitiveActionService(
    this.auth,
    this.storage,
    this.clock,
    this.currentUserId,
  );

  String _key(String id) => 'nexapos.security.$id';

  Future<Map<String, dynamic>> _state(String id) async {
    final value = await storage.read(key: _key(id));
    return value == null
        ? {}
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  Future<String> verifyPassword(String username, String password) async {
    final id = currentUserId();
    if (id == null) throw StateError('Sign in as an administrator first.');
    final state = await _state(id);
    if ((state['lockedUntil'] as int? ?? 0) >
        clock.now().millisecondsSinceEpoch) {
      throw StateError('Too many attempts. Try again in five minutes.');
    }
    final result = await auth.login(username, password);
    final user = result.when(ok: (user) => user, failure: (_) => null);
    if (user == null || user.id != id || user.role != UserRole.admin) {
      await _failure(id, state);
      throw StateError('Administrator credentials were not accepted.');
    }
    return id;
  }

  Future<bool> isEnrolled(String id) async =>
      (await _state(id))['secret'] != null;

  String newSecret() {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final random = Random.secure();
    return List.generate(32, (_) => alphabet[random.nextInt(32)]).join();
  }

  int? _matchingStep(String secret, String code) {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) return null;
    final step = clock.now().millisecondsSinceEpoch ~/ 30000;
    for (final candidate in [step, step - 1, step + 1]) {
      final expected = OTP.generateTOTPCodeString(
        secret,
        candidate * 30000,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );
      if (OTP.constantTimeVerification(expected, code)) return candidate;
    }
    return null;
  }

  Future<void> _failure(String id, Map<String, dynamic> state) async {
    final attempts = (state['attempts'] as int? ?? 0) + 1;
    state['attempts'] = attempts;
    if (attempts >= 5) {
      state['attempts'] = 0;
      state['lockedUntil'] = clock
          .now()
          .add(const Duration(minutes: 5))
          .millisecondsSinceEpoch;
    }
    await storage.write(key: _key(id), value: jsonEncode(state));
  }

  Future<ActionApproval> approve({
    required String username,
    required String password,
    required String code,
    required String action,
    String? enrollmentSecret,
  }) async {
    final id = await verifyPassword(username, password);
    final state = await _state(id);
    final savedSecret = state['secret'] as String?;
    final secret = savedSecret ?? enrollmentSecret;
    if (secret == null || !RegExp(r'^[A-Z2-7]{32}$').hasMatch(secret)) {
      throw StateError('Set up an authenticator before continuing.');
    }
    final step = _matchingStep(secret, code.trim());
    if (step == null || step <= (state['lastStep'] as int? ?? -1)) {
      await _failure(id, state);
      throw StateError(
        'Invalid or already used code. Use the next authenticator code.',
      );
    }
    await storage.write(
      key: _key(id),
      value: jsonEncode({
        'secret': secret,
        'lastStep': step,
        'attempts': 0,
        'lockedUntil': 0,
      }),
    );
    return ActionApproval._(
      id,
      action,
      clock.now().add(const Duration(minutes: 5)),
    );
  }

  Future<void> consume(ActionApproval approval, String action) async {
    if (approval._used ||
        approval.action != action ||
        currentUserId() != approval.userId ||
        !clock.now().isBefore(approval.expires)) {
      throw StateError('Authorization expired. Verify your identity again.');
    }
    approval._used = true;
    final users = await auth.getAllUsers();
    if (!users.any(
      (u) => u.id == approval.userId && u.isActive && u.role == UserRole.admin,
    )) {
      throw StateError('Administrator access is required.');
    }
  }
}
