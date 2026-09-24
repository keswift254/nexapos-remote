import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/secure_storage_provider.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import 'package:nexapos_mobile/features/licensing/activation_screen.dart';

import '../../support/fake_secure_storage.dart';

const _lastEndKey = 'nexapos.license.lastEnd';
const _membershipKey = 'nexapos.license.shopMembership';
const _joinedTitle = 'Connect to the internet to confirm your shop access';

void main() {
  late ProviderContainer container;
  late FixedClock clock;
  late AppDatabase db;

  /// [joinedConfirmedAgo] makes this a device that joined a shop and last
  /// confirmed the membership that long before the (fixed) current time.
  Future<void> openActivationScreen(
    WidgetTester tester, {
    LicenseEnd? end,
    Duration? joinedConfirmedAgo,
  }) async {
    installFakeSecureStorage();
    clock = FixedClock(DateTime.utc(2026, 1, 10, 12));
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
      clockProvider.overrideWith((ref) => clock),
    ]);
    final storage = container.read(secureStorageProvider);
    if (end != null) {
      await storage.write(key: _lastEndKey, value: jsonEncode(end.toJson()));
    }
    if (joinedConfirmedAgo != null) {
      final deviceId = (await tester.runAsync(() => container.read(syncMetadataProvider).deviceId()))!;
      await storage.write(
        key: _membershipKey,
        value: jsonEncode({
          'shopId': 7,
          'deviceId': deviceId,
          'verifiedAt': clock.now().subtract(joinedConfirmedAgo).toIso8601String(),
          'blocked': false,
        }),
      );
    }
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ActivationScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await db.close();
  }

  testWidgets('a device that was never licensed sees the plain activation screen', (tester) async {
    await openActivationScreen(tester);

    expect(find.text('Activate NexaPOS'), findsOneWidget);
    expect(find.textContaining('Your license'), findsNothing);
    expect(find.textContaining('date or time'), findsNothing);
    expect(find.text(_joinedTitle), findsNothing);

    await close(tester);
  });

  testWidgets('an expired license says so, when it ran out, and what to do', (tester) async {
    await openActivationScreen(
      tester,
      end: LicenseEnd(
        reason: LicenseEndReason.expired,
        validUntil: DateTime.utc(2025, 12, 20, 9, 30),
        noticedAt: DateTime.utc(2025, 12, 20, 9, 31),
      ),
    );

    expect(find.text('Your license has expired'), findsOneWidget);
    expect(find.textContaining('It ran out on'), findsOneWidget);
    expect(find.textContaining('2025'), findsOneWidget);
    expect(find.textContaining('enter your license key below'), findsOneWidget);
    // The way back in is still right there.
    expect(find.text('Activate NexaPOS'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Activate'), findsOneWidget);

    await close(tester);
  });

  testWidgets('an expired license with no recorded end date still explains itself', (tester) async {
    await openActivationScreen(tester, end: const LicenseEnd(reason: LicenseEndReason.expired));

    expect(find.text('Your license has expired'), findsOneWidget);
    expect(find.textContaining('It ran out on'), findsNothing);
    expect(find.textContaining('Contact NexaPOS to renew it'), findsOneWidget);

    await close(tester);
  });

  testWidgets('a revoked license says so, and mentions that a restored key works again', (tester) async {
    await openActivationScreen(tester, end: const LicenseEnd(reason: LicenseEndReason.revoked));

    expect(find.text('Your license was revoked'), findsOneWidget);
    expect(find.textContaining('If it has been restored'), findsOneWidget);
    expect(find.text('Your license has expired'), findsNothing);

    await close(tester);
  });

  testWidgets('a joined device whose shop license ran out says so, and that the renewal arrives by itself', (tester) async {
    await openActivationScreen(tester, end: const LicenseEnd(reason: LicenseEndReason.shopLicenseExpired));

    expect(find.text("This shop's license has expired"), findsOneWidget);
    expect(find.textContaining('Ask the shop owner to renew it'), findsOneWidget);
    expect(find.textContaining('reopens by itself'), findsOneWidget);
    expect(find.text('Your license has expired'), findsNothing);

    await close(tester);
  });

  testWidgets('a set-back clock is explained as that, not as an expired license', (tester) async {
    await openActivationScreen(tester, end: const LicenseEnd(reason: LicenseEndReason.clockSetBack));

    expect(find.text("This device's date or time looks wrong"), findsOneWidget);
    expect(find.textContaining('Correct the date and time'), findsOneWidget);
    expect(find.text('Your license has expired'), findsNothing);

    await close(tester);
  });

  testWidgets('the notice appears by itself when the app locks while this screen is showing', (tester) async {
    await openActivationScreen(tester);
    expect(find.textContaining('Your license'), findsNothing);

    // What LicenseService does the moment it locks the app: record why, then signal.
    await container
        .read(secureStorageProvider)
        .write(key: _lastEndKey, value: jsonEncode(const LicenseEnd(reason: LicenseEndReason.revoked).toJson()));
    container.read(licenseChangeSignalProvider.notifier).bump();
    await tester.pumpAndSettle();

    expect(find.text('Your license was revoked'), findsOneWidget);

    await close(tester);
  });

  group('a joined device that has not confirmed its shop access lately', () {
    testWidgets('is told to connect, that its data is safe, and that nothing needs entering', (tester) async {
      await openActivationScreen(tester, joinedConfirmedAgo: const Duration(hours: 30));

      expect(find.text(_joinedTitle), findsOneWidget);
      expect(find.textContaining('Your data is safe'), findsOneWidget);
      expect(find.textContaining('every 24 hours'), findsOneWidget);
      expect(find.textContaining('nothing to enter'), findsOneWidget);
      // Not a license problem, so none of the license notices.
      expect(find.textContaining('Your license'), findsNothing);
      // The normal way in is still there.
      expect(find.widgetWithText(FilledButton, 'Activate'), findsOneWidget);
      expect(find.text('Join an existing shop'), findsOneWidget);

      await close(tester);
    });

    testWidgets('sees nothing extra while its access is still fresh', (tester) async {
      await openActivationScreen(tester, joinedConfirmedAgo: const Duration(hours: 1));

      expect(find.text(_joinedTitle), findsNothing);

      await close(tester);
    });

    testWidgets('gets the notice by itself when the 24 hours run out while this screen is open', (tester) async {
      await openActivationScreen(tester, joinedConfirmedAgo: const Duration(hours: 23));
      expect(find.text(_joinedTitle), findsNothing);

      clock.advance(const Duration(hours: 2));
      container.read(licenseChangeSignalProvider.notifier).bump();
      await tester.pumpAndSettle();

      expect(find.text(_joinedTitle), findsOneWidget);

      await close(tester);
    });

    testWidgets('and an ended license notice can show together without clashing', (tester) async {
      await openActivationScreen(
        tester,
        end: const LicenseEnd(reason: LicenseEndReason.expired),
        joinedConfirmedAgo: const Duration(days: 2),
      );

      expect(find.text('Your license has expired'), findsOneWidget);
      expect(find.text(_joinedTitle), findsOneWidget);

      await close(tester);
    });
  });
}
