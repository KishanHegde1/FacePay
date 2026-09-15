# Run FacePay from the synchronized folder

## Same hosted backend as the phone demo

Connect and authorize the USB phone, then run:

```powershell
Set-Location 'D:\Face Payment'
.\Start-FacePay.ps1 -Mode app -Device RZCX20ZDCLJ
```

Or run directly:

```powershell
Set-Location 'D:\Face Payment\Frontend\flutter'
flutter pub get
flutter run -d RZCX20ZDCLJ --dart-define=API_BASE_URL=https://facepay-rtyr.onrender.com
```

Use another connected device ID or omit it. Android uses Firebase Phone Authentication. A local Rust process is optional for this mode. Login usually survives an app update signed with the same key; demo activity resets when the process restarts.

## Build and checks

```powershell
Set-Location 'D:\Face Payment'
.\Start-FacePay.ps1 -Mode check
.\Start-FacePay.ps1 -Mode build
```

The APK is at `Frontend/flutter/build/app/outputs/flutter-apk/app-debug.apk`. The check runs Flutter analysis/tests and Rust formatting/tests. This is a debug build; release signing remains a separate setup step. The synchronization adds no package dependency.

## Optional local Rust API

In the first terminal:

```powershell
Set-Location 'D:\Face Payment'
.\Start-FacePay.ps1 -Mode backend
```

The existing private `Backend/rust/.env` is preserved. Startup validates the database name and applies idempotent schema setup. Android Firebase login also requires `FIREBASE_WEB_API_KEY` in the local backend configuration, even when Firebase test numbers are used. Keep it private. Firebase phone login is separate from Rust's loopback-only development OTP mode.

In a second terminal, with the backend listening on port 8080:

```powershell
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" -s RZCX20ZDCLJ reverse tcp:8080 tcp:8080
Set-Location 'D:\Face Payment'
.\Start-FacePay.ps1 -Mode app -Device RZCX20ZDCLJ -ApiBaseUrl http://127.0.0.1:8080
```

Production Render keeps `AUTH_TEST_ENABLED=false` and uses Render's assigned port.

## Common problems

- **No pubspec.yaml:** use `Frontend/flutter` or the root run script.
- **Not a Git repository:** D is a source copy. Use the publishing checkout named in the root README for Git commands.
- **Missing packages:** run `flutter pub get` in the Flutter folder.
- **Restore timeout:** check internet/Render availability; temporary errors retain the saved token.
- **SQL database guard failure:** use the full `neon_setup.sql` transaction or let backend startup run migrations.
- **Scripts blocked by local policy:** use the direct Flutter commands above, without changing machine-wide policy.
