import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;

/// The browser-independent half of "quick sign in on the web" (Face ID, Touch ID, a
/// fingerprint, Windows Hello through WebAuthn). The browser does the prompt; everything
/// here only checks what the browser hands back, so it can be tested without a browser.
///
/// What it protects: quick sign in is a convenience lock in front of an account that is
/// already on this device - the proof is that the SAME platform credential that was set up
/// on this browser was just unlocked by the person's face or finger. It does not replace
/// the password anywhere else.

String base64UrlNoPad(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

Uint8List fromBase64Url(String text) {
  final padded = text.padRight(text.length + (4 - text.length % 4) % 4, '=');
  return Uint8List.fromList(base64Url.decode(padded));
}

/// The fixed-size head of WebAuthn "authenticator data": the hash of the site's id, the
/// flag byte and the signature counter.
class AuthenticatorData {
  final Uint8List rpIdHash;
  final int flags;
  final int signCount;

  const AuthenticatorData(this.rpIdHash, this.flags, this.signCount);

  bool get userPresent => flags & 0x01 != 0;
  bool get userVerified => flags & 0x04 != 0;

  static AuthenticatorData? parse(Uint8List data) {
    if (data.length < 37) return null;
    final count = ByteData.sublistView(data, 33, 37).getUint32(0, Endian.big);
    return AuthenticatorData(Uint8List.fromList(data.sublist(0, 32)), data[32], count);
  }
}

/// An ECDSA signature as a security key sends it (an ASN.1 DER sequence of two integers)
/// turned into what the browser's own signature check wants: r and s, 32 bytes each,
/// side by side. Null when it is not a well-formed P-256 signature.
Uint8List? ecdsaDerToRaw(Uint8List der, {int size = 32}) {
  var offset = 0;
  int? readLength() {
    if (offset >= der.length) return null;
    final first = der[offset++];
    if (first < 0x80) return first;
    final bytes = first & 0x7f;
    if (bytes == 0 || bytes > 2 || offset + bytes > der.length) return null;
    var value = 0;
    for (var i = 0; i < bytes; i++) {
      value = (value << 8) | der[offset++];
    }
    return value;
  }

  Uint8List? readInteger() {
    if (offset >= der.length || der[offset++] != 0x02) return null;
    final length = readLength();
    if (length == null || length < 1 || offset + length > der.length) return null;
    var bytes = der.sublist(offset, offset + length);
    offset += length;
    // A leading zero only keeps a high bit from reading as a sign.
    while (bytes.length > 1 && bytes.first == 0) {
      bytes = bytes.sublist(1);
    }
    if (bytes.length > size) return null;
    final out = Uint8List(size);
    out.setRange(size - bytes.length, size, bytes);
    return out;
  }

  if (der.isEmpty || der[offset++] != 0x30) return null;
  final total = readLength();
  if (total == null || offset + total != der.length) return null;
  final r = readInteger();
  final s = readInteger();
  if (r == null || s == null || offset != der.length) return null;
  return Uint8List.fromList([...r, ...s]);
}

/// Everything about one sign-in answer that can be checked without the signature itself.
/// Returns null when it is right, else why not (for the log - the person only sees "could
/// not verify you").
String? checkAssertionParts({
  required String expectedRpId,
  required String expectedOrigin,
  required Uint8List expectedChallenge,
  required Uint8List authenticatorData,
  required Uint8List clientDataJson,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(clientDataJson));
  } catch (_) {
    return 'client data is not JSON';
  }
  if (decoded is! Map) return 'client data is not an object';
  if (decoded['type'] != 'webauthn.get') return 'wrong request type';
  if (decoded['challenge'] != base64UrlNoPad(expectedChallenge)) return 'challenge does not match';
  if (decoded['origin'] != expectedOrigin) return 'origin does not match';
  if (decoded['crossOrigin'] == true) return 'cross-origin request';
  final data = AuthenticatorData.parse(authenticatorData);
  if (data == null) return 'authenticator data too short';
  final expectedHash = sha256.convert(utf8.encode(expectedRpId)).bytes;
  var same = data.rpIdHash.length == expectedHash.length;
  for (var i = 0; same && i < expectedHash.length; i++) {
    same = data.rpIdHash[i] == expectedHash[i];
  }
  if (!same) return 'site id does not match';
  if (!data.userPresent) return 'the user was not present';
  if (!data.userVerified) return 'the user was not verified (face / fingerprint / PIN)';
  return null;
}

/// What the signature covers: the authenticator data followed by the hash of the client data.
Uint8List assertionSignedBytes(Uint8List authenticatorData, Uint8List clientDataJson) =>
    Uint8List.fromList([...authenticatorData, ...sha256.convert(clientDataJson).bytes]);

/// Checks a sign-in answer completely, given a function that verifies an ES256 signature
/// (the browser's WebCrypto in the app; anything in a test).
Future<bool> verifyAssertion({
  required Uint8List publicKeySpki,
  required String expectedRpId,
  required String expectedOrigin,
  required Uint8List expectedChallenge,
  required Uint8List authenticatorData,
  required Uint8List clientDataJson,
  required Uint8List signatureDer,
  required Future<bool> Function(Uint8List publicKeySpki, Uint8List signedBytes, Uint8List rawSignature) verifySignature,
}) async {
  if (checkAssertionParts(
        expectedRpId: expectedRpId,
        expectedOrigin: expectedOrigin,
        expectedChallenge: expectedChallenge,
        authenticatorData: authenticatorData,
        clientDataJson: clientDataJson,
      ) !=
      null) {
    return false;
  }
  final raw = ecdsaDerToRaw(signatureDer);
  if (raw == null) return false;
  try {
    return await verifySignature(publicKeySpki, assertionSignedBytes(authenticatorData, clientDataJson), raw);
  } catch (_) {
    return false;
  }
}
