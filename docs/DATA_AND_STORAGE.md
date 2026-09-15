# Code, configuration and data locations

| Item | Location |
| --- | --- |
| Active project | `D:\Face Payment` |
| Publishing Git checkout | `C:\Users\kisha\Documents\Codex\2026-09-13\referenced-chatgpt-conversation-this-is-an\work\FacePay-github` |
| Flutter screens, state and services | `Frontend/flutter/lib` |
| Android Firebase app configuration | `Frontend/flutter/android/app/google-services.json` |
| Computer-specific SDK paths | `Frontend/flutter/android/local.properties` |
| Rust HTTP routes and database access | `Backend/rust/src` |
| Private local backend settings | `Backend/rust/.env` (ignored by Git) |
| Hosted backend settings | Render service environment |
| Backend startup migration | `Backend/rust/migrations/001_profile_auth.sql` |
| Full manual SQL setup transaction | `Backend/rust/neon_setup.sql` |
| Generated Android debug APK | `Frontend/flutter/build/app/outputs/flutter-apk/app-debug.apk` |
| Generated local Rust binaries | `Backend/rust/target` |
| Previous overwritten source/doc files | `review-backups/sync-<timestamp>/files` |

## Online database records

| Neon table | Contents |
| --- | --- |
| `facepay.profiles` | Profile ID, verified mobile number, name/email and timestamps |
| `facepay.auth_sessions` | SHA-256 session-token hash, profile reference and creation time |
| `facepay.face_enrollments` | Profile reference, hashed app identifier, `two_blink_v1` label and timestamps |

The Rust process connects to the Neon database selected by `DATABASE_URL`. `EXPECTED_DATABASE_NAME` must match. This guard does not distinguish different Neon projects/branches with the same database name.

Raw FacePay tokens are stored on the phone, not in these rows. Face templates/images are not stored. Demo bank selections and demo transactions are in app memory only and are not written to Neon.

Firebase manages phone sign-in separately. Firebase test phone numbers/codes are configured in its console. Render validates the Firebase ID token before creating a FacePay session.

## Synchronizing source

Back up changed files before copying. Preserve private `.env`, platform configuration, signing keys, IDE files and existing wrapper files. Regenerate `.dart_tool`, `build`, `target` and `.gradle` locally instead of copying another folder's caches.

A source sync does not move or reset Neon or Firebase records. Starting a local Rust backend can use the same remote Neon database as Render if configured that way. The default hosted-API app mode uses the same server as the installed demo.
