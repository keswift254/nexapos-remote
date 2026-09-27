import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/adaptive_pair.dart';

void main() {
  for (final width in [320.0, 800.0, 1920.0]) {
    testWidgets('dashboard cards fit a $width pixel screen', (tester) async {
      tester.view.physicalSize = Size(width, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdaptivePair(
              child: Row(
                children: [
                  Expanded(child: Text('Sales today', key: Key('left'))),
                  SizedBox(width: 12),
                  Expanded(child: Text('Stock value', key: Key('right'))),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final left = tester.getTopLeft(find.byKey(const Key('left')));
      final right = tester.getTopLeft(find.byKey(const Key('right')));
      if (width < 560) {
        expect(right.dy, greaterThan(left.dy));
      } else {
        expect(right.dx, greaterThan(left.dx));
      }
    });
  }
}
