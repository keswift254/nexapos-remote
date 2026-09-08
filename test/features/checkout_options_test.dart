import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    'checkout offers only Cash and M-Pesa Prompt and ignores retired methods',
    (tester) async {
      final container = ProviderContainer(
        overrides: [sessionProvider.overrideWith(_Session.new)],
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
      expect(find.text('M-Pesa'), findsNothing);
      expect(find.text('M-Pesa Till'), findsNothing);
      await tester.ensureVisible(find.text('M-Pesa Prompt'));
      await tester.tap(find.text('M-Pesa Prompt'));
      await tester.pump();
      expect(container.read(cartProvider).paymentMethod, 'paystack');
      container.read(cartProvider.notifier).setPaymentMethod('mpesa');
      expect(container.read(cartProvider).paymentMethod, 'paystack');
      container.read(cartProvider.notifier).setPaymentMethod('mpesa_manual');
      expect(container.read(cartProvider).paymentMethod, 'paystack');
    },
  );
}
