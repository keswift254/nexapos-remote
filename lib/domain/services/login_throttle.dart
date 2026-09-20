import 'dart:math';

import 'package:drift/drift.dart' show Variable;

import '../../core/utils/clock.dart';
import '../../data/local/database.dart';

/// Slows down repeated wrong-password attempts against a username.
///
/// Login is a local bcrypt check with nothing on the other end to say
/// "too many tries", so before this anyone standing at the till could
/// script unlimited guesses at the admin account - bcrypt only makes each
/// guess slow, not finite. The count is stored in the database (not
/// memory) so simply closing and reopening the app doesn't reset it.
///
/// Counted by the username as typed, whether or not it exists: a lock that
/// only ever appeared for real accounts would tell an attacker which
/// usernames are valid.
class LoginThrottle {
  LoginThrottle(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// Wrong guesses allowed before the first lock.
  static const freeAttempts = 5;
  static const baseLock = Duration(seconds: 30);
  static const maxLock = Duration(minutes: 15);

  String _key(String username) => 'login_throttle:${username.trim().toLowerCase()}';

  /// How much longer this username is locked out, or null if it isn't.
  Future<Duration?> remainingLock(String username) async {
    final state = await _read(username);
    final until = state?.lockedUntil;
    if (until == null) return null;
    final left = until.difference(_clock.now());
    return left > Duration.zero ? left : null;
  }

  /// Records a wrong guess. From the [freeAttempts]th failure on, each
  /// further one doubles the lock (30s, 1m, 2m ... up to [maxLock]).
  Future<void> recordFailure(String username) async {
    final failures = ((await _read(username))?.failures ?? 0) + 1;
    DateTime? until;
    if (failures >= freeAttempts) {
      final doublings = min(failures - freeAttempts, 10);
      var lock = baseLock * (1 << doublings);
      if (lock > maxLock) lock = maxLock;
      until = _clock.now().add(lock);
    }
    await _db.customStatement(
      'INSERT OR REPLACE INTO local_safety_state(id, value) VALUES(?, ?)',
      [_key(username), '$failures|${until?.toIso8601String() ?? ''}'],
    );
  }

  Future<void> reset(String username) => _db.customStatement(
        'DELETE FROM local_safety_state WHERE id = ?',
        [_key(username)],
      );

  Future<({int failures, DateTime? lockedUntil})?> _read(String username) async {
    final rows = await _db
        .customSelect(
          'SELECT value FROM local_safety_state WHERE id = ?',
          variables: [Variable<String>(_key(username))],
        )
        .get();
    if (rows.isEmpty) return null;
    final parts = rows.first.read<String>('value').split('|');
    final failures = int.tryParse(parts.first) ?? 0;
    final until = parts.length > 1 && parts[1].isNotEmpty ? DateTime.tryParse(parts[1]) : null;
    return (failures: failures, lockedUntil: until);
  }

  /// "45 seconds" / "3 minutes", rounded up so it never promises less
  /// than the real wait.
  static String describe(Duration d) {
    if (d.inSeconds < 60) {
      final s = max(1, d.inSeconds + (d.inMilliseconds % 1000 > 0 ? 1 : 0));
      return '$s second${s == 1 ? '' : 's'}';
    }
    final m = (d.inSeconds / 60).ceil();
    return '$m minute${m == 1 ? '' : 's'}';
  }
}
