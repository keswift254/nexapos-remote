import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/features/checkout/cart_notifier.dart';
import 'package:nexapos_mobile/features/checkout/cart_screen.dart';

class _Session extends SessionNotifier {
  @override
  User? build() => null;
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

      final container = ProviderContainer(
        overrides: [sessionProvider.overrideWith(_Session.new)],
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

      // Switching to M-Pesa hides the whole cash section entirely -
      // this calculator is cash-only.
      await tester.ensureVisible(find.text('M-Pesa Prompt'));
      await tester.tap(find.text('M-Pesa Prompt'));
      await tester.pump();
      expect(find.text('Cash received (optional)'), findsNothing);
      expect(find.text('Still owed'), findsNothing);
    },
  );
}
