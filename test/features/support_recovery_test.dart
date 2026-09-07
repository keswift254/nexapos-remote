import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/data/licensing/license_gateway.dart';
import 'package:nexapos_mobile/data/local/database.dart' show AppDatabase;
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/services/auth_service.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import 'package:nexapos_mobile/features/auth/support_recovery_dialog.dart';
import '../support/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installFakeSecureStorage);
  testWidgets('support authorization reveals usernames and resets only the selected password', (tester) async {
    var authorized = false;
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) {
        final db = AppDatabase(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
      licenseGatewayProvider.overrideWith((ref) => LicenseGateway(MockClient((request) async {
        expect(request.url.queryParameters['action'], 'redeem_support_access');
        expect(request.headers['Authorization'], 'Bearer device-license');
        authorized = jsonDecode(request.body)['password'] == 'approved-password';
        return http.Response(jsonEncode({'success': authorized}), authorized ? 200 : 401);
      }))),
    ]);
    addTearDown(container.dispose);
    final auth = container.read(authServiceProvider);
    await tester.runAsync(() async {
      await container.read(secureStorageProvider).write(key: 'nexapos.license.activationToken', value: 'device-license');
      await auth.createUser(name: 'Cashier One', username: 'cashier-one', password: 'old-password', role: UserRole.cashier);
    });
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: const MaterialApp(home: Scaffold(body: SupportRecoveryDialog()))));
    await tester.pumpAndSettle();
    expect(find.text('Cashier One (cashier-one)'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'One-time support password'), 'approved-password');
    await tester.runAsync(() async {
      await tester.tap(find.text('Authorize recovery'));
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.pump();
        if (find.byType(DropdownButtonFormField<User>).evaluate().isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(authorized, isTrue);
    expect(find.byType(DropdownButtonFormField<User>), findsOneWidget,
      reason: tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).join(' | '));
    await tester.tap(find.byType(DropdownButtonFormField<User>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cashier One (cashier-one)').last);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final account = (await auth.getAllUsers()).single;
      await auth.updateUser(id: account.id, name: account.name, username: account.username,
        role: UserRole.manager);
    });
    await tester.enterText(find.widgetWithText(TextField, 'New password (at least 8 characters)'), 'new-password');
    await tester.enterText(find.widgetWithText(TextField, 'Confirm password'), 'new-password');
    await tester.runAsync(() async {
      await tester.tap(find.text('Reset password'));
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.pump();
        if (find.text('Done').evaluate().isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('Done. Sign in as cashier-one using the new password.'), findsOneWidget);
    final result = await tester.runAsync(() => auth.login('cashier-one', 'new-password'));
    expect(result!.when(ok: (user) => user.role, failure: (_) => null), UserRole.manager);
  });
}
