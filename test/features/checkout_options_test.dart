import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide User;
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
    'checkout offers Cash, M-Pesa Prompt and M-Pesa Till/Paybill, and ignores retired methods',
    (tester) async {
      // CartNotifier now persists every change (see cart_notifier.dart) -
      // an in-memory database keeps this test's several rapid-fire
      // setPaymentMethod() calls (with no pump() between them) from ever
      // touching the real default database, whose connection setup can
      // still be mid-flight (and its Timer still pending) when the test
      // ends and disposes the widget tree.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(_Session.new),
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CartScreen()),
        ),
      );
      expect(find.widgetWithText(ChoiceChip, 'Cash'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'M-Pesa Prompt'), findsOneWidget);
      // "M-Pesa Till/Paybill" (1.0.85): the customer paid the shop's own till or paybill, checked with the shop's server.
      expect(find.widgetWithText(ChoiceChip, 'M-Pesa Till/Paybill'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(5), reason: 'Retail, Wholesale and the three payment methods - nothing else');
      expect(find.widgetWithText(ChoiceChip, 'IntaSend'), findsNothing);
      expect(find.text('M-Pesa'), findsNothing);
      await tester.ensureVisible(find.text('M-Pesa Prompt'));
      await tester.tap(find.text('M-Pesa Prompt'));
      await tester.pump();
      expect(container.read(cartProvider).paymentMethod, 'paystack');
      // the retired methods cannot be chosen any more
      container.read(cartProvider.notifier).setPaymentMethod('mpesa');
      expect(container.read(cartProvider).paymentMethod, 'paystack');
      container.read(cartProvider.notifier).setPaymentMethod('intasend');
      expect(container.read(cartProvider).paymentMethod, 'paystack');
      // M-Pesa Till/Paybill can
      container.read(cartProvider.notifier).setPaymentMethod('mpesa_manual');
      expect(container.read(cartProvider).paymentMethod, 'mpesa_manual');
    },
  );
}
