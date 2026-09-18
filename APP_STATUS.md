# FacePay current status - 18 September 2026

## Implemented updates

- Android Firebase Phone OTP and Firebase ID-token exchange with the Rust API.
- Login restoration, logout and profile name/mobile/email persistence in Neon.
- Hosted Render API by default, with an explicit build-time override for local development.
- Responsive Home actions: Send, Receive, Scan, Wallet and Balance.
- Searchable demo bank linking/unlinking. No real bank connection.
- Balance service interface and unavailable state; no invented available bank balance.
- Single-camera QR and face scanning, two completed blinks, single-face tracking, timeout, duplicate locking and camera permission/lifecycle handling.
- Image-label checks for phones, tablets and displays during the blink challenge.
- Home > FACE VERIFICATION > Register Face saves account enrollment metadata through Rust into Neon.
- Demo payment: enter recipient and amount, review, complete the camera check, explicitly approve, then show local demo activity and a receipt. No money moves.

- Friendly server-connection startup screen and bounded automatic session-restore retries while the hosted server responds; saved login remains intact on temporary failures.
- Settings from the home header and Profile, with saved System/Light/Dark appearance across app routes.
- Gallery/camera profile photo selection, removal, metadata removal and encrypted per-profile device storage.

## Face registration limitations

The database stores a profile ID, a hash of a random app installation identifier, a liveness-method label and timestamps. It stores no face photo, biometric embedding or face template. It cannot identify or match a scanned recipient.

The registration lookup checks the account, not the current installation identifier. It does not enforce same-device use. The stored identifier is not hardware attestation. Blink completion is checked on the client; the backend does not independently verify a liveness proof. Screen-label checks can miss photos and replayed video. These are demo checks, not verified identity or real payment authorization.

## Data locations

- Neon: `facepay.profiles`, `facepay.auth_sessions`, `facepay.face_enrollments`.
- Firebase: Android phone authentication and Firebase user records.
- Phone secure storage: FacePay session token, random app identifier and per-profile photo. Appearance is a non-secret device preference.
- Phone memory: demo bank selection and demo payment activity. Restarting the process or signing out resets these records.
- `D:\Face Payment`: active Git checkout, code, SQL definitions and generated builds; no local production database. Older C-drive copies are not used for current updates.

See [data and storage](docs/DATA_AND_STORAGE.md).

## Remaining work

Opt-in recipient identity matching; evaluated face-template/liveness provider; server-verified device binding; stronger enrollment, recovery and deletion controls; sponsor-bank sandbox; real bank linking, authorization and balance retrieval; durable payment processing, reconciliation, support and security review; release signing.

The current demo uses a manually entered recipient name. The requested scan-recipient-face-to-find-their-account flow is not yet implemented.

## Run and verify

Use `Start-FacePay.ps1` or [RUNNING.md](docs/RUNNING.md). The synchronization report records the source revision, changed files, backup location and checks. Build artifacts are regenerated inside the destination project.
