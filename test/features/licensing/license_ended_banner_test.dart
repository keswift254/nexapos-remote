import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/core/secure_storage_provider.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import 'package:nexapos_mobile/features/licensing/activation_screen.dart';

import '../../support/fake_secure_storage.dart';

const _lastEndKey = 'nexapos.license.lastEnd';

void main() {
  late ProviderContainer container;

  Future<void> openActivationScreen(WidgetTester tester, {LicenseEnd? end}) async {
    installFakeSecureStorage();
    container = ProviderContainer();
    if (end != null) {
      await container
          .read(secureStorageProvider)
          .write(key: _lastEndKey, value: jsonEncode(end.toJson()));
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
  }

  testWidgets('a device that was never licensed sees the plain activation screen', (tester) async {
    await openActivationScreen(tester);

    expect(find.text('Activate NexaPOS'), findsOneWidget);
    expect(find.textContaining('Your license'), findsNothing);
    expect(find.textContaining('date or time'), findsNothing);

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
}
