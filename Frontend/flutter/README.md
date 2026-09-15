# FacePay Flutter app

Run Flutter commands from this folder. Android uses Firebase Phone Authentication and exchanges the Firebase ID token for a FacePay backend session. The default API is `https://facepay-rtyr.onrender.com`.

```powershell
flutter pub get
flutter run -d RZCX20ZDCLJ --dart-define=API_BASE_URL=https://facepay-rtyr.onrender.com
```

Use another connected device ID or omit `-d`. Alternatively, run `Start-FacePay.ps1` from the project root. See [running instructions](../../docs/RUNNING.md).

## Current flows

- Firebase OTP, saved session restore, profile editing and sign out.
- Home actions Send, Receive, Scan, Wallet and Balance.
- Searchable demo bank selection/unlinking and local demo payment activity.
- Balance provider interface with an unavailable state until a real provider is connected.
- Single-camera QR/face detection, two-blink interaction check and heuristic phone/display labels.
- Home Register Face action that saves enrollment metadata through the Rust API.
- Payment review, camera check and explicit approval before recording a demo activity item.

Face identity matching, real bank linking, real balance retrieval and real transfers are not implemented. Installation hashes are stored but not enforced during enrollment lookup. Photos/video replay can evade the camera checks. See [current status](../../APP_STATUS.md) for exact limits.

## Configuration and checks

Keep Android Firebase configuration at `android/app/google-services.json`, local SDK paths at `android/local.properties`, and private Neon/backend secrets exclusively in backend configuration.

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

Demo banks/payments live only in memory. A fresh app state has no seeded transactions or spendable bank balance. Device behavior needs testing in addition to automated checks. Other platforms do not yet have equivalent Firebase phone-auth configuration.
