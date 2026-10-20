import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Plays a WAV file in the browser. It starts from the tap that sent the message, which is
/// what lets the browser allow sound; if it still refuses, there is simply no sound.
Future<void> playWav(Uint8List wav) async {
  final blob = web.Blob(
    [wav.toJS].toJS,
    web.BlobPropertyBag(type: 'audio/wav'),
  );
  final url = web.URL.createObjectURL(blob);
  final audio = web.HTMLAudioElement()
    ..src = url
    ..volume = 0.8;
  try {
    await audio.play().toDart;
    await Future<void>.delayed(const Duration(seconds: 1));
  } finally {
    web.URL.revokeObjectURL(url);
  }
}
