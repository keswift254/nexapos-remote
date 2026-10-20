import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/features/support/support_photos.dart';

/// A real 1x1 PNG (67 bytes).
final _tinyPng = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  group('SupportPhotoController', () {
    test('a copied picture is attached and reported as consumed', () async {
      final controller = SupportPhotoController(
        clipboardImage: () async => _tinyPng,
      );
      expect(await controller.pasteImage(), isTrue);
      expect(controller.photos, hasLength(1));
      expect(controller.error, isNull);
    });

    test(
      'no picture on the clipboard: nothing attached, text pasting may go on',
      () async {
        final controller = SupportPhotoController(
          clipboardImage: () async => null,
        );
        expect(await controller.pasteImage(), isFalse);
        expect(controller.photos, isEmpty);
      },
    );

    test('an unreadable clipboard never blocks text pasting', () async {
      final controller = SupportPhotoController(
        clipboardImage: () async => throw PlatformException(code: 'denied'),
      );
      expect(await controller.pasteImage(), isFalse);
      expect(controller.error, isNull);
    });

    test('a picture over 2 MB is refused with a message, and still counts as consumed', () async {
      final controller = SupportPhotoController(
        clipboardImage: () async => Uint8List(2 * 1024 * 1024 + 1)..[0] = 1,
      );
      expect(await controller.pasteImage(), isTrue);
      expect(controller.photos, isEmpty);
      expect(controller.error, 'Each photo must be 2 MB or smaller.');
    });

    test('at most four photos per message', () async {
      final controller = SupportPhotoController(
        clipboardImage: () async => _tinyPng,
      );
      for (var i = 0; i < 4; i++) {
        expect(await controller.pasteImage(), isTrue);
      }
      expect(await controller.pasteImage(), isTrue);
      expect(controller.photos, hasLength(4));
      expect(controller.error, 'Attach up to 4 photos per message.');
    });

    test('photos together may not pass 4 MB', () async {
      final big = Uint8List(1800 * 1024)..[0] = 1;
      final controller = SupportPhotoController(
        clipboardImage: () async => big,
      );
      await controller.pasteImage();
      await controller.pasteImage();
      await controller.pasteImage();
      expect(controller.photos, hasLength(2));
      expect(controller.error, 'Photos must total 4 MB or less.');
    });

    test(
      'a picture from a phone keyboard is attached; remove and clear work',
      () {
        final controller = SupportPhotoController();
        controller.addFromKeyboard(_tinyPng);
        controller.addFromKeyboard(null);
        expect(controller.photos, hasLength(1));
        controller.addFromKeyboard(_tinyPng);
        controller.removeAt(0);
        expect(controller.photos, hasLength(1));
        controller.removeAt(9);
        expect(controller.photos, hasLength(1));
        controller.clear();
        expect(controller.isEmpty, isTrue);
      },
    );

    test(
      'photos is a copy, so a sent message keeps its pictures after clear()',
      () async {
        final controller = SupportPhotoController(
          clipboardImage: () async => _tinyPng,
        );
        await controller.pasteImage();
        final sent = controller.photos;
        controller.clear();
        expect(sent, hasLength(1));
        expect(controller.photos, isEmpty);
      },
    );
  });

  group('the message box', () {
    late SupportPhotoController controller;
    late TextEditingController text;

    Future<void> show(
      WidgetTester tester, {
      Future<Uint8List?> Function()? clipboardImage,
      bool enabled = true,
      String? clipboardText,
    }) async {
      controller = SupportPhotoController(
        clipboardImage: clipboardImage ?? () async => null,
      );
      text = TextEditingController();
      addTearDown(controller.dispose);
      addTearDown(text.dispose);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') {
            return clipboardText == null ? null : {'text': clipboardText};
          }
          if (call.method == 'Clipboard.hasStrings') {
            return {'value': clipboardText != null};
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SupportPhotoStrip(controller: controller, enabled: enabled),
                SupportPasteImageShortcut(
                  controller: controller,
                  enabled: enabled,
                  child: TextField(
                    controller: text,
                    decoration: InputDecoration(
                      hintText: 'Reply to this ticket…',
                      border: const OutlineInputBorder(),
                      prefixIcon: SupportAttachButton(
                        controller: controller,
                        enabled: enabled,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
    }

    Future<void> pressCtrlV(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    testWidgets('one "+" button replaces the two text buttons', (tester) async {
      await show(tester);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('Add photos'), findsNothing);
      expect(find.text('Paste photo'), findsNothing);
      expect(
        find.byTooltip('Add photos (or copy a picture and press Ctrl+V)'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Ctrl+V attaches a copied picture, shows it, and leaves the text alone',
      (tester) async {
        await show(
          tester,
          clipboardImage: () async => _tinyPng,
          clipboardText: 'should not be pasted',
        );
        await pressCtrlV(tester);
        expect(controller.photos, hasLength(1));
        expect(text.text, isEmpty, reason: 'the picture was pasted, not text');
        expect(find.byType(Image), findsOneWidget);
        expect(find.byTooltip('Remove photo'), findsOneWidget);
      },
    );

    testWidgets('Ctrl+V with no picture still pastes text normally', (
      tester,
    ) async {
      await show(tester, clipboardText: 'hello from the clipboard');
      await pressCtrlV(tester);
      expect(controller.photos, isEmpty);
      expect(text.text, 'hello from the clipboard');
    });

    testWidgets(
      'Ctrl+V while sending is disabled does not attach, but text still pastes',
      (tester) async {
        await show(
          tester,
          enabled: false,
          clipboardImage: () async => _tinyPng,
          clipboardText: 'plain text',
        );
        await pressCtrlV(tester);
        expect(controller.photos, isEmpty);
        expect(text.text, 'plain text');
      },
    );

    testWidgets('the remove button takes a photo off again', (tester) async {
      await show(tester, clipboardImage: () async => _tinyPng);
      await pressCtrlV(tester);
      await tester.tap(find.byTooltip('Remove photo'));
      await tester.pump();
      expect(controller.photos, isEmpty);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a refused picture explains why, in the strip above the box', (
      tester,
    ) async {
      await show(
        tester,
        clipboardImage: () async => Uint8List(2 * 1024 * 1024 + 1)..[0] = 1,
      );
      await pressCtrlV(tester);
      expect(find.text('Each photo must be 2 MB or smaller.'), findsOneWidget);
      expect(controller.photos, isEmpty);
    });

    testWidgets('the "+" button is disabled while sending', (tester) async {
      await show(tester, enabled: false);
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add),
      );
      expect(button.onPressed, isNull);
    });
  });
}
