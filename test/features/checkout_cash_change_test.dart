import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide User;
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/features/checkout/cart_notifier.dart';
import 'package:nexapos_mobile/features/checkout/cart_screen.dart';

// A real logged-in user, unlike checkout_options_test.dart's null-user
// stand-in - "Complete Sale" is disabled by both userId == null and a
// cash shortfall, so testing the shortfall-specific gating in isolation
// needs a session where userId is never the reason it's disabled.
class _Session extends SessionNotifier {
  @override
  User? build() => const User(
        id: 'cashier-1',
        role: UserRole.cashier,
        name: 'Cashier',
        username: 'cashier',
        passwordHash: 'irrelevant-for-this-test',
        status: 'active',
      );
}

void main() {
  testWidgets(
    'cash payment shows a live change-due (or still-owed) calculation, hidden for M-Pesa',
    (tester) async {
      // The cash-received field sits below the fold once a cart item is
      // present (unlike checkout_options_test's empty cart) - a
      // sliver-backed ListView never builds children outside the
      // viewport+cache extent, so a default-sized surface would leave it
      // genuinely absent from the tree, not just unscrolled-to.
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // CartNotifier now persists every change (see cart_notifier.dart) -
      // an in-memory database keeps that off the real default database,
      // whose connection setup can still be mid-flight (and its Timer
      // still pending) when the test ends and disposes the widget tree.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(_Session.new),
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);
      container.read(cartProvider.notifier).addManualItem(
        name: 'Test item',
        quantity: 1,
        price: Money.fromMajor(300),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CartScreen()),
        ),
      );

      // Cash is the default payment method - the field should already be
      // visible with nothing entered, and no change row yet.
      expect(find.text('Cash received (optional)'), findsOneWidget);
      expect(find.text('Change due'), findsNothing);
      expect(find.text('Still owed'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Cash received (optional)'),
        '500',
      );
      await tester.pump();
      expect(find.text('Change due'), findsOneWidget);
      expect(find.text('KES 200.00'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Cash received (optional)'),
        '150',
      );
      await tester.pump();
      expect(find.text('Still owed'), findsOneWidget);
      expect(find.text('Change due'), findsNothing);
      expect(find.text('KES 150.00'), findsOneWidget);

      // A genuine shortfall blocks "Complete Sale" outright and offers
      // sending an M-Pesa prompt for exactly the remaining balance.
      expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Complete Sale')).onPressed,
        isNull,
      );
      expect(find.text('Send M-Pesa prompt for KES 150.00'), findsOneWidget);

      // Entering enough cash clears the block and the prompt offer.
      await tester.enterText(
        find.widgetWithText(TextField, 'Cash received (optional)'),
        '300',
      );
      await tester.pump();
      expect(find.text('Still owed'), findsNothing);
      expect(find.textContaining('Send M-Pesa prompt'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Complete Sale')).onPressed,
        isNotNull,
      );

      // Back to a shortfall for the next assertion (M-Pesa hides the
      // whole cash section, including any shortfall state).
      await tester.enterText(
        find.widgetWithText(TextField, 'Cash received (optional)'),
        '150',
      );
      await tester.pump();

      // Switching to M-Pesa hides the whole cash section entirely -
      // this calculator is cash-only.
      await tester.ensureVisible(find.text('M-Pesa Prompt'));
      await tester.tap(find.text('M-Pesa Prompt'));
      await tester.pump();
      expect(find.text('Cash received (optional)'), findsNothing);
      expect(find.text('Still owed'), findsNothing);
    },
  );

  testWidgets(
    'entering exactly 0 is treated as "nothing entered", not a shortfall',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(_Session.new),
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);
      container.read(cartProvider.notifier).addManualItem(
        name: 'Test item',
        quantity: 1,
        price: Money.fromMajor(15),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CartScreen()),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Cash received (optional)'),
        '0',
      );
      await tester.pump();

      expect(find.text('Still owed'), findsNothing);
      expect(find.text('Change due'), findsNothing);
      expect(find.textContaining('Send M-Pesa prompt'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Complete Sale')).onPressed,
        isNotNull,
      );
    },
  );
}
