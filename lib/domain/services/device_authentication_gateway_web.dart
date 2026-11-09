import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'device_authentication_gateway.dart';
import 'webauthn_logic.dart';

/// Selected instead of device_authentication_gateway_native.dart when compiling for web
/// (see app_security_service.dart's conditional import).
///
/// Quick sign in in a browser is a WebAuthn platform credential: Face ID or Touch ID on an
/// iPhone, iPad or Mac, a fingerprint or screen lock on Android, Windows Hello in Chrome or
/// Edge. Turning it on creates a credential that lives in the device's secure hardware and
/// can only be used after the person's face, finger or PIN; signing in asks for it and
/// checks the answer against the public key saved at set-up. Nothing secret is stored here.
DeviceAuthenticationGateway createDeviceAuthenticationGateway() => WebDeviceAuthenticationGateway();

const _storeKey = 'nexapos.webauthn.v1';
const _timeoutMs = 60000;

class WebDeviceAuthenticationGateway implements DeviceAuthenticationGateway, EnrollableDeviceAuthentication {
  bool? _supported;
  final Random _random = Random.secure();

  Uint8List _bytes(int length) => Uint8List.fromList([for (var i = 0; i < length; i++) _random.nextInt(256)]);

  String get _rpId => web.window.location.hostname;
  String get _origin => web.window.location.origin;

  // ---- what the browser can do ---------------------------------------------------------------

  @override
  Future<bool> isSupported() async {
    final known = _supported;
    if (known != null) return known;
    var result = false;
    try {
      // Needs https (or localhost) and a built-in unlock method (face, finger, screen lock).
      if (web.window.isSecureContext && globalContext.has('PublicKeyCredential')) {
        result = (await web.PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable().toDart).toDart;
      }
    } catch (_) {
      result = false;
    }
    return _supported = result;
  }

  // ---- what was saved at set-up --------------------------------------------------------------

  ({Uint8List id, Uint8List publicKey})? _saved() {
    try {
      final text = web.window.localStorage.getItem(_storeKey);
      if (text == null) return null;
      final decoded = jsonDecode(text) as Map<String, dynamic>;
      if (decoded['alg'] != -7) return null;
      return (id: fromBase64Url(decoded['id'] as String), publicKey: fromBase64Url(decoded['key'] as String));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> isEnrolled() async => _saved() != null;

  @override
  Future<void> forget() async {
    try {
      web.window.localStorage.removeItem(_storeKey);
    } catch (_) {}
  }

  // ---- set up --------------------------------------------------------------------------------

  /// Creates the credential (the browser asks for Face ID / the fingerprint once). Returns
  /// false if the person cancelled; throws a [StateError] with an explanation if this browser
  /// cannot do it.
  @override
  Future<bool> enroll() async {
    final options = _object({
      'publicKey': {
        'challenge': _bytes(32),
        'rp': {'name': 'NexaPOS', 'id': _rpId},
        'user': {'id': _bytes(16), 'name': 'nexapos-quick-sign-in', 'displayName': 'NexaPOS quick sign in'},
        // ES256 only: it is what every phone, Mac and recent Windows PC offers.
        'pubKeyCredParams': [
          {'type': 'public-key', 'alg': -7},
        ],
        'authenticatorSelection': {
          'authenticatorAttachment': 'platform',
          'userVerification': 'required',
          'residentKey': 'discouraged',
        },
        'timeout': _timeoutMs,
        'attestation': 'none',
      },
    });
    final web.Credential? credential;
    try {
      credential = await web.window.navigator.credentials.create(options as web.CredentialCreationOptions).toDart;
    } catch (error) {
      if (_cancelled(error)) return false;
      throw StateError(_explain(error));
    }
    if (credential == null) return false;
    final publicKeyCredential = credential as web.PublicKeyCredential;
    final response = publicKeyCredential.response as web.AuthenticatorAttestationResponse;
    final key = response.getPublicKey();
    if (key == null || response.getPublicKeyAlgorithm() != -7) {
      throw StateError('This browser cannot set up quick sign in. Use your password instead.');
    }
    web.window.localStorage.setItem(
      _storeKey,
      jsonEncode({
        'v': 1,
        'id': base64UrlNoPad(publicKeyCredential.rawId.toDart.asUint8List()),
        'key': base64UrlNoPad(key.toDart.asUint8List()),
        'alg': -7,
      }),
    );
    return true;
  }

  // ---- sign in -------------------------------------------------------------------------------

  @override
  Future<bool> authenticate() async {
    final saved = _saved();
    if (saved == null) return false;
    final challenge = _bytes(32);
    final options = _object({
      'publicKey': {
        'challenge': challenge,
        'rpId': _rpId,
        'allowCredentials': [
          {
            'type': 'public-key',
            'id': saved.id,
            'transports': ['internal'],
          },
        ],
        'userVerification': 'required',
        'timeout': _timeoutMs,
      },
    });
    try {
      final credential = await web.window.navigator.credentials.get(options as web.CredentialRequestOptions).toDart;
      if (credential == null) return false;
      final response = (credential as web.PublicKeyCredential).response as web.AuthenticatorAssertionResponse;
      return await verifyAssertion(
        publicKeySpki: saved.publicKey,
        expectedRpId: _rpId,
        expectedOrigin: _origin,
        expectedChallenge: challenge,
        authenticatorData: response.authenticatorData.toDart.asUint8List(),
        clientDataJson: response.clientDataJSON.toDart.asUint8List(),
        signatureDer: response.signature.toDart.asUint8List(),
        verifySignature: _verifyEs256,
      );
    } catch (_) {
      // Cancelled, timed out, or the stored credential is gone from this device: not signed in.
      return false;
    }
  }

  /// The browser's own ECDSA P-256 / SHA-256 check of [rawSignature] over [signedBytes].
  Future<bool> _verifyEs256(Uint8List spki, Uint8List signedBytes, Uint8List rawSignature) async {
    final subtle = web.window.crypto.subtle;
    final key = await subtle
        .importKey('spki', spki.toJS, _object({'name': 'ECDSA', 'namedCurve': 'P-256'}), false, ['verify'.toJS].toJS)
        .toDart;
    final ok = await subtle
        .verify(_object({'name': 'ECDSA', 'hash': 'SHA-256'}), key, rawSignature.toJS, signedBytes.toJS)
        .toDart;
    return (ok as JSBoolean).toDart;
  }

  // ---- helpers -------------------------------------------------------------------------------

  bool _cancelled(Object error) {
    final text = '$error';
    return text.contains('NotAllowedError') || text.contains('AbortError');
  }

  String _explain(Object error) {
    final text = '$error';
    if (text.contains('InvalidStateError')) return 'Quick sign in is already set up on this device. Turn it off and on again.';
    if (text.contains('NotSupportedError') || text.contains('SecurityError')) {
      return 'This browser or device cannot set up Face ID / fingerprint sign in. Use your password instead.';
    }
    return 'Quick sign in could not be set up on this device.';
  }

  JSObject _object(Map<String, Object?> values) {
    final object = JSObject();
    values.forEach((name, value) => object.setProperty(name.toJS, _toJs(value)));
    return object;
  }

  JSAny? _toJs(Object? value) {
    if (value == null) return null;
    if (value is Uint8List) return value.toJS;
    if (value is String) return value.toJS;
    if (value is bool) return value.toJS;
    if (value is num) return value.toJS;
    if (value is Map<String, Object?>) return _object(value);
    if (value is List) return [for (final item in value) _toJs(item)].toJS;
    throw ArgumentError('Cannot pass ${value.runtimeType} to the browser');
  }
}
