# FacePay

Flutter Android app with Firebase Phone Authentication and a Rust API backed by Neon PostgreSQL. Payment and face-check flows are demos.

## Project layout

```text
Face Payment/
  Frontend/flutter/       App source, Android project, tests and assets
  Backend/rust/           API source, migrations and backend tests
  docs/                   Data locations and run instructions
  Start-FacePay.ps1       Run app, build APK, run backend or check code
  APP_STATUS.md           Implemented features and limitations
  review-backups/         Previous source files backed up before sync
```

Open this root folder in VS Code. Flutter commands belong in `Frontend/flutter`; Rust commands belong in `Backend/rust`.

## Run the same app as the installed demo

```powershell
Set-Location 'D:\Face Payment'
.\Start-FacePay.ps1 -Mode app -Device RZCX20ZDCLJ
```

Connect and authorize the USB phone first. Use another device ID or omit `-Device`. The script selects `https://facepay-rtyr.onrender.com`, so you can use the hosted backend directly.

```powershell
# Other tasks, from the project root
.\Start-FacePay.ps1 -Mode build
.\Start-FacePay.ps1 -Mode check
.\Start-FacePay.ps1 -Mode backend
```

See [running instructions](docs/RUNNING.md), [data and storage](docs/DATA_AND_STORAGE.md) and [current status](APP_STATUS.md). The backend mode uses the private local `.env` and applies guarded migrations to its configured Neon database.

## Version control

Repository: https://github.com/KishanHegde1/FacePay

The synchronized D folder is a working source copy. The existing Git checkout used for publishing is:

```text
C:\Users\kisha\Documents\Codex\2026-09-13\referenced-chatgpt-conversation-this-is-an\work\FacePay-github
```

Git commands must run inside a Git checkout. Future edits in either folder do not automatically appear in the other; review and back up differences before syncing again. Keep private environment files, signing keys, generated builds and local backups out of Git.
