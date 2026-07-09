#!/usr/bin/env node
// Generates a PASSWORD_HASH value for the recall server.
// Usage: node scripts/hash-password.mjs <password>
import { pbkdf2Sync, randomBytes } from 'node:crypto';

const password = process.argv[2];
if (!password) {
  console.error('usage: node scripts/hash-password.mjs <password>');
  process.exit(1);
}
const iterations = 100_000;
const salt = randomBytes(16);
const hash = pbkdf2Sync(password, salt, iterations, 32, 'sha256');
console.log(`pbkdf2:${iterations}:${salt.toString('base64')}:${hash.toString('base64')}`);
