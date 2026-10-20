import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nexapos_mobile/features/support/support_photos.dart';

/// A real 1x1 PNG (67 bytes).
final _tinyPng = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

const _twoMb = 2 * 1024 * 1024;

/// A Windows-style BMP: bottom-up rows of BGR (24-bit) or BGRA (32-bit) pixels,
/// BI_RGB. The left half is red, the right half blue; with [noise] every pixel is
/// random instead. [alpha] is what the unused fourth byte holds (Windows leaves
/// it 0).
Uint8List _bmp(
  int width,
  int height, {
  int bitsPerPixel = 32,
  int alpha = 0,
  bool noise = false,
}) {
  final rowSize = ((bitsPerPixel * width + 31) ~/ 32) * 4;
  final dataSize = rowSize * height;
  final data = ByteData(54 + dataSize);
  data.setUint8(0, 0x42);
  data.setUint8(1, 0x4D);
  data.setUint32(2, 54 + dataSize, Endian.little);
  data.setUint32(10, 54, Endian.little);
  data.setUint32(14, 40, Endian.little);
  data.setInt32(18, width, Endian.little);
  data.setInt32(22, height, Endian.little);
  data.setUint16(26, 1, Endian.little);
  data.setUint16(28, bitsPerPixel, Endian.little);
  data.setUint32(34, dataSize, Endian.little);
  final random = math.Random(7);
  final bytes = bitsPerPixel ~/ 8;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final at = 54 + y * rowSize + x * bytes;
      final left = x < width / 2;
      data.setUint8(at, noise ? random.nextInt(256) : (left ? 0 : 255)); // B
      data.setUint8(at + 1, noise ? random.nextInt(256) : 0); // G
      data.setUint8(
        at + 2,
        noise ? random.nextInt(256) : (left ? 255 : 0),
      ); // R
      if (bytes == 4) data.setUint8(at + 3, alpha);
    }
  }
  return data.buffer.asUint8List();
}

/// A PNG of random pixels, which does not compress: about 3 bytes per pixel.
Uint8List _noisePng(int width, int height, {int seed = 1}) {
  final random = math.Random(seed);
  final image = img.Image(width: width, height: height);
  for (final pixel in image) {
    pixel.setRgb(random.nextInt(256), random.nextInt(256), random.nextInt(256));
  }
  return Uint8List.fromList(img.encodePng(image, level: 1));
}

