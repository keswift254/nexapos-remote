import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:win32/win32.dart';

const _channel = MethodChannel('com.nexapos/sound');

// Kept for the conditional backend's shared interface; native playback uses
// the WAV bytes through playWav instead.
Future<void> playAsset() async {}

Pointer<Uint8>? _windowsBuffer;
int _windowsBufferLength = 0;

/// Plays a WAV file on this device. Windows: the system sound player (winmm, no plugin, so
/// the Windows 7/8 edition gets it too). Android: a native audio track (MainActivity.kt).
/// Anything else: the system's own click.
Future<void> playWav(Uint8List wav) async {
  if (Platform.isWindows) {
    _playOnWindows(wav);
  } else if (Platform.isAndroid) {
    await _channel.invokeMethod<void>('play', wav);
  } else {
    await SystemSound.play(SystemSoundType.click);
  }
}

void _playOnWindows(Uint8List wav) {
  // Asynchronous playback keeps reading the buffer after PlaySound returns, so it has to
  // outlive this call. The sound never changes, so one copy is made and reused.
  if (_windowsBuffer == null || _windowsBufferLength != wav.length) {
    final buffer = calloc<Uint8>(wav.length);
    buffer.asTypedList(wav.length).setAll(0, wav);
    _windowsBuffer = buffer;
    _windowsBufferLength = wav.length;
  }
  PlaySound(
    PCWSTR(_windowsBuffer!.cast<Utf16>()),
    null,
    SND_MEMORY | SND_ASYNC | SND_NODEFAULT,
  );
}
