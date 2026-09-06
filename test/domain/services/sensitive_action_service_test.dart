import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:drift/native.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/data/repositories/user_repository_impl.dart';
import 'package:nexapos_mobile/core/utils/id_generator.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/domain/services/auth_service.dart';
import 'package:nexapos_mobile/domain/services/sensitive_action_service.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:otp/otp.dart';

import '../../support/fake_secure_storage.dart';

class TestClock implements Clock {
  DateTime value = DateTime.utc(2026, 9, 6, 12);
  @override
  DateTime now() => value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late SensitiveActionService security;
  late TestClock clock;
  late AuthService auth;
  String? userId;
  const secret = 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP';
  String code() => OTP.generateTOTPCodeString(
    secret,
    clock.now().millisecondsSinceEpoch,
    algorithm: Algorithm.SHA1,
    isGoogle: true,
  );
  setUp(() async {
    installFakeSecureStorage();
    db = AppDatabase(NativeDatabase.memory());
    clock = TestClock();
    final repo = UserRepositoryImpl(
      db,
      db.usersDao,
      SyncMetadataService(db),
      clock,
      UuidIdGenerator(),
    );
    auth = AuthService(repo, UuidIdGenerator());
    final result = await auth.createUser(
      name: 'Owner',
      username: 'owner',
      password: 'long-password',
      role: UserRole.admin,
    );
    userId = result.when(ok: (u) => u.id, failure: (e) => throw StateError(e));
    security = SensitiveActionService(
      auth,
      const FlutterSecureStorage(),
      clock,
      () => userId,
    );
  });
  tearDown(() => db.close());

  test(
    'requires password and authenticator, then consumes approval exactly once',
    () async {
      await expectLater(
        security.approve(
          username: 'owner',
          password: 'bad',
          code: code(),
          action: 'Leave this shop',
          enrollmentSecret: secret,
        ),
        throwsStateError,
      );
      final approval = await security.approve(
        username: 'owner',
        password: 'long-password',
        code: code(),
        action: 'Leave this shop',
        enrollmentSecret: secret,
      );
      await expectLater(
        security.approve(
          username: 'owner',
          password: 'long-password',
          code: code(),
          action: 'Leave this shop',
        ),
        throwsStateError,
      );
      await security.consume(approval, 'Leave this shop');
      await expectLater(
        security.consume(approval, 'Leave this shop'),
        throwsStateError,
      );
    },
  );

  test('approval is bound to action, active user and expiration', () async {
    final approval = await security.approve(
      username: 'owner',
      password: 'long-password',
      code: code(),
      action: 'Leave this shop',
      enrollmentSecret: secret,
    );
    await expectLater(
      security.consume(approval, 'Import shop data'),
      throwsStateError,
    );
    final owner = userId;
    userId = null;
    await expectLater(
      security.consume(approval, 'Leave this shop'),
      throwsStateError,
    );
    userId = owner;
    clock.value = clock.value.add(const Duration(minutes: 6));
    await expectLater(
      security.consume(approval, 'Leave this shop'),
      throwsStateError,
    );
  });

  test('five failures lock attempts even across service recreation', () async {
    for (var i = 0; i < 5; i++) {
      await expectLater(
        security.verifyPassword('owner', 'wrong'),
        throwsStateError,
      );
    }
    final other = SensitiveActionService(
      auth,
      const FlutterSecureStorage(),
      clock,
      () => userId,
    );
    await expectLater(
      other.verifyPassword('owner', 'long-password'),
      throwsStateError,
    );
    clock.value = clock.value.add(const Duration(minutes: 6));
    expect(await other.verifyPassword('owner', 'long-password'), userId);
  });
}
