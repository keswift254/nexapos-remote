import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// What the support server accepts for one photo: PNG, JPEG or WebP, at most
/// 2 MB and 16 megapixels.
const supportPhotoMaxBytes = 2 * 1024 * 1024;
const _maxPixels = 16000000;

/// Pictures up to this many pixels (about a 1920x1080 screenshot) are tried as a
/// lossless PNG first, which keeps text sharp; larger ones go straight to JPEG.
const _pngFirstPixels = 2300000;
const _longestSides = [2560, 2048, 1600, 1280, 1024, 800];
const _jpegQualities = [88, 75, 60];

/// Why a picture could not be turned into something the server takes.
class SupportPhotoUnreadable implements Exception {
  const SupportPhotoUnreadable();
}

class SupportPhotoTooLarge implements Exception {
  const SupportPhotoTooLarge();
}

/// Makes [bytes] fit what the server takes. A PNG/JPEG/WebP that already fits is
/// returned untouched. Anything else - a Windows clipboard picture (a BMP), a GIF,
/// a camera photo over 2 MB, a huge screenshot - is decoded, shrunk if needed and
/// re-encoded as PNG or JPEG, off the UI thread.
///
/// Throws [SupportPhotoUnreadable] when the bytes are not a picture this app can
/// read, and [SupportPhotoTooLarge] when it will not fit even when shrunk.
Future<Uint8List> prepareSupportPhoto(Uint8List bytes) async {
  if (bytes.isEmpty) throw const SupportPhotoUnreadable();
  if (_alreadyFits(bytes)) return bytes;
  final result = await compute(_convert, bytes);
  if (result.bytes != null) return result.bytes!;
  throw result.tooLarge
      ? const SupportPhotoTooLarge()
      : const SupportPhotoUnreadable();
}

bool _alreadyFits(Uint8List bytes) {
  if (bytes.length > supportPhotoMaxBytes) return false;
  final format = img.findFormatForData(bytes);
  if (format != img.ImageFormat.png &&
      format != img.ImageFormat.jpg &&
      format != img.ImageFormat.webp) {
    return false;
  }
  try {
    final info = img.findDecoderForData(bytes)?.startDecode(bytes);
    if (info == null || info.width <= 0 || info.height <= 0) return false;
    return info.width * info.height <= _maxPixels;
  } catch (_) {
    return false;
  }
}

typedef _Converted = ({Uint8List? bytes, bool tooLarge});

_Converted _convert(Uint8List bytes) {
  final isBmp = img.findFormatForData(bytes) == img.ImageFormat.bmp;
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
    return (bytes: null, tooLarge: false);
  }
  // A Windows clipboard BMP carries no real transparency: its fourth byte is
  // unused and is often zero, which would turn the whole picture invisible.
  var picture = isBmp ? _opaque(decoded) : decoded;
  final transparent = !isBmp && _hasTransparency(picture);

  final longest = math.max(picture.width, picture.height);
  final pixels = picture.width * picture.height;
  final steps = <int>[
    // The original size, when it is already within the limits.
    if (longest <= _longestSides.first && pixels <= _maxPixels) longest,
    ..._longestSides.where((side) => side < longest),
  ];

  for (final side in steps) {
    final sized = side >= longest ? picture : _fit(picture, side);
    if (transparent || sized.width * sized.height <= _pngFirstPixels) {
      final png = Uint8List.fromList(img.encodePng(sized));
      if (png.length <= supportPhotoMaxBytes) {
        return (bytes: png, tooLarge: false);
      }
    }
    if (transparent) continue;
    for (final quality in _jpegQualities) {
      final jpeg = Uint8List.fromList(img.encodeJpg(sized, quality: quality));
      if (jpeg.length <= supportPhotoMaxBytes) {
        return (bytes: jpeg, tooLarge: false);
      }
    }
  }
  return (bytes: null, tooLarge: true);
}

img.Image _fit(img.Image source, int longestSide) {
  final scale = longestSide / math.max(source.width, source.height);
  return img.copyResize(
    source,
    width: math.max(1, (source.width * scale).round()),
    height: math.max(1, (source.height * scale).round()),
    interpolation: img.Interpolation.average,
  );
}

/// The same picture as plain RGB, whatever its fourth channel held.
img.Image _opaque(img.Image source) {
  final out = img.Image(width: source.width, height: source.height);
  for (final pixel in source) {
    out.setPixelRgb(pixel.x, pixel.y, pixel.r, pixel.g, pixel.b);
  }
  return out;
}

bool _hasTransparency(img.Image image) {
  if (!image.hasAlpha) return false;
  final opaque = image.maxChannelValue;
  for (final pixel in image) {
    if (pixel.a < opaque) return true;
  }
  return false;
}
