import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Call directly from the user's send gesture. Audio.play() is invoked before
/// any await, allowing browser autoplay policies to permit this short sound.
web.HTMLAudioElement? _sentAudio;

Future<void> playAsset() async {
  // The element is created by index.html before Flutter boots. Reuse it so
  // Safari can load the WAV ahead of the Send gesture; play() itself still
  // happens synchronously inside that gesture, before the first await.
  final audio = _sentAudio ??=
      (web.document.getElementById('nexapos-send-sound')
          as web.HTMLAudioElement?) ??
      (web.HTMLAudioElement()
        ..src = 'assets/assets/sounds/message_sent.wav'
        ..preload = 'auto');
  audio.volume = 0.8;
  try {
    audio.currentTime = 0;
  } catch (_) {
    // Safari can refuse seeking until the source has loaded; play still works.
  }
  await audio.play().toDart;
}

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
