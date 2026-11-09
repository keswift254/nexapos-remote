import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/domain/services/webauthn_logic.dart';

/// The checks behind quick sign in on the web (Face ID / fingerprint through WebAuthn). The
/// vectors are real P-256 sign-ins made by test/tool/make_webauthn_vectors.mjs, each verified
/// with Node's WebCrypto before it was written down.
class _Vector {
  final Map<String, dynamic> json;
  _Vector(this.json);
  String get rpId => json['rpId'] as String;
  String get origin => json['origin'] as String;
  Uint8List get spki => fromBase64Url(json['spki'] as String);
  Uint8List get challenge => fromBase64Url(json['challenge'] as String);
  Uint8List get authData => fromBase64Url(json['authenticatorData'] as String);
  Uint8List get clientData => fromBase64Url(json['clientDataJson'] as String);
  Uint8List get der => fromBase64Url(json['derSignature'] as String);
  Uint8List get raw => fromBase64Url(json['rawSignature'] as String);
}

void main() {
  late List<_Vector> vectors;

  setUpAll(() {
    final file = File('test/fixtures/webauthn/vectors.json');
    expect(file.existsSync(), isTrue, reason: 'Generate it with: node test/tool/make_webauthn_vectors.mjs');
    vectors = [
      for (final v in (jsonDecode(file.readAsStringSync())['vectors'] as List)) _Vector(v as Map<String, dynamic>),
    ];
  });

  Uint8List clientDataWith(_Vector v, Map<String, Object?> changes) {
    final decoded = jsonDecode(utf8.decode(v.clientData)) as Map<String, dynamic>;
    decoded.addAll(changes);
    return Uint8List.fromList(utf8.encode(jsonEncode(decoded)));
  }

  Uint8List authDataWith(_Vector v, {int? flags, Uint8List? rpIdHash, int? length}) {
    final data = Uint8List.fromList(v.authData);
    if (flags != null) data[32] = flags;
    if (rpIdHash != null) data.setRange(0, 32, rpIdHash);
    return length == null ? data : Uint8List.fromList(data.sublist(0, length));
  }

  String? check(_Vector v, {String? rpId, String? origin, Uint8List? challenge, Uint8List? authData, Uint8List? clientData}) =>
      checkAssertionParts(
        expectedRpId: rpId ?? v.rpId,
        expectedOrigin: origin ?? v.origin,
        expectedChallenge: challenge ?? v.challenge,
        authenticatorData: authData ?? v.authData,
        clientDataJson: clientData ?? v.clientData,
      );

  group('base64url', () {
    test('round-trips every length, with no padding', () {
      for (var length = 0; length < 70; length++) {
        final bytes = Uint8List.fromList([for (var i = 0; i < length; i++) (i * 37 + length) & 0xff]);
        final text = base64UrlNoPad(bytes);
        expect(text.contains('='), isFalse);
        expect(text.contains('+') || text.contains('/'), isFalse);
        expect(fromBase64Url(text), bytes, reason: 'length $length');
      }
    });
  });

  group('authenticator data', () {
    test('reads the site hash, flags and counter', () {
      final data = Uint8List(37);
      for (var i = 0; i < 32; i++) {
        data[i] = i;
      }
      data[32] = 0x05;
      data.setRange(33, 37, [0x00, 0x00, 0x01, 0x02]);
      final parsed = AuthenticatorData.parse(data)!;
      expect(parsed.rpIdHash, Uint8List.fromList([for (var i = 0; i < 32; i++) i]));
      expect(parsed.userPresent, isTrue);
      expect(parsed.userVerified, isTrue);
      expect(parsed.signCount, 258);
    });

    test('reads each flag on its own, and refuses data that is too short', () {
      Uint8List withFlags(int f) => Uint8List(37)..[32] = f;
      expect(AuthenticatorData.parse(withFlags(0x01))!.userPresent, isTrue);
      expect(AuthenticatorData.parse(withFlags(0x01))!.userVerified, isFalse);
      expect(AuthenticatorData.parse(withFlags(0x04))!.userVerified, isTrue);
      expect(AuthenticatorData.parse(withFlags(0x04))!.userPresent, isFalse);
      expect(AuthenticatorData.parse(withFlags(0x00))!.userPresent, isFalse);
      expect(AuthenticatorData.parse(Uint8List(36)), isNull);
      expect(AuthenticatorData.parse(Uint8List(0)), isNull);
    });

    test('keeps reading when extension data follows the fixed part', () {
      final data = Uint8List(80)..[32] = 0x05;
      expect(AuthenticatorData.parse(data)!.userVerified, isTrue);
    });
  });

  group('turning a DER signature into the browser\'s r||s form', () {
    test('matches the real signature for every vector, including short and zero-padded integers', () {
      expect(vectors.length, greaterThanOrEqualTo(40));
      var short = 0;
      var padded = 0;
      for (final v in vectors) {
        expect(ecdsaDerToRaw(v.der), v.raw);
        if (v.json['rIsShort'] == true || v.json['sIsShort'] == true) short++;
        if (v.json['rHasLeadingZeroPad'] == true || v.json['sHasLeadingZeroPad'] == true) padded++;
      }
      expect(short, greaterThanOrEqualTo(3), reason: 'the vectors must include integers shorter than 32 bytes');
      expect(padded, greaterThanOrEqualTo(3), reason: 'and integers padded with a zero byte');
    });

    test('refuses anything that is not a well-formed signature', () {
      final good = vectors.first.der;
      expect(ecdsaDerToRaw(Uint8List(0)), isNull);
      expect(ecdsaDerToRaw(Uint8List.fromList([0x31, ...good.sublist(1)])), isNull, reason: 'not a SEQUENCE');
      expect(ecdsaDerToRaw(Uint8List.fromList(good.sublist(0, good.length - 1))), isNull, reason: 'truncated');
      expect(ecdsaDerToRaw(Uint8List.fromList([...good, 0x00])), isNull, reason: 'trailing byte');
      final wrongInteger = Uint8List.fromList(good)..[2] = 0x04;
      expect(ecdsaDerToRaw(wrongInteger), isNull, reason: 'first item is not an INTEGER');
      expect(ecdsaDerToRaw(Uint8List.fromList([0x30, 0x06, 0x02, 0x01, 0x01, 0x02, 0x01])), isNull, reason: 'second integer cut short');
      expect(ecdsaDerToRaw(Uint8List.fromList([0x30, 0x04, 0x02, 0x01, 0x01, 0x02])), isNull);
      // A 33-byte integer that is not just a sign pad does not fit a P-256 signature.
      expect(ecdsaDerToRaw(Uint8List.fromList([0x30, 0x27, 0x02, 0x21, 0x01, ...List.filled(32, 0x55), 0x02, 0x01, 0x01])), isNull);
    });

    test('a tiny signature is left-padded to 32 bytes', () {
      final raw = ecdsaDerToRaw(Uint8List.fromList([0x30, 0x06, 0x02, 0x01, 0x07, 0x02, 0x01, 0x09]))!;
      expect(raw.length, 64);
      expect(raw[31], 7);
      expect(raw[63], 9);
      expect(raw.sublist(0, 31).every((b) => b == 0), isTrue);
    });
  });

  group('checking an answer without its signature', () {
    test('a genuine answer passes', () {
      for (final v in vectors) {
        expect(check(v), isNull);
      }
    });

    test('every wrong detail is refused with its own reason', () {
      final v = vectors.first;
      expect(check(v, rpId: 'evil.example'), 'site id does not match');
      expect(check(v, origin: 'https://evil.example'), 'origin does not match');
      expect(check(v, challenge: Uint8List(32)), 'challenge does not match');
      expect(check(v, clientData: clientDataWith(v, {'type': 'webauthn.create'})), 'wrong request type');
      expect(check(v, clientData: clientDataWith(v, {'crossOrigin': true})), 'cross-origin request');
      expect(check(v, clientData: clientDataWith(v, {'origin': 'http://nexapos.cc'})), 'origin does not match');
      expect(check(v, authData: authDataWith(v, flags: 0x04)), 'the user was not present');
      expect(check(v, authData: authDataWith(v, flags: 0x01)), contains('not verified'));
      expect(check(v, authData: authDataWith(v, flags: 0x00)), 'the user was not present');
      expect(check(v, authData: authDataWith(v, rpIdHash: Uint8List.fromList(sha256.convert(utf8.encode('other.site')).bytes))), 'site id does not match');
      expect(check(v, authData: authDataWith(v, length: 36)), 'authenticator data too short');
      expect(check(v, clientData: Uint8List.fromList(utf8.encode('not json'))), 'client data is not JSON');
      expect(check(v, clientData: Uint8List.fromList(utf8.encode('[1,2]'))), 'client data is not an object');
    });

    test('a different site\'s hash differing in only the last byte is still refused', () {
      final v = vectors.first;
      final hash = Uint8List.fromList(v.authData.sublist(0, 32));
      hash[31] ^= 1;
      expect(check(v, authData: authDataWith(v, rpIdHash: hash)), 'site id does not match');
    });
  });

  group('verifying a whole answer', () {
    Future<bool> run(
      _Vector v, {
      Uint8List? der,
      Uint8List? authData,
      Uint8List? clientData,
      required Future<bool> Function(Uint8List, Uint8List, Uint8List) verifySignature,
    }) => verifyAssertion(
      publicKeySpki: v.spki,
      expectedRpId: v.rpId,
      expectedOrigin: v.origin,
      expectedChallenge: v.challenge,
      authenticatorData: authData ?? v.authData,
      clientDataJson: clientData ?? v.clientData,
      signatureDer: der ?? v.der,
      verifySignature: verifySignature,
    );

    test('hands the signature check exactly what the authenticator signed', () async {
      final v = vectors.first;
      Uint8List? gotKey, gotSigned, gotSignature;
      final ok = await run(v, verifySignature: (key, signed, signature) async {
        gotKey = key;
        gotSigned = signed;
        gotSignature = signature;
        return true;
      });
      expect(ok, isTrue);
      expect(gotKey, v.spki);
      expect(gotSigned, Uint8List.fromList([...v.authData, ...sha256.convert(v.clientData).bytes]));
      expect(gotSignature, v.raw);
    });

    test('is false when the signature check says so', () async {
      expect(await run(vectors.first, verifySignature: (_, _, _) async => false), isFalse);
    });

    test('is false, not a crash, when the signature check throws', () async {
      expect(await run(vectors.first, verifySignature: (_, _, _) async => throw StateError('boom')), isFalse);
    });

    test('never reaches the signature check when the details are wrong or the signature is malformed', () async {
      final v = vectors.first;
      var calls = 0;
      Future<bool> counting(Uint8List a, Uint8List b, Uint8List c) async {
        calls++;
        return true;
      }

      expect(await run(v, authData: authDataWith(v, flags: 0x01), verifySignature: counting), isFalse);
      expect(await run(v, clientData: clientDataWith(v, {'type': 'webauthn.create'}), verifySignature: counting), isFalse);
      expect(await run(v, der: Uint8List.fromList([1, 2, 3]), verifySignature: counting), isFalse);
      expect(calls, 0);
    });

    test('every genuine vector verifies when the signature check accepts r||s', () async {
      for (final v in vectors) {
        expect(await run(v, verifySignature: (_, _, signature) async => signature.length == 64), isTrue);
      }
    });
  });
}
