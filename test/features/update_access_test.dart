import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/app.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/result.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide User;
import 'package:nexapos_mobile/data/update/update_gateway.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/domain/services/update_service.dart';
import 'package:nexapos_mobile/features/settings/payment_settings_screen.dart'
    show currentPaymentCredentialsProvider;
import '../support/fake_secure_storage.dart';

class _Session extends SessionNotifier {
  final User user;
  _Session(this.user);
  @override
  User? build() => user;
}

class _Updates implements UpdateService {
  int checks = 0;
  int installs = 0;
  @override
  Future<UpdateCheckResult> checkForUpdate() async {
    checks++;
    return const UpdateCheckResult(currentVersion: '1.0.11', updateAvailable: false);
  }

  @override
  Future<Result<void>> install(LatestVersionInfo info, {void Function(double)? onProgress}) async {
    installs++;
    return const Result.failure('Installation is disabled in this test.');
  }
}

void main() {
  for (final role in UserRole.values) {
    testWidgets('${role.name} can check updates without installing or gaining admin access', (tester) async {
      installFakeSecureStorage();
      final db = AppDatabase(NativeDatabase.memory());
      final updates = _Updates();
      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWith((ref) => db),
        hasCachedLicenseProvider.overrideWith((ref) async => true),
        hasAnyUsersProvider.overrideWith((ref) async => true),
        currentPaymentCredentialsProvider.overrideWith((ref) async => const PaystackCredentials(
          baseUrl: 'https://test.example', apiKey: 'test', currency: 'KES', defaultEmail: '',
        )),
        sessionProvider.overrideWith(() => _Session(User(
          id: 'test-user', role: role, name: 'Test User', username: 'tester', passwordHash: '', status: 'active',
        ))),
        updateServiceProvider.overrideWith((ref) => updates),
      ]);
      final router = container.read(routerProvider);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      // The dashboard itself now fires an automatic background check on
      // load (see dashboard_screen.dart) on top of app.dart's own
      // startup one - both already settled by pumpAndSettle above and
      // both use this test's fake (always "no update"), so applying the
      // "update available" result here, after mounting rather than
      // before, is what actually sticks for the assertions below.
      container.read(updateAvailabilityProvider.notifier).applyResult(const UpdateCheckResult(
        currentVersion: '1.0.11', updateAvailable: true,
        latest: LatestVersionInfo(version: '1.0.12', androidUrl: ''),
      ));
      await tester.pump();
      expect(find.text('Update available: version 1.0.12'), findsOneWidget);
      expect(find.byTooltip('Update available: version 1.0.12'), findsOneWidget);
      if (role != UserRole.admin) {
        expect(find.byTooltip('Users & Roles'), findsNothing);
      }
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Privacy'), findsOneWidget);
      if (role != UserRole.admin) {
        expect(find.text('General Settings'), findsNothing);
        expect(find.text('Payment Settings'), findsNothing);
        expect(find.text('Device Sync'), findsNothing);
        expect(find.text('Backup'), findsNothing);
      }
      // Relative, not absolute, from here on - automatic background
      // checks (dashboard load, app startup) already happened above and
      // may happen again on later navigation in this same test; what
      // actually matters is that each explicit tap below adds exactly
      // one more call of its own.
      final checksBeforeFirstTap = updates.checks;
      await tester.tap(find.text('Check for Updates'));
      await tester.pumpAndSettle();
      expect(find.text('Software Update'), findsOneWidget);
      expect(updates.checks, checksBeforeFirstTap + 1);
      final checksBeforeSecondTap = updates.checks;
      await tester.tap(find.text('Check for Updates'));
      await tester.pumpAndSettle();
      expect(updates.checks, checksBeforeSecondTap + 1);
      expect(updates.installs, 0);
      if (role != UserRole.admin) {
        for (final route in ['/users', '/device-sync', '/payment-settings', '/business-settings']) {
          router.go(route);
          await tester.pumpAndSettle();
          expect(router.routeInformationProvider.value.uri.path, '/');
        }
      }
      await container.read(sessionProvider.notifier).logout();
      router.go('/update');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(updates.installs, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await db.close();
    });
  }
}
