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

The server URL and password are entered on the login screen at runtime (stored in secure
storage), so no build-time configuration is needed to point the app at your Worker.

### Deploy to Android

**Quick install (debug build, no signing setup):**

```sh
cd app
flutter build apk --debug
# installs on a connected device/emulator:
flutter install
```

**Release build (for real installs / Play Store):**

1. Generate a signing key (one time, keep this file and its passwords safe — losing it means
   you can never publish an update to the same app under the same identity):

   ```sh
   keytool -genkey -v -keystore recall-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias recall
   ```

2. Copy `app/android/key.properties.example` to `app/android/key.properties` and fill in the
   passwords/alias and the absolute path to the `.jks` file you just created. This file is
   gitignored — never commit it.

3. Build:

   ```sh
   cd app
   flutter build apk --release          # single universal APK -> build/app/outputs/flutter-apk/app-release.apk
   # or, smaller per-ABI APKs:
   flutter build apk --release --split-per-abi
   # or, for Play Store upload:
   flutter build appbundle --release    # -> build/app/outputs/bundle/release/app-release.aab
   ```

   `build.gradle.kts` automatically signs the release build with `key.properties` when present,
   falling back to the debug key otherwise.

4. Install directly on a device (sideloading, no Play Store):

   ```sh
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```

   Or transfer the APK to the phone and open it (enable "Install unknown apps" for the file
   source first).

5. To publish on the Play Store instead, upload the `.aab` from step 3 via the
   [Play Console](https://play.google.com/console).

### Automated Release (GitHub Actions)

When you tag a commit and push the tag to GitHub, a GitHub Actions workflow will automatically build the release APKs per ABI and attach them to a new GitHub Release.

To trigger a release:

1. Create an annotated tag (e.g., `v1.0.0`):

   ```sh
   git tag -a v1.0.0 -m "Release version 1.0.0"
   ```

2. Push the tag to GitHub:

   ```sh
   git push origin v1.0.0
   ```
   (Or use `git push --tags` to push all local tags).
