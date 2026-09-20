import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/core/utils/id_generator.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/data/repositories/user_repository_impl.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/auth_service.dart';
import 'package:nexapos_mobile/domain/services/login_throttle.dart';

import '../../support/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late FixedClock clock;
  late AuthService auth;

  setUp(() async {
    installFakeSecureStorage();
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime.utc(2026, 9, 20, 12));
    final repo = UserRepositoryImpl(db, db.usersDao, SyncMetadataService(db), clock, UuidIdGenerator());
    auth = AuthService(repo, UuidIdGenerator(), throttle: LoginThrottle(db, clock));
    await auth.createUser(
      name: 'Owner',
      username: 'owner',
      password: 'correct-password',
      role: UserRole.admin,
    );
  });
  tearDown(() => db.close());

  Future<String?> wrong([String user = 'owner']) async =>
      (await auth.login(user, 'not-the-password')).when(ok: (_) => null, failure: (m) => m);

  test('the first few wrong passwords just say incorrect - no lock yet', () async {
    for (var i = 0; i < LoginThrottle.freeAttempts - 1; i++) {
      expect(await wrong(), 'Incorrect username or password.');
    }
    // Still not locked: the right password works.
    expect((await auth.login('owner', 'correct-password')).isOk, isTrue);
  });

  test('after 5 wrong guesses even the correct password is refused until the wait is over', () async {
    for (var i = 0; i < LoginThrottle.freeAttempts; i++) {
      await wrong();
    }
    final refused = await auth.login('owner', 'correct-password');
    expect(refused.isFailure, isTrue);
    expect(refused.when(ok: (_) => '', failure: (m) => m), contains('Too many failed attempts'));
    expect(refused.when(ok: (_) => '', failure: (m) => m), contains('30 seconds'));

    clock.advance(const Duration(seconds: 31));
    expect((await auth.login('owner', 'correct-password')).isOk, isTrue);
  });

  test('each further failure doubles the lock, capped at 15 minutes', () async {
    for (var i = 0; i < LoginThrottle.freeAttempts; i++) {
      await wrong();
    }
    clock.advance(const Duration(seconds: 31));
    await wrong(); // 6th failure -> 60s
    expect(await wrong(), contains('1 minute'));

    // Keep failing through many rounds; the wait must never exceed 15 min.
    for (var i = 0; i < 12; i++) {
      clock.advance(const Duration(minutes: 20));
      await wrong();
    }
    final lock = await LoginThrottle(db, clock).remainingLock('owner');
    expect(lock, isNotNull);
    expect(lock! <= LoginThrottle.maxLock, isTrue);
  });

  test('a successful login clears the count', () async {
    for (var i = 0; i < LoginThrottle.freeAttempts - 1; i++) {
      await wrong();
    }
    expect((await auth.login('owner', 'correct-password')).isOk, isTrue);
    // Four more wrong guesses would have tripped the lock had the earlier
    // four still counted.
    for (var i = 0; i < LoginThrottle.freeAttempts - 1; i++) {
      await wrong();
    }
    expect((await auth.login('owner', 'correct-password')).isOk, isTrue);
  });

  test('a username that does not exist is throttled too, so a lock never reveals which accounts are real', () async {
    for (var i = 0; i < LoginThrottle.freeAttempts; i++) {
      expect(await wrong('nobody'), 'Incorrect username or password.');
    }
    final message = await wrong('nobody');
    expect(message, contains('Too many failed attempts'));
  });

  test('the lock survives closing and reopening the app (it is stored, not held in memory)', () async {
    for (var i = 0; i < LoginThrottle.freeAttempts; i++) {
      await wrong();
    }
    // A brand-new throttle over the same database - what a relaunch builds.
    final relaunched = LoginThrottle(db, clock);
    expect(await relaunched.remainingLock('owner'), isNotNull);
  });

  test('locking one username does not lock another', () async {
    await auth.createUser(
      name: 'Cashier',
      username: 'cashier',
      password: 'cashier-password',
      role: UserRole.cashier,
    );
    for (var i = 0; i < LoginThrottle.freeAttempts; i++) {
      await wrong();
    }
    expect((await auth.login('cashier', 'cashier-password')).isOk, isTrue);
  });

  test('the wait is described without promising less than the real time', () {
    expect(LoginThrottle.describe(const Duration(seconds: 30)), '30 seconds');
    expect(LoginThrottle.describe(const Duration(milliseconds: 29500)), '30 seconds');
    expect(LoginThrottle.describe(const Duration(seconds: 61)), '2 minutes');
    expect(LoginThrottle.describe(const Duration(minutes: 15)), '15 minutes');
  });
}
