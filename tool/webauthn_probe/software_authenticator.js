// A software WebAuthn authenticator for trying the probe page in a browser that has no Face ID / fingerprint:
// paste into the page's console (or inject it) BEFORE pressing the buttons. It behaves like a platform
// authenticator that always has the user verified: real P-256 keys, real ES256 signatures in ASN.1 DER,
// authenticator data and client data shaped like the spec says.
(function () {
  var keys = {}; // credential id (base64url) -> private CryptoKey
  var state = (window.__softAuth = { creates: 0, gets: 0, mode: 'ok', last: null, uvpaa: true });

  function b64u(buffer) {
    var s = '';
    new Uint8Array(buffer).forEach(function (b) { s += String.fromCharCode(b); });
    return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }
  function toBuffer(bytes) { return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength); }
  function concat() {
    var total = 0, i;
    for (i = 0; i < arguments.length; i++) { total += arguments[i].length; }
    var out = new Uint8Array(total), at = 0;
    for (i = 0; i < arguments.length; i++) { out.set(arguments[i], at); at += arguments[i].length; }
    return out;
  }
  function derInteger(bytes) {
    var i = 0;
    while (i < bytes.length - 1 && bytes[i] === 0) { i++; }
    bytes = bytes.slice(i);
    if (bytes[0] & 0x80) { bytes = concat(new Uint8Array([0]), bytes); }
    return concat(new Uint8Array([0x02, bytes.length]), bytes);
  }
  function derFromRaw(raw) {
    var r = derInteger(raw.slice(0, 32)), s = derInteger(raw.slice(32));
    return concat(new Uint8Array([0x30, r.length + s.length]), r, s);
  }
  function bytesOf(source) { return source instanceof ArrayBuffer ? new Uint8Array(source) : new Uint8Array(source.buffer, source.byteOffset, source.byteLength); }
  function notAllowed() { var e = new Error('The operation either timed out or was not allowed.'); e.name = 'NotAllowedError'; return e; }

  PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable = function () { return Promise.resolve(state.uvpaa); };
  // The newer question browsers answer too; the same "no" an iPhone gave on iOS 26.2 when no passkey provider is set up.
  PublicKeyCredential.getClientCapabilities = function () { return Promise.resolve({ userVerifyingPlatformAuthenticator: state.uvpaa }); };

  navigator.credentials.create = function (options) {
    state.creates++;
    state.last = options;
    if (state.mode === 'cancel') { return Promise.reject(notAllowed()); }
    return crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']).then(function (pair) {
      return crypto.subtle.exportKey('spki', pair.publicKey).then(function (spki) {
        var id = crypto.getRandomValues(new Uint8Array(32));
        keys[b64u(id)] = pair.privateKey;
        return {
          id: b64u(id), type: 'public-key', rawId: toBuffer(id),
          response: {
            getPublicKey: function () { return spki; },
            getPublicKeyAlgorithm: function () { return -7; }
          }
        };
      });
    });
  };

  navigator.credentials.get = function (options) {
    state.gets++;
    state.last = options;
    if (state.mode === 'cancel') { return Promise.reject(notAllowed()); }
    var pk = options.publicKey;
    var allowed = pk.allowCredentials && pk.allowCredentials[0];
    var id = allowed ? b64u(allowed.id) : null;
    var privateKey = keys[id];
    if (!privateKey) { return Promise.reject(notAllowed()); }
    var userVerified = state.mode !== 'no-uv';
    var challenge = b64u(pk.challenge);
    var origin = state.mode === 'wrong-origin' ? 'https://evil.example' : location.origin;
    var clientData = new TextEncoder().encode(JSON.stringify({ type: 'webauthn.get', challenge: challenge, origin: origin, crossOrigin: false }));
    return crypto.subtle.digest('SHA-256', new TextEncoder().encode(pk.rpId || location.hostname)).then(function (rpHash) {
      var authData = concat(new Uint8Array(rpHash), new Uint8Array([userVerified ? 0x05 : 0x01, 0, 0, 0, state.gets]));
      return crypto.subtle.digest('SHA-256', clientData).then(function (clientHash) {
        var signed = concat(authData, new Uint8Array(clientHash));
        return crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, privateKey, signed).then(function (raw) {
          var der = derFromRaw(new Uint8Array(raw));
          if (state.mode === 'bad-signature') { der[der.length - 1] ^= 1; }
          return {
            id: id, type: 'public-key', rawId: toBuffer(bytesOf(allowed.id)),
            response: { authenticatorData: toBuffer(authData), clientDataJSON: toBuffer(clientData), signature: toBuffer(der) }
          };
        });
      });
    });
  };
})();
