import { test } from 'node:test';
import assert from 'node:assert';
import { createToken, verifyToken, verifyPassword } from '../src/auth.ts';

test('auth token creation and verification', async () => {
  const secret = 'super-secret-key-12345';
  const token = await createToken(secret);
  assert.strictEqual(typeof token, 'string');
  assert.strictEqual(token.includes('.'), true);

  const isValid = await verifyToken(secret, token);
  assert.strictEqual(isValid, true);

  const wrongSecret = await verifyToken('wrong-secret', token);
  assert.strictEqual(wrongSecret, false);

  const corruptedToken = await verifyToken(secret, token + 'tampered');
  assert.strictEqual(corruptedToken, false);

  const invalidFormat = await verifyToken(secret, 'not-a-token');
  assert.strictEqual(invalidFormat, false);
});

test('auth verifyPassword handles PBKDF2 hash correctly', async () => {
  // Let's test with a known pbkdf2 hash format: pbkdf2:iterations:saltB64:hashB64
  // Generate salt and hash for password "secret123"
  const enc = new TextEncoder();
  const password = 'mySecretPassword!';
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const iterations = 1000;
  const key = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', hash: 'SHA-256', salt, iterations },
    key,
    256
  );

  let saltBin = '';
  for (const b of salt) saltBin += String.fromCharCode(b);
  const saltB64 = btoa(saltBin);

  let hashBin = '';
  for (const b of new Uint8Array(bits)) hashBin += String.fromCharCode(b);
  const hashB64 = btoa(hashBin);

  const stored = `pbkdf2:${iterations}:${saltB64}:${hashB64}`;

  assert.strictEqual(await verifyPassword('mySecretPassword!', stored), true);
  assert.strictEqual(await verifyPassword('wrongPassword', stored), false);
  assert.strictEqual(await verifyPassword('mySecretPassword!', 'invalid:format'), false);
  assert.strictEqual(await verifyPassword('mySecretPassword!', 'pbkdf2:-1:salt:hash'), false);
});
