import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/app.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Sale;
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/entities/sale.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import 'package:nexapos_mobile/domain/services/pending_sales_notifier.dart';
import 'package:nexapos_mobile/features/settings/payment_settings_screen.dart'
    show currentPaymentCredentialsProvider;

import 'support/fake_secure_storage.dart';

const _credentials = PaystackCredentials(
  baseUrl: 'https://test.example/index.php', apiKey: 'test-api-key', currency: 'KES', defaultEmail: '',
);

final _unpaid = Sale(
  id: 'sale-1',
  saleNumber: 'S-0001',
  userId: 'cashier-1',
  customerName: 'Walk-in',
  saleType: 'retail',
  paymentMethod: 'paystack',
  subtotal: const Money(10000),
  discount: const Money.zero(),
  total: const Money(10000),
  status: 'pending',
  createdAt: DateTime(2026, 11, 3, 12),
);

/// Starts out knowing the given pending sales, and counts how often it is asked to look again.
class _CountingPendingSales extends PendingPaystackSalesNotifier {
  _CountingPendingSales(this.initial);

  final List<Sale> initial;
  int reconciles = 0;
  Completer<void>? holdUp;

  @override
  List<Sale> build() => initial;

  @override
  Future<void> reconcile() async {
    reconciles++;
    final blocked = holdUp;
    if (blocked != null) await blocked.future;
  }
}

void main() {
  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    installFakeSecureStorage();
  });

  Future<void> openApp(WidgetTester tester, _CountingPendingSales pending) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) {
            final db = AppDatabase(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
          hasCachedLicenseProvider.overrideWith((ref) async => true),
          currentPaymentCredentialsProvider.overrideWith((ref) async => _credentials),
          pendingPaystackSalesProvider.overrideWith(() => pending),
        ],
        child: const NexaPosApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pass(WidgetTester tester, Duration total) async {
    for (var elapsed = Duration.zero; elapsed < total; elapsed += const Duration(seconds: 1)) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('with nothing unpaid it never goes looking again after the first check at start', (tester) async {
    final pending = _CountingPendingSales(const []);
    await openApp(tester, pending);
    final atStart = pending.reconciles;

    await pass(tester, const Duration(seconds: 60));

    expect(pending.reconciles, atStart);
    await close(tester);
  });

  testWidgets('an unpaid online payment is asked about every 10 seconds, wherever the cashier is', (tester) async {
    final pending = _CountingPendingSales([_unpaid]);
    await openApp(tester, pending);
    final atStart = pending.reconciles;

    await pass(tester, const Duration(seconds: 30));

    expect(pending.reconciles - atStart, 3);
    await close(tester);
  });

  testWidgets('coming back to the app asks straight away instead of waiting for the next tick', (tester) async {
    final pending = _CountingPendingSales([_unpaid]);
    await openApp(tester, pending);
    final atStart = pending.reconciles;

    // The order a real page or window goes through when it is hidden and shown again.
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();

    expect(pending.reconciles - atStart, 1);
    await close(tester);
  });

  testWidgets('a slow check is not piled up on', (tester) async {
    final pending = _CountingPendingSales([_unpaid]);
    await openApp(tester, pending);
    final atStart = pending.reconciles;
    pending.holdUp = Completer<void>();

    await pass(tester, const Duration(seconds: 45));
    expect(pending.reconciles - atStart, 1, reason: 'the first check is still running');

    pending.holdUp!.complete();
    await pass(tester, const Duration(seconds: 12));
    expect(pending.reconciles - atStart, 2, reason: 'and it carries on once that one finishes');
    await close(tester);
  });
}
