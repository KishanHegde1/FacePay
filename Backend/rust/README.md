# FacePay Rust API setup

The Android app uses Firebase Phone Authentication, then exchanges its Firebase ID token with this API. Login sessions, profiles and face enrollment metadata persist in Neon PostgreSQL. Demo banks and payments live only in app memory. See [current status](../../APP_STATUS.md) and [run instructions](../../docs/RUNNING.md).

## Local configuration

`Backend/rust/.env` contains your private Neon connection settings. The selected database is **neondb**. Never copy this file into Flutter or commit it.

`Backend/rust/.env.example` is the reusable template:

- `DATABASE_URL`: Copy the PostgreSQL URL from Neon Connect after selecting the correct project, branch, database, and role. Keep `sslmode=require` (or stronger). Use the pooled hostname provided by Neon.
- `EXPECTED_DATABASE_NAME=neondb`: Must exactly match the database selected in the URL. Startup checks the actual database before creating tables. Also check the Neon project/branch hostname: the name guard cannot distinguish two branches both named neondb.
- `BIND_ADDR=127.0.0.1:8080`: Local development API.
- `FRONTEND_ORIGINS`: Exact local web origins; default port 5173.
- `APP_ENV=development`, `AUTH_TEST_ENABLED=true`, `AUTH_TEST_PHONE=+917349083847`, `AUTH_TEST_OTP=000000`: Explicit development test login. This does not send SMS. Production startup rejects enabled test authentication.

## Render deployment

Create a Rust web service with Root Directory `Backend/rust` when the repository contains both frontend and backend. Keep Build Command `cargo build --release` and Start Command `cargo run --release`.

Render provides `PORT`; when `BIND_ADDR` is not set, the backend binds to `0.0.0.0:$PORT` automatically. Add these Render environment variables:

- `APP_ENV=production`
- `AUTH_TEST_ENABLED=false`
- `DATABASE_URL`: Neon pooled PostgreSQL URL with `sslmode=require` or stronger (secret)
- `EXPECTED_DATABASE_NAME=neondb`
- `FRONTEND_ORIGINS=https://YOUR-FRONTEND-DOMAIN` once the web frontend is deployed. Each value must be an exact HTTPS origin; multiple origins are comma-separated.
- `FIREBASE_WEB_API_KEY`: Firebase project's Web API key. The backend uses it only to ask Firebase to validate an ID token; keep it in Render environment settings, never in a Flutter `.env`.

Do not add `BIND_ADDR`, `PORT`, `AUTH_TEST_PHONE`, or `AUTH_TEST_OTP` on Render. The `/health` endpoint is available for Render health checks after database startup succeeds.

The existing local .env is configured. Start the backend from `Backend/rust` with `cargo run`. Startup creates the requested tables automatically. You can alternatively inspect `neon_setup.sql` in Neon SQL Editor; it is already configured for neondb. Do not paste the Rust .env into SQL Editor.

Start Flutter from `Frontend/flutter`:

```powershell
# Browser
flutter run -d chrome --web-port 5173 --dart-define=API_BASE_URL=http://localhost:8080

# Android device connected by USB (also works with an emulator)
adb reverse tcp:8080 tcp:8080
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

The frontend `.env.example` contains only the public API URL. To load a copied Flutter `.env`, pass `--dart-define-from-file=.env`; Flutter does not load it automatically. Neon credentials belong exclusively in the Rust backend.

## Profile and session behavior

Enter the test mobile number, request a code, then enter `000000`. Only backend verification opens the dashboard. No SMS is sent in this mode.

The app saves the bearer token in secure platform storage and validates it with `/auth/me` on reopening. Closing the app does not require another OTP. Temporary network failure offers retry and preserves the saved login. Invalid/revoked sessions require login again.

Logout removes the local token and requests server revocation. If offline, local logout still completes; server revocation cannot be guaranteed until the backend is reachable. Android backup is disabled so reinstall does not restore the login. The installation marker clears any surviving iOS keychain token. Actual uninstall/reinstall must still be checked on a device; Windows widget tests cannot verify OS storage behavior.

The profile screen contains name, verified read-only mobile number, and optional email. It reports success only after the API confirms the database update. New users start with blank name/email. Mobile number changes and client-selected profile IDs are rejected.

| Table | Fields |
| --- | --- |
| `facepay.profiles` | `id`, `name`, `mobile_no` (unique), `email`, `created_at`, `updated_at` |
| `facepay.auth_sessions` | `token_hash` (SHA-256), `profile_id`, `created_at` |
| `facepay.face_enrollments` | `profile_id`, hashed app-installation binding, liveness method, timestamps; no raw face data |

Session rows persist across backend restarts; raw bearer tokens are not stored in Neon. They remain valid until revoked. Uninstall clears the device token; it cannot notify the server to delete its old session row.

## API

- `POST /auth/request-otp` — `{ "phone": "+917349083847" }`
- `POST /auth/verify-otp` — `{ "challenge_id": "...", "otp": "000000" }` for local development only
- `POST /auth/firebase` — `{ "id_token": "..." }` after Firebase Phone Authentication; Firebase validates the ID token and the API creates a FacePay session
- `GET /auth/me` — restore account with Bearer token
- `GET /profile` — read own profile
- `PATCH /profile` — `{ "name": "Your name", "email": "you@example.com" }`; blank/null email clears it
- `GET /face-enrollment` — checks whether the account has enrollment metadata; it does not compare the current app installation
- `POST /face-enrollment` — stores a hashed client-supplied app identifier and liveness-method label; the backend does not independently verify liveness
- `POST /auth/logout` — revoke Bearer token

Firebase Phone Authentication is used by Android when the Firebase app enables Phone sign-in and has the required signing fingerprints. The debug Android signing fingerprints are:

- Package: `com.example.face_payment`
- SHA-1: `4E:B6:A0:E7:76:FB:59:40:33:37:82:29:95:95:32:E3:74:F9:68:36`
- SHA-256: `F2:43:D2:ED:14:F5:0E:E1:15:9A:3D:3B:70:9D:30:FD:3C:3B:60:14:14:55:B7:37:55:A2:59:3B:62:49:90:EF`

These identify the debug signing certificate, not a phone number. Release signing has different fingerprints.

## Face enrollment limitations

No face template, image or identity match is stored or performed. Installation identifiers are currently recorded but not enforced at lookup. Client blink/screen checks are a demo interaction and may miss replay attacks. They do not authorize real payments.

## Checks

`cargo test` runs isolated validation/OTP/API tests without database credentials. The ignored `live_neon_profile_roundtrip` test is explicitly run with `cargo test live_neon_profile_roundtrip -- --ignored`; it uses the selected local database and creates/removes an isolated test profile.

`flutter analyze --no-pub` and `flutter test --no-pub` check the frontend. Android secure storage and uninstall behavior still require a physical device/emulator test.

