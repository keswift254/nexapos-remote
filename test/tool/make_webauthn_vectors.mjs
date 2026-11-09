// Makes test/fixtures/webauthn/vectors.json: sign-in answers shaped exactly like a WebAuthn authenticator's
// (authenticator data, client data JSON, ASN.1 DER ES256 signature), made with a real P-256 key, together
// with the raw r||s form the browser's signature check wants. Every vector is checked here with Node's own
// WebCrypto before it is written, so the Dart test can rely on them being genuine.
//
// Run: node test/tool/make_webauthn_vectors.mjs
import { createHash, generateKeyPairSync, sign, webcrypto } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

const out = new URL('../fixtures/webauthn/vectors.json', import.meta.url);
const b64url = (buffer) => Buffer.from(buffer).toString('base64url');
const sha256 = (data) => createHash('sha256').update(data).digest();

const rpId = 'nexapos.cc';
const origin = 'https://nexapos.cc';
const vectors = [];
let shortCount = 0;

for (let i = 0; vectors.length < 40 || shortCount < 3; i++) {
  if (i > 4000) throw new Error('could not find enough short-integer signatures');
  const { publicKey, privateKey } = generateKeyPairSync('ec', { namedCurve: 'P-256' });
  const spki = publicKey.export({ type: 'spki', format: 'der' });
  const challenge = webcrypto.getRandomValues(new Uint8Array(32));
  const clientData = Buffer.from(JSON.stringify({ type: 'webauthn.get', challenge: b64url(challenge), origin, crossOrigin: false }));
  const flags = 0x05; // user present + user verified
  const counter = Buffer.alloc(4);
  counter.writeUInt32BE(i);
  const authData = Buffer.concat([sha256(rpId), Buffer.from([flags]), counter]);
  const signed = Buffer.concat([authData, sha256(clientData)]);
  const der = sign('sha256', signed, { key: privateKey, dsaEncoding: 'der' });
  const raw = sign('sha256', signed, { key: privateKey, dsaEncoding: 'ieee-p1363' });
  // Both encodings are the SAME signature only if the same random nonce was used - they were not, so check each one
  // on its own and keep the pair together only through the DER form (the raw form is derived from it below).
  const parsed = parseDer(der);
  const derivedRaw = Buffer.concat([pad32(parsed.r), pad32(parsed.s)]);
  const key = await webcrypto.subtle.importKey('spki', spki, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['verify']);
  const ok = await webcrypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, key, derivedRaw, signed);
  const okRaw = await webcrypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, key, raw, signed);
  if (!ok || !okRaw) throw new Error('vector does not verify');
  const short = parsed.r.length < 32 || parsed.s.length < 32;
  if (short) shortCount++;
  if (vectors.length < 40 || short) {
    vectors.push({
      rpId, origin,
      spki: b64url(spki), challenge: b64url(challenge),
      authenticatorData: b64url(authData), clientDataJson: b64url(clientData),
      derSignature: b64url(der), rawSignature: b64url(derivedRaw),
      rIsShort: parsed.r.length < 32, sIsShort: parsed.s.length < 32,
      rHasLeadingZeroPad: parsed.rPadded, sHasLeadingZeroPad: parsed.sPadded,
    });
  }
}

function parseDer(der) {
  let o = 2;
  if (der[1] & 0x80) o += der[1] & 0x7f;
  const read = () => {
    if (der[o++] !== 0x02) throw new Error('not an integer');
    const length = der[o++];
    const bytes = der.subarray(o, o + length);
    o += length;
    let trimmed = bytes;
    let padded = false;
    while (trimmed.length > 1 && trimmed[0] === 0) { trimmed = trimmed.subarray(1); padded = true; }
    return { value: Buffer.from(trimmed), padded };
  };
  const r = read();
  const s = read();
  return { r: r.value, s: s.value, rPadded: r.padded, sPadded: s.padded };
}
function pad32(buffer) { return Buffer.concat([Buffer.alloc(32 - buffer.length), buffer]); }

mkdirSync(dirname(out.pathname.replace(/^\/([A-Za-z]:)/, '$1')), { recursive: true });
writeFileSync(out, JSON.stringify({ made_by: 'test/tool/make_webauthn_vectors.mjs', vectors }, null, 1) + '\n');
console.log(`wrote ${vectors.length} vectors (${shortCount} with a short r or s; ${vectors.filter((v) => v.rHasLeadingZeroPad || v.sHasLeadingZeroPad).length} with a zero-padded integer)`);
