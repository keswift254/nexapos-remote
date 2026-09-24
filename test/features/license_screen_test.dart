import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/secure_storage_provider.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/data/licensing/license_gateway.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import 'package:nexapos_mobile/features/settings/license_screen.dart';

import '../support/fake_secure_storage.dart';

const _tokenKey = 'nexapos.license.activationToken';
const _validUntilKey = 'nexapos.license.validUntil';
const _membershipKey = 'nexapos.license.shopMembership';

http.Response _verify({required bool valid, String? validUntil}) => http.Response(
  jsonEncode({'success': true, 'valid': valid, 'valid_until': validUntil}),
  200,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FixedClock clock;
  late http.Response Function() serverAnswer;
  late ProviderContainer container;
  late AppDatabase db;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Stores what a device holds after activating, then opens the screen.
  Future<void> openLicenseScreen(
    WidgetTester tester, {
    String? savedValidUntil,
    bool withToken = true,
    Map<String, dynamic>? membership,
  }) async {
    installFakeSecureStorage();
    clock = FixedClock(DateTime.utc(2026, 1, 1));
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
      clockProvider.overrideWith((ref) => clock),
      licenseGatewayProvider.overrideWith(
        (ref) => LicenseGateway(MockClient((request) async => serverAnswer())),
      ),
    ]);
    final storage = container.read(secureStorageProvider);
    if (withToken) await storage.write(key: _tokenKey, value: 'a' * 64);
    if (savedValidUntil != null) {
      await storage.write(key: _validUntilKey, value: savedValidUntil);
    }
    if (membership != null) {
      await storage.write(key: _membershipKey, value: jsonEncode(membership));
    }
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: LicenseScreen()),
    ));
    await settle(tester);
  }

  Future<void> closeScreen(WidgetTester tester) async {
    // Unmounting cancels the screen's one-second ticker.
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await db.close();
  }

  testWidgets('an active license shows its end date and a live countdown', (tester) async {
    serverAnswer = () => _verify(valid: true, validUntil: '2026-01-31 04:00:05');
    await openLicenseScreen(tester, savedValidUntil: '2026-01-31T04:00:05.000Z');

    expect(find.text('License'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Time remaining'), findsOneWidget);
    // 30 days, 4 hours, 0 minutes, 5 seconds from the fixed clock.
    expect(find.text('30'), findsOneWidget);
    expect(find.text('04'), findsOneWidget);
    expect(find.text('00'), findsOneWidget);
    expect(find.text('05'), findsOneWidget);
    expect(find.text('Days'), findsOneWidget);
    expect(find.text('Seconds'), findsOneWidget);
    expect(find.text('Confirmed with the license server just now.'), findsOneWidget);

    clock.advance(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('05'), findsNothing);
    expect(find.text('04'), findsNWidgets(2)); // hours and the seconds that just ticked

    await closeScreen(tester);
  });

  testWidgets('a license that never expires says so, with no countdown', (tester) async {
    serverAnswer = () => _verify(valid: true);
    await openLicenseScreen(tester);

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('This license never expires.'), findsOneWidget);
    expect(find.text('Time remaining'), findsNothing);

    await closeScreen(tester);
  });

  testWidgets('a revoked license is shown as revoked', (tester) async {
    serverAnswer = () => _verify(valid: false, validUntil: '2026-01-31 00:00:00');
    await openLicenseScreen(tester, savedValidUntil: '2026-01-31T00:00:00.000Z');

    expect(find.text('Revoked'), findsOneWidget);
    expect(find.textContaining('has been revoked'), findsOneWidget);
    expect(find.text('Time remaining'), findsNothing);

    await closeScreen(tester);
  });

  testWidgets('an expired license is shown as expired, with when it ran out', (tester) async {
    serverAnswer = () => _verify(valid: false, validUntil: '2025-12-20 09:30:00');
    await openLicenseScreen(tester, savedValidUntil: '2025-12-20T09:30:00.000Z');

    expect(find.text('Expired'), findsOneWidget);
    expect(find.textContaining('ran out on'), findsOneWidget);
    expect(find.text('Time remaining'), findsNothing);

    await closeScreen(tester);
  });

  testWidgets('offline: shows the saved answer and says it could not be confirmed', (tester) async {
    serverAnswer = () => throw const SocketException('no internet');
    await openLicenseScreen(tester, savedValidUntil: '2026-01-31T04:00:05.000Z');

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.textContaining('Could not reach the license server'), findsOneWidget);

    await closeScreen(tester);
  });

  testWidgets('the countdown reaching zero while the screen is open flips it to Expired', (tester) async {
    serverAnswer = () => throw const SocketException('no internet');
    await openLicenseScreen(tester, savedValidUntil: '2026-01-01T00:00:03.000Z');
    expect(find.text('Active'), findsOneWidget);

    clock.advance(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('Active'), findsNothing);
    expect(find.text('Time remaining'), findsNothing);

    await closeScreen(tester);
  });

  testWidgets('a joined device explains it has no license and counts down to its next check', (tester) async {
    serverAnswer = () => throw StateError('a joined device must not ask the license server');
    await openLicenseScreen(
      tester,
      withToken: false,
      membership: {
        'shopId': 7,
        'deviceId': 'd',
        // Confirmed 20 hours before the fixed clock: 4 hours left of the 24.
        'verifiedAt': DateTime.utc(2025, 12, 31, 4).toIso8601String(),
        'blocked': false,
      },
    );

    expect(find.text('Joined device'), findsOneWidget);
    expect(find.textContaining('no license of its own'), findsOneWidget);
    expect(find.text('Time left before it must reconnect'), findsOneWidget);
    expect(find.text('04'), findsOneWidget);

    await closeScreen(tester);
  });

  testWidgets('shows this device\'s ID, for support and for unrevoking', (tester) async {
    serverAnswer = () => _verify(valid: true);
    await openLicenseScreen(tester);

    final deviceId = (await tester.runAsync(() => container.read(syncMetadataProvider).deviceId()))!;
    await tester.pump();

    expect(find.text('Device ID'), findsOneWidget);
    expect(find.text(deviceId), findsOneWidget);
    expect(find.byTooltip('Copy device ID'), findsOneWidget);

    await closeScreen(tester);
  });
}
