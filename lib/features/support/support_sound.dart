import 'dart:typed_data';

import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'support_sound_native.dart'
    if (dart.library.js_interop) 'support_sound_web.dart'
    as backend;

/// The short "message sent" sound of the Support conversation.
abstract class SupportSound {
  Future<void> playSent();
}

/// The sound file that ships with the app.
const sentSoundAsset = 'assets/sounds/message_sent.wav';

/// Plays [sentSoundAsset] through the device: the Windows sound player, an Android audio track,
/// or the browser's audio element. Never throws - a missing speaker or file must not break sending.
///
/// [play] and [load] are replaced in tests so that no test ever makes a real noise.
class DeviceSupportSound implements SupportSound {
  DeviceSupportSound({
    Future<void> Function(Uint8List wav)? play,
    Future<ByteData> Function(String asset)? load,
  }) : _play = play ?? backend.playWav,
       _load = load ?? rootBundle.load;

  final Future<void> Function(Uint8List wav) _play;
  final Future<ByteData> Function(String asset) _load;
  Uint8List? _wav;

  @override
  Future<void> playSent() async {
    try {
      final wav = _wav ??= await _loadWav();
      await _play(wav);
    } catch (_) {
      // No sound is better than a failed message.
    }
  }

  Future<Uint8List> _loadWav() async {
    final data = await _load(sentSoundAsset);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}

final supportSoundProvider = Provider<SupportSound>(
  (ref) => DeviceSupportSound(),
);
