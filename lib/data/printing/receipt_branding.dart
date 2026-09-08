import 'dart:convert';

import 'package:barcode/barcode.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

const supportFooter = 'Support / Installation: 0768415017';
const installationFooter = supportFooter;

// Fixed-length numeric Code 128 stays readable at 2 dots/module on 58mm paper.
String receiptBarcodeValue(String receiptNumber) => BigInt.parse(
  sha256.convert(utf8.encode(receiptNumber)).toString().substring(0, 19),
  radix: 16,
).toString().padLeft(24, '0');

img.Image receiptLogo() {
  // ESC/POS raster rows must be byte-aligned (a multiple of eight pixels).
  final image = img.Image(width: 184, height: 36);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  img.drawString(
    image,
    'NEXAPOS',
    x: 12,
    y: 5,
    font: img.arial24,
    color: img.ColorRgb8(0, 0, 0),
  );
  return image;
}

img.Image receiptBarcode(String receiptNumber) {
  final value = receiptBarcodeValue(receiptNumber);
  final image = img.Image(width: 384, height: 112);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  for (final bar
      in Barcode.code128()
          .make(value, width: 334, height: 76)
          .whereType<BarcodeBar>()) {
    if (!bar.black) continue;
    img.fillRect(
      image,
      x1: 25 + bar.left.round(),
      y1: 4,
      x2: 25 + (bar.left + bar.width).round() - 1,
      y2: 79,
      color: img.ColorRgb8(0, 0, 0),
    );
  }
  img.drawString(
    image,
    value,
    y: 88,
    font: img.arial14,
    color: img.ColorRgb8(0, 0, 0),
  );
  return image;
}
