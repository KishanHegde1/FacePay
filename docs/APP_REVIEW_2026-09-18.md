# FacePay settings, profile photo and regression review — 18 September 2026

## Source and scope

Active source/Git folder: `D:\Face Payment`. All changes in this update are reviewed, built and published from that folder. Backend OTP, bank API integration and database schema were not modified.

## Changes

- Settings accessible from the home header gear and Profile; persistent System, Light and Dark choices. System follows device appearance changes.
- Context-scoped route/card/form/navigation colors, readable dark-mode foregrounds and pastel surfaces. The camera and branded splash retain dedicated dark artwork.
- Gallery/camera profile photo selection, replacement and removal. Photos update the Profile avatar and home header.
- Photo service behind an injectable interface; encrypted storage scoped to profile ID, bounded image size, image validation, metadata removal, cancellation/permission/storage failure handling and Android lost-picker recovery with account ownership checks.
- Responsive login badge and larger navigation height for accessibility text. Startup timing and existing navigation/login/payment behavior are retained.
- `image_picker: ^1.2.3`; lockfile and generated platform plugin registrations updated. iOS photo and camera descriptions included. Android uses the native picker with existing camera configuration.

## Verification

- `flutter analyze`: no issues.
- Full `flutter test`: 172 passed. Existing Firebase/login/profile/session, demo payment, scanner, blink, permissions and banking boundary regressions remain covered.
- New tests: appearance persistence and system brightness changes; gallery/camera/remove UI; cancellation and permission feedback; secure per-profile persistence, invalid/oversized image rejection and Android recovery ownership.
- Layout matrix: 11 screens in both themes at widths 320, 390, 768, 1024 and 1440; 320 also tested at 1.8 text scale, for 132 screen/size/theme combinations. No layout exceptions in those scenarios.
- Rendered light/dark login, dashboard, profile and settings screenshots inspected. Previews are local under `Frontend/flutter/build/review` and not committed.
- `cargo test --locked`: 15 passed, 1 ignored. The ignored test deliberately writes to live Neon and was not run.
- Android debug APK build succeeded with the hosted Render URL. Installed with `adb install -r` on Samsung SM-A156E (`RZCX20ZDCLJ`), launched successfully and its running process/foreground activity confirmed. Owner should try native gallery/camera selection on the phone; no personal photo was taken or saved for this review.

Checks cover the exercised states; they cannot guarantee every future data size, platform or camera environment. Gallery/camera automated tests use an injected picker; real hardware selection should also be tried by the owner.

## Existing limitations observed

- Profile photos are device-local and not synchronized to Neon or another phone. They are separate from face-registration data.
- Face enrollment stores metadata, not a biometric template. It cannot identify another scanned recipient. Two blinks and screen-label checks are client-side demo checks; the installation identifier is not hardware attestation and same-device authorization is not enforced by the existing server lookup.
- Demo bank/payment data remain local. The HDFC scaffold is not a working provider integration; bank documentation/access are still needed. No real bank balance or funds transfer is claimed.
- Release builds still use debug signing in the existing Android configuration. Production signing is separate work.
- Current Android build warns that Firebase plugins use the Kotlin Gradle Plugin; a future Flutter SDK upgrade will require checking plugin compatibility. This update does not upgrade those dependencies.

## Changed files

- `.gitignore`
- `APP_STATUS.md`
- `Frontend/flutter/ios/Runner/Info.plist`
- `Frontend/flutter/lib/data/app_state.dart`
- `Frontend/flutter/lib/main.dart`
- `Frontend/flutter/lib/screens/activity_screen.dart`
- `Frontend/flutter/lib/screens/app_shell.dart`
- `Frontend/flutter/lib/screens/auth_screen.dart`
- `Frontend/flutter/lib/screens/balance_screen.dart`
- `Frontend/flutter/lib/screens/bank_link_screen.dart`
- `Frontend/flutter/lib/screens/dashboard_screen.dart`
- `Frontend/flutter/lib/screens/payment_screen.dart`
- `Frontend/flutter/lib/screens/profile_screen.dart`
- `Frontend/flutter/lib/screens/receive_screen.dart`
- `Frontend/flutter/lib/screens/scan_result_screen.dart`
- `Frontend/flutter/lib/screens/settings_screen.dart`
- `Frontend/flutter/lib/screens/wallet_screen.dart`
- `Frontend/flutter/lib/services/app_settings.dart`
- `Frontend/flutter/lib/services/profile_photo_service.dart`
- `Frontend/flutter/lib/ui/design.dart`
- `Frontend/flutter/linux/flutter/generated_plugin_registrant.cc`
- `Frontend/flutter/linux/flutter/generated_plugins.cmake`
- `Frontend/flutter/macos/Flutter/GeneratedPluginRegistrant.swift`
- `Frontend/flutter/pubspec.lock`
- `Frontend/flutter/pubspec.yaml`
- `Frontend/flutter/test/profile_photo_service_test.dart`
- `Frontend/flutter/test/settings_photo_test.dart`
- `Frontend/flutter/test/theme_layout_test.dart`
- `Frontend/flutter/windows/flutter/generated_plugin_registrant.cc`
- `Frontend/flutter/windows/flutter/generated_plugins.cmake`
- `README.md`
- `docs/APP_REVIEW_2026-09-18.md`
- `docs/DATA_AND_STORAGE.md`
- `docs/RUNNING.md`
