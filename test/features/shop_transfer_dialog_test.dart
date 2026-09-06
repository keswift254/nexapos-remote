import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/features/products/shop_transfer_dialog.dart';

void main() {
  for (final size in [const Size(360, 640), const Size(1280, 800)]) {
    testWidgets('transfer window fits $size and exposes backup controls', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: ShopTransferDialog())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Import all data from another POS'), findsOneWidget);
      expect(find.text('Inspect source'), findsOneWidget);
      await tester.ensureVisible(find.text('Create backup'));
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithIcon(IconButton, Icons.close));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
