# Recall

Personal physical-asset inventory: track tools, ladders, electronics, peripherals, and appliances — with photos, purchase/warranty info, and maintenance schedules that notify your phone.

- **`server/`** — Cloudflare Worker (Hono + TypeScript), D1 (SQLite) for data, R2 for photos. Runs entirely on Cloudflare's free tier.
- **`app/`** — Flutter client (Android + web). Local notifications for upcoming maintenance.

## Server

```sh
cd server
npm install
npm run migrate:local          # apply D1 migrations locally
npm run dev                    # wrangler dev on http://localhost:8787
```

Dev login password is `recall-dev` (see `.dev.vars`, gitignored).

### Deploy

```sh
npx wrangler login
npx wrangler d1 create recall            # paste database_id into wrangler.jsonc
npx wrangler r2 bucket create recall-photos
npm run migrate:remote
node scripts/hash-password.mjs '<your-password>' | npx wrangler secret put PASSWORD_HASH
npx wrangler secret put SESSION_SECRET   # any long random string
npm run deploy
```

## API

All endpoints under `/api` require `Authorization: Bearer <token>` except login.

| Method | Path | Notes |
|---|---|---|
| POST | `/api/auth/login` | `{password}` → `{token}` (30-day expiry) |
| GET/POST | `/api/items` | list: `?q=&location_id=&label_id=&page=&per_page=` |
| GET/PUT/DELETE | `/api/items/:id` | detail includes labels, photos, schedules |
| GET/POST | `/api/locations`, `/api/labels` | plus PUT/DELETE `/:id` |
| POST | `/api/items/:id/photos` | raw image body with `Content-Type: image/*`, ≤10 MB |
| GET/DELETE | `/api/photos/:id` | streams from R2 |
| GET/POST | `/api/items/:id/maintenance` | schedules for an item |
| PUT/DELETE | `/api/maintenance/:id` | |
| POST | `/api/maintenance/:id/complete` | `{completed_at?, notes?, cost?}` — logs + advances due date |
| GET | `/api/maintenance/:id/logs` | completion history |
| GET | `/api/maintenance-upcoming?days=60` | feed for client notification scheduling |

## Flutter app

```sh
cd app
flutter pub get
flutter run          # Android device/emulator
flutter run -d chrome # web
```
