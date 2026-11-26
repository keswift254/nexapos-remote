import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/app.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide User;
import 'package:nexapos_mobile/data/payments/sms_forwarding.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import 'package:nexapos_mobile/features/settings/sms_forwarding_screen.dart';

import '../../support/fake_secure_storage.dart';

/// A phone that only gets the till's M-Pesa messages needs no shop of its own: from the first screen of a NexaPOS that
/// was never activated, "This phone only passes on M-Pesa messages" opens the passing-on screen - and nothing else of
/// the shop opens without activating.
class _Forwarding implements SmsForwarding {
  @override
  Future<SmsForwardingStatus> status() async => const SmsForwardingStatus(enabled: false, permission: false);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('a phone with no shop: the first screen offers passing on, and only that opens without activating',
      (tester) async {
    installFakeSecureStorage();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
      hasCachedLicenseProvider.overrideWith((ref) async => false),
      smsForwardingProvider.overrideWithValue(_Forwarding()),
    ]);
    final router = container.read(routerProvider);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    String path() => router.routeInformationProvider.value.uri.path;

    expect(path(), '/activate');
    final link = find.byKey(const Key('activation-sms-forwarding'));
    await tester.scrollUntilVisible(link, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.byType(SmsForwardingScreen), findsOneWidget);

    router.go('/sms-forwarding');
    await tester.pumpAndSettle();
    expect(path(), '/sms-forwarding', reason: 'allowed without a shop');
    for (final shopPage in ['/', '/reports', '/till-phone', '/products']) {
      router.go(shopPage);
      await tester.pumpAndSettle();
      expect(path(), '/activate', reason: '$shopPage still needs activating');
    }

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await db.close();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('not an Android phone: the first screen does not offer it', (tester) async {
    installFakeSecureStorage();
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
      hasCachedLicenseProvider.overrideWith((ref) async => false),
    ]);
    final router = container.read(routerProvider);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activation-sms-forwarding')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await db.close();
    debugDefaultTargetPlatformOverride = null;
  });
}
