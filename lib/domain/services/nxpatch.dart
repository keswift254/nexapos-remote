import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Applies a binary patch produced by release-tools/nxpatch.py's
/// make_patch(): the bsdiff algorithm's own control/diff/extra blocks
/// (bsdiff4.core.diff on the build machine), repackaged with plain gzip
/// instead of bsdiff4's own bzip2 - so this reconstructs the EXACT
/// original new-version bytes using only dart:io's built-in gzip
/// support, with no third-party bzip2 dependency. A byte-exact
/// reconstruction is the whole point: it's what lets a device already
/// holding the previous version's file download a few percent of its
/// size instead of the whole thing again. See NxPatch.cs for the
/// identical format read by the Windows installer's elevated patcher.
///
/// Format ("NXPATCH1"):
///   8 bytes  magic "NXPATCH1"
///   int64 LE  newLength
///   int64 LE  numControlTuples
///   int64 LE  compressedControlLen
///   int64 LE  compressedDiffLen
///   int64 LE  compressedExtraLen
///   [gzip(control)]  numControlTuples * 3 int64 LE (addLen, copyLen, seekOffset)
///   [gzip(diff)]
///   [gzip(extra)]
class NxPatchFormatException implements Exception {
  final String message;
  const NxPatchFormatException(this.message);
  @override
  String toString() => 'NxPatchFormatException: $message';
}

const List<int> nxPatchMagic = [
  0x4e, 0x58, 0x50, 0x41, 0x54, 0x43, 0x48, 0x31, // "NXPATCH1"
];

Uint8List applyNxPatch(Uint8List oldBytes, Uint8List patchBytes) {
  if (patchBytes.length < 48 ||
      !_startsWith(patchBytes, nxPatchMagic)) {
    throw const NxPatchFormatException('Not an NXPATCH1 file.');
  }
  final header = ByteData.sublistView(patchBytes, 8, 48);
  final newLength = header.getInt64(0, Endian.little);
  final numTuples = header.getInt64(8, Endian.little);
  final controlLen = header.getInt64(16, Endian.little);
  final diffLen = header.getInt64(24, Endian.little);
  final extraLen = header.getInt64(32, Endian.little);

  var offset = 48;
  Uint8List take(int length) {
    if (offset + length > patchBytes.length) {
      throw const NxPatchFormatException('Patch file is truncated.');
    }
    final slice = patchBytes.sublist(offset, offset + length);
    offset += length;
    return slice;
  }

  final gzip = GZipCodec();
  final controlBytes = Uint8List.fromList(gzip.decode(take(controlLen)));
  final diffBytes = Uint8List.fromList(gzip.decode(take(diffLen)));
  final extraBytes = Uint8List.fromList(gzip.decode(take(extraLen)));

  if (controlBytes.length != numTuples * 24) {
    throw const NxPatchFormatException(
      'Control block length does not match the tuple count.',
    );
  }
  final control = ByteData.sublistView(controlBytes);

  final out = Uint8List(newLength);
  var outPos = 0;
  var oldPos = 0;
  var diffPos = 0;
  var extraPos = 0;

  for (var i = 0; i < numTuples; i++) {
    final base = i * 24;
    final addLen = control.getInt64(base, Endian.little);
    final copyLen = control.getInt64(base + 8, Endian.little);
    final seekOffset = control.getInt64(base + 16, Endian.little);

    if (addLen < 0 || copyLen < 0) {
      throw const NxPatchFormatException('Negative length in control block.');
    }
    if (oldPos + addLen > oldBytes.length ||
        diffPos + addLen > diffBytes.length ||
        outPos + addLen > out.length) {
      throw const NxPatchFormatException(
        'Patch does not match the given original file.',
      );
    }
    for (var j = 0; j < addLen; j++) {
      out[outPos + j] = (oldBytes[oldPos + j] + diffBytes[diffPos + j]) & 0xff;
    }
    outPos += addLen;
    oldPos += addLen;
    diffPos += addLen;

    if (extraPos + copyLen > extraBytes.length || outPos + copyLen > out.length) {
      throw const NxPatchFormatException(
        'Patch extra block is shorter than expected.',
      );
    }
    out.setRange(outPos, outPos + copyLen, extraBytes, extraPos);
    outPos += copyLen;
    extraPos += copyLen;

    oldPos += seekOffset;
  }

  if (outPos != newLength) {
    throw const NxPatchFormatException(
      'Reconstructed file length does not match the patch header.',
    );
  }
  return out;
}

bool _startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

/// A patch bundle for a platform that updates more than one installed
/// file at once (Windows: the exe plus its plugin DLLs and app.so) -
/// a plain zip containing manifest.json (old/new SHA-256 per relative
/// path, for verifying both that this device's current files are
/// exactly the expected "from" version and that patching produced
/// exactly the expected "to" version) plus one .nxpatch file per entry.
/// Android only ever patches its own single APK, so it never needs
/// this - see UpdateService._installAndroid vs _installWindows.
class NxPatchManifestEntry {
  final String path;
  final String oldSha256;
  final String newSha256;
  final String patchFile;

  const NxPatchManifestEntry({
    required this.path,
    required this.oldSha256,
    required this.newSha256,
    required this.patchFile,
  });

  factory NxPatchManifestEntry.fromJson(Map<String, dynamic> json) =>
      NxPatchManifestEntry(
        path: json['path'] as String,
        oldSha256: json['oldSha256'] as String,
        newSha256: json['newSha256'] as String,
        patchFile: json['patchFile'] as String,
      );
}

List<NxPatchManifestEntry> parseNxPatchManifest(String jsonText) {
  final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
  final files = decoded['files'] as List;
  return files
      .map((e) => NxPatchManifestEntry.fromJson((e as Map).cast<String, dynamic>()))
      .toList();
}
