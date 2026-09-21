# FacePay full application review - 21 September 2026

Active source and Git folder: `D:\Face Payment`.

## Result

The existing Flutter and Rust code compiles and its automated checks pass. The
new demo completion screen is shown for 4.5 seconds after explicit approval,
speaks "Thanks, bro." through the device text-to-speech engine, and then shows
the existing local receipt. Speech failure does not change recorded state or
block the receipt. Leaving the flow stops speech and cancels the timer.

The confirmation continues to say demo/no money moved. FacePay still has no
real bank payment operation and must not show this as a settled bank payment.

## Current application flow

1. Native launch screen, two-second logo, then the three-second FacePay splash.
2. Firebase phone authentication and Rust token exchange, or the local-only
   development OTP when explicitly enabled on loopback.
3. Server-verified session restore, profile and dashboard.
4. Optional local profile photo and server-side face-enrollment metadata.
5. Searchable demo bank selection; no provider OTP or bank account is fetched.
6. Demo payment entry, review, two-blink camera check and explicit approval.
7. 4.5-second visual/voice confirmation, then an in-memory demo receipt and
   activity item. Restarting/signing out removes demo bank/payment activity.

## Multiple users and 1,000 simultaneous payments

Flutter runs a separate in-memory `AppState` for each installed/running app.
The backend derives ownership from each bearer session and Neon tables scope
profile, enrollment and linked-account reads/writes to that profile. The Axum
server and SQLx are asynchronous, and Firebase now reuses one HTTP client.

This is not evidence that 1,000 people can pay at the same time. There is no
real payment endpoint, provider authorization, durable payment record, PSP
callback, reconciliation worker or idempotent payment state machine to load
test. The current Render instance has one CPU and the Rust service uses a
five-connection database pool with a ten-second acquisition timeout. Capacity
also depends on Render, Neon and provider quotas. A controlled UAT load test,
with bank permission and realistic latency/failure callbacks, is required.

Before claiming that capacity, implement the approved provider flow, define an
SLO, add metrics/tracing, use a production Render plan, size the database pool
against Neon limits, horizontally scale stateless API instances, and test
gradually (for example 10, 50, 100, then 1,000 concurrent requests). Never load
test the public provider or current free service without written permission.

## Database coverage

The migration and paste-ready Neon setup define the same application tables:

| Table | Current purpose |
| --- | --- |
| `facepay.profiles` | User profile and verified mobile number |
| `facepay.auth_sessions` | Hashed FacePay bearer sessions |
| `facepay.face_enrollments` | Installation hash and two-blink method metadata; no face template |
| `facepay.linked_bank_accounts` | Future provider-verified references and masked display fields |

No table is missing for the currently implemented persistent features. Demo
payments intentionally remain in memory and must not be inserted into a real
transaction table.

A real payment system still needs bank-approved schemas for payment intents,
provider transaction IDs, immutable status transitions, idempotency keys,
callbacks/events, reversals/refunds, reconciliation attempts and an audit trail.
Those tables should be designed from the selected PSP contract so FacePay does
not invent incompatible or misleading payment records.

## Important release gaps

- ICICI/HDFC modules do not perform a bank request. ICICI discovery contracts
  are offline preparation only; HDFC routes return an unavailable response.
- Face registration stores no biometric template and cannot identify another
  person. The client blink interaction is not bank payment authorization.
- Sessions currently have no server-enforced expiry. Add expiry/rotation and
  revocation policy before a production release.
- The development OTP store is process-local and is unsuitable for multiple
  backend replicas. Production uses Firebase, and test authentication is
  rejected outside loopback development/test mode.
- There is no general per-user/IP production rate limiter, provider circuit
  breaker, retry/idempotency policy, telemetry or alerting.
- Android still uses `com.example.face_payment` and release builds use the
  debug signing key. Set a permanent application ID and protected release key.
- The linked-account table is unused until a bank verifies ownership. Demo bank
  labels are local and never written to that table.

## Package and platform review

`flutter_tts 4.2.5` is locked by `pubspec.lock`. Android already uses minSdk 24,
which satisfies the package minimum, and the manifest declares the Android 11+
TTS service query. Flutter generated macOS and Windows plugin registration
files during `pub get`. iOS requires no new usage-description permission for
speech synthesis. The phone must have an enabled text-to-speech engine/voice;
otherwise the visual confirmation remains functional.

## Verification performed

- `flutter pub get`
- `flutter analyze --no-pub`
- Full `flutter test --no-pub`
- Android release APK build with the hosted API URL
- `cargo fmt --check`
- Full offline `cargo test` (the explicit live-Neon mutation test remains
  skipped)
- Rust release build
- Git diff/whitespace and generated plugin registration review

Automated tests do not prove bank correctness, 1,000-user payment capacity,
native speech quality on every phone, or production security certification.
