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
import 'package:nexapos_mobile/features/reports/reports_screen.dart';
import 'package:nexapos_mobile/features/settings/payment_settings_screen.dart'
    show currentPaymentCredentialsProvider;

import '../../support/fake_secure_storage.dart';

/// The owner, 2026-11-23: "in fact I want the reports section completely removed from cashier user". A cashier has no
/// Reports button, and the app's router sends a cashier who asks for /reports (a link, a back step, an old bookmark on
/// the web) back to the dashboard. Admins and managers keep Reports.

class _Session extends SessionNotifier {
  _Session(this.user);
  User user;
  @override
  User? build() => user;
  void become(UserRole role) =>
      state = user = User(id: 'u-${role.name}', role: role, name: role.name, username: role.name, passwordHash: '', status: 'active');
}

class _NoUpdates implements UpdateService {
  @override
  Future<UpdateCheckResult> checkForUpdate() async =>
      const UpdateCheckResult(currentVersion: '1.0.92', updateAvailable: false);

  @override
  Future<Result<void>> install(LatestVersionInfo info, {void Function(double)? onProgress}) async =>
      const Result.failure('not in this test');
}

void main() {
  Future<(ProviderContainer, dynamic, AppDatabase)> start(WidgetTester tester, UserRole role) async {
    installFakeSecureStorage();
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
      hasCachedLicenseProvider.overrideWith((ref) async => true),
      hasAnyUsersProvider.overrideWith((ref) async => true),
      currentPaymentCredentialsProvider.overrideWith((ref) async => const PaystackCredentials(
            baseUrl: 'https://test.example', apiKey: 'test', currency: 'KES', defaultEmail: '',
          )),
      sessionProvider.overrideWith(() => _Session(User(
            id: 'u-${role.name}', role: role, name: role.name, username: role.name, passwordHash: '', status: 'active',
          ))),
      updateServiceProvider.overrideWith((ref) => _NoUpdates()),
    ]);
    final router = container.read(routerProvider);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    return (container, router, db);
  }

  Future<void> finish(WidgetTester tester, ProviderContainer container, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await db.close();
  }

  String path(dynamic router) => router.routeInformationProvider.value.uri.path as String;

  testWidgets('a cashier: no Reports button, and /reports goes back to the dashboard', (tester) async {
    final (container, router, db) = await start(tester, UserRole.cashier);
    expect(path(router), '/');
    expect(find.text('New Sale'), findsOneWidget, reason: 'on the dashboard');
    expect(find.byTooltip('Reports'), findsNothing);
    for (final attempt in ['/reports', '/reports?from=link']) {
      router.go(attempt);
      await tester.pumpAndSettle();
      expect(path(router), '/', reason: attempt);
      expect(find.byType(ReportsScreen), findsNothing);
    }
    // a receipt opened "from reports" still returns somewhere a cashier may be
    router.push('/reports');
    await tester.pumpAndSettle();
    expect(find.byType(ReportsScreen), findsNothing);
    await finish(tester, container, db);
  });

  for (final role in [UserRole.admin, UserRole.manager]) {
    testWidgets('${role.name == 'admin' ? 'an admin' : 'a manager'} keeps Reports: the button opens it', (tester) async {
      final (container, router, db) = await start(tester, role);
      expect(find.byTooltip('Reports'), findsOneWidget);
      await tester.tap(find.byTooltip('Reports'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportsScreen), findsOneWidget);
      // and the address itself is allowed (a push does not change the reported address in this go_router)
      router.go('/reports');
      await tester.pumpAndSettle();
      expect(path(router), '/reports');
      expect(find.byType(ReportsScreen), findsOneWidget);
      await finish(tester, container, db);
    });
  }

  testWidgets('an admin hands the till to a cashier: the Reports button goes at once', (tester) async {
    final (container, router, db) = await start(tester, UserRole.admin);
    expect(find.byTooltip('Reports'), findsOneWidget);
    (container.read(sessionProvider.notifier) as _Session).become(UserRole.cashier);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Reports'), findsNothing);
    router.go('/reports');
    await tester.pumpAndSettle();
    expect(path(router), '/');
    await finish(tester, container, db);
  });
}
