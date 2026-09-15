# FacePay Flutter app

OTP development login and profile editing are connected to the Rust API and Neon. See [backend setup](../../Backend/rust/README.md) for environment values, database tables, Android fingerprints, and run instructions.

The profile screen has name, verified mobile number, optional email, save, and sign out. Login is stored securely and restored on reopen. Only verified backend sessions open the dashboard; there is no demo login bypass.

The dashboard and wallet now include **Link bank account**. It opens a searchable directory of 20 popular bank names and lets the user link a clearly marked in-session demo account. It never requests a bank account number, OTP, UPI PIN, password, or bank login, and it does not call the backend or Neon. Use a regulated payment or Account Aggregator provider before replacing this demo with a real connection.

The app defaults to the deployed Render API at `https://facepay-rtyr.onrender.com`.
For a local development backend, explicitly override the address. The local test
account uses mobile 7349083847 and OTP 000000; no SMS is sent.

```powershell
flutter pub get
# Web
flutter run -d chrome --web-port 5173 --dart-define=API_BASE_URL=http://localhost:8080
# USB Android / emulator
adb reverse tcp:8080 tcp:8080
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

Use `--dart-define-from-file=.env` if you copy the frontend environment template. The frontend file contains only API_BASE_URL, never Neon credentials.

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

Generate screenshots with `flutter test --no-pub --dart-define=SAVE_PREVIEWS=true`. Output is in build/previews.

The bank directory remains a clearly marked in-session demo. Fresh accounts contain no seeded balance, payment history, contacts, sample merchants, QR requests, or virtual card data. Send, receive, scan, and payment screens are inactive setup views until a real payment provider is connected. Real SMS, payments, bank connectivity, camera, and biometrics are not integrated. Platform secure storage and uninstall/reinstall need device testing; widget tests validate the app's session logic.
