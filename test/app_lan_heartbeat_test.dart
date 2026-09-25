import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/app.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/secure_storage_provider.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/services/lan_sync_service.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import 'package:nexapos_mobile/features/settings/payment_settings_screen.dart'
    show currentPaymentCredentialsProvider;

import 'support/fake_secure_storage.dart';

const _credentials = PaystackCredentials(
  baseUrl: 'https://test.example/index.php', apiKey: 'test-api-key', currency: 'KES', defaultEmail: '',
);

/// Counts how often the app tells the LAN about itself.
class _CountingLan implements LanSyncService {
  int announcements = 0;
  Completer<void>? holdUp;

  @override
  Future<void> syncNow() async {
    announcements++;
    final blocked = holdUp;
    if (blocked != null) await blocked.future;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  late _CountingLan lan;
  late ProviderContainer container;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    installFakeSecureStorage();
    lan = _CountingLan();
  });

  Future<void> openApp(WidgetTester tester, {required bool licensed, bool joined = false}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) {
            final db = AppDatabase(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
          hasCachedLicenseProvider.overrideWith((ref) async => licensed),
          currentPaymentCredentialsProvider.overrideWith((ref) async => _credentials),
          lanSyncServiceProvider.overrideWithValue(lan),
        ],
        child: const NexaPosApp(),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(tester.element(find.byType(NexaPosApp)));
    if (joined) {
      // A device that joined a shop (and, in this test, is locked out of it).
      await tester.runAsync(() => container.read(secureStorageProvider).write(
        key: 'nexapos.license.shopMembership',
        value: jsonEncode({'shopId': 7, 'deviceId': 'd', 'verifiedAt': DateTime.utc(2020).toIso8601String(), 'blocked': false}),
      ));
    }
  }

  Future<void> pass(WidgetTester tester, Duration total) async {
    for (var elapsed = Duration.zero; elapsed < total; elapsed += const Duration(seconds: 1)) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('a licensed device tells the LAN about itself every 2 seconds', (tester) async {
    await openApp(tester, licensed: true);
    final before = lan.announcements;

    await pass(tester, const Duration(seconds: 10));

    expect(lan.announcements - before, 5, reason: 'once per 2 seconds, on its own timer');
    await close(tester);
  });

  testWidgets('it keeps going, at that pace, for as long as the app is open', (tester) async {
    await openApp(tester, licensed: true);
    final before = lan.announcements;

    await pass(tester, const Duration(seconds: 60));

    expect(lan.announcements - before, 30);
    await close(tester);
  });

  testWidgets('a slow announcement is not piled up on: one at a time, then carries on', (tester) async {
    lan.holdUp = Completer<void>();
    await openApp(tester, licensed: true);
    final before = lan.announcements;

    await pass(tester, const Duration(seconds: 10));
    expect(lan.announcements - before, 1, reason: 'the first is still in flight, so no more are started');

    lan.holdUp!.complete();
    lan.holdUp = null;
    await pass(tester, const Duration(seconds: 6));
    expect(lan.announcements - before, greaterThanOrEqualTo(3), reason: 'and it picks up again');
    await close(tester);
  });

  testWidgets('a device with no licence and no shop membership stays quiet', (tester) async {
    await openApp(tester, licensed: false);

    await pass(tester, const Duration(seconds: 10));

    expect(lan.announcements, 0);
    await close(tester);
  });

  testWidgets('a joined device that is locked out still announces, so a renewal can reach it with no internet', (tester) async {
    await openApp(tester, licensed: false, joined: true);
    final before = lan.announcements;

    await pass(tester, const Duration(seconds: 10));

    expect(lan.announcements - before, 5);
    await close(tester);
  });

  testWidgets('closing the app stops it', (tester) async {
    await openApp(tester, licensed: true);
    await pass(tester, const Duration(seconds: 4));
    await close(tester);
    final atClose = lan.announcements;

    await tester.pump(const Duration(seconds: 10));

    expect(lan.announcements, atClose);
  });
}