bool _isPng(Uint8List b) => b.length > 4 && b[0] == 0x89 && b[1] == 0x50;
bool _isJpeg(Uint8List b) => b.length > 3 && b[0] == 0xFF && b[1] == 0xD8;

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

    test('bytes that are not a picture are refused with a message, and still count as consumed', () async {
      final controller = SupportPhotoController(
        clipboardImage: () async => Uint8List.fromList(List.filled(5000, 1)),
      );
      expect(await controller.pasteImage(), isTrue);
      expect(controller.photos, isEmpty);
      expect(
        controller.error,
        'This picture could not be read. Try a PNG or JPEG photo.',
      );
    });

    test('a Windows clipboard picture (a BMP, which the server refuses) is sent as PNG with its colours intact', () async {
      // The 4th byte of a Windows 32-bit BMP is unused and is 0: treating it
      // as transparency would make the whole picture invisible.
      final controller = SupportPhotoController(
        clipboardImage: () async => _bmp(64, 40, alpha: 0),
      );
      expect(await controller.pasteImage(), isTrue);
      expect(controller.error, isNull);
      final sent = controller.photos.single;
      expect(_isPng(sent), isTrue);
      final decoded = img.decodePng(sent)!;
      expect((decoded.width, decoded.height), (64, 40));
      expect(decoded.getPixel(2, 5).r, 255, reason: 'left half is red');
      expect(decoded.getPixel(2, 5).b, 0);
      expect(decoded.getPixel(60, 5).b, 255, reason: 'right half is blue');
      expect(decoded.getPixel(60, 5).r, 0);
      expect(decoded.hasAlpha, isFalse);
    });

    test('a 24-bit BMP works too', () async {
      final controller = SupportPhotoController(
        clipboardImage: () async => _bmp(33, 21, bitsPerPixel: 24),
      );
      await controller.pasteImage();
      expect(controller.error, isNull);
      expect(_isPng(controller.photos.single), isTrue);
    });

    test(
      'a big screenshot BMP is shrunk to a JPEG under 2 MB and 16 megapixels',
      () async {
        // 3000x1900 random pixels: ~17 MB as a BMP, nothing like it fits as is.
        final bmp = _bmp(3000, 1900, noise: true);
        expect(bmp.length, greaterThan(16 * 1024 * 1024));
        final controller = SupportPhotoController(
          clipboardImage: () async => bmp,
        );
        await controller.pasteImage();
        expect(controller.error, isNull);
        final sent = controller.photos.single;
        expect(_isJpeg(sent), isTrue);
        expect(sent.length, lessThanOrEqualTo(_twoMb));
        final decoded = img.decodeJpg(sent)!;
        expect(
          math.max(decoded.width, decoded.height),
          lessThanOrEqualTo(2560),
        );
        expect(decoded.width * decoded.height, lessThanOrEqualTo(16000000));
        expect(decoded.width / decoded.height, closeTo(3000 / 1900, 0.01));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test('a PNG over 2 MB is made small enough instead of refused', () async {
      final big = _noisePng(1000, 800);
      expect(big.length, greaterThan(_twoMb));
      final controller = SupportPhotoController(
        clipboardImage: () async => big,
      );
      await controller.pasteImage();
      expect(controller.error, isNull);
      expect(controller.photos.single.length, lessThanOrEqualTo(_twoMb));
      expect(img.decodeImage(controller.photos.single), isNotNull);
    });

    test('a PNG that already fits is sent exactly as it was', () async {
      final fits = _noisePng(300, 200);
      expect(fits.length, lessThan(_twoMb));
      final controller = SupportPhotoController(
        clipboardImage: () async => fits,
      );
      await controller.pasteImage();
      expect(controller.photos.single, fits);
    });

    test('a transparent PNG that is too big stays a PNG', () async {
      // Random red, half-see-through every other row: ~1 byte a pixel, so 2.3
      // megapixels is a little over 2 MB.
      final image = img.Image(width: 1800, height: 1300, numChannels: 4);
      final random = math.Random(3);
      for (final pixel in image) {
        pixel.setRgba(random.nextInt(256), 0, 0, pixel.y.isEven ? 255 : 128);
      }
      final big = Uint8List.fromList(img.encodePng(image, level: 1));
      expect(big.length, greaterThan(_twoMb));
      final controller = SupportPhotoController(
        clipboardImage: () async => big,
      );
      await controller.pasteImage();
      expect(controller.error, isNull);
      final sent = controller.photos.single;
      expect(_isPng(sent), isTrue);
      expect(sent.length, lessThanOrEqualTo(_twoMb));
      expect(img.decodePng(sent)!.hasAlpha, isTrue);
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
      // ~1.9 MB each: each fits on its own, three do not fit together.
      final big = _noisePng(790, 790);
      expect(big.length, inInclusiveRange(1800 * 1024, _twoMb));
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
      () async {
        final controller = SupportPhotoController();
        await controller.addFromKeyboard(_tinyPng);
        await controller.addFromKeyboard(null);
        expect(controller.photos, hasLength(1));
        await controller.addFromKeyboard(_tinyPng);
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
        clipboardImage: () async => Uint8List.fromList(List.filled(300, 1)),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      // Trying to read it runs in a background isolate, which needs real time.
      await tester.runAsync(() async {
        for (var i = 0; i < 400 && controller.error == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });
      await tester.pump();
      expect(
        find.text('This picture could not be read. Try a PNG or JPEG photo.'),
        findsOneWidget,
      );
      expect(controller.photos, isEmpty);
    });

    testWidgets('tapping a photo opens a preview; the preview closes again', (
      tester,
    ) async {
      await show(tester, clipboardImage: () async => _tinyPng);
      await pressCtrlV(tester);
      expect(find.byType(InteractiveViewer), findsNothing);

      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(controller.photos, hasLength(1), reason: 'previewing keeps it');
      // Even for a 1-pixel picture the close button is inside the dialog, so it
      // can be tapped (outside it, a tap only hits the dimmed backdrop).
      final dialog = tester.getRect(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Material),
            )
            .first,
      );
      final close = tester.getRect(find.byTooltip('Close photo'));
      expect(dialog.contains(close.center), isTrue);

      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
      expect(controller.photos, hasLength(1));
    });

    testWidgets('the X sits on the photo corner and removes only that photo', (
      tester,
    ) async {
      await show(tester, clipboardImage: () async => _tinyPng);
      await pressCtrlV(tester);
      await pressCtrlV(tester);
      expect(controller.photos, hasLength(2));

      final photoBox = tester.getRect(find.byType(Image).first);
      final xBox = tester.getRect(find.byIcon(Icons.close).first);
      expect(
        (xBox.center - photoBox.topRight).distance,
        lessThan(24),
        reason: 'the badge is on the top-right corner of its photo',
      );

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();
      expect(controller.photos, hasLength(1));
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('a Windows clipboard BMP shows up as a thumbnail', (
      tester,
    ) async {
      await show(tester, clipboardImage: () async => _bmp(48, 32));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.runAsync(() async {
        // The conversion runs in a background isolate, which needs real time.
        for (var i = 0; i < 400 && controller.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });
      await tester.pump();
      expect(controller.photos, hasLength(1));
      expect(controller.error, isNull);
      expect(find.byType(Image), findsOneWidget);
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
