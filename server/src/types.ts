export type Bindings = {
  DB: D1Database;
  PHOTOS: R2Bucket;
  /** Secret: HMAC key for session tokens */
  SESSION_SECRET: string;
  /** Secret: "pbkdf2:<iterations>:<saltB64>:<hashB64>", generate with scripts/hash-password.mjs */
  PASSWORD_HASH: string;
};

export type App = { Bindings: Bindings };
