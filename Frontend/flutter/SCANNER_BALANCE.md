# Scanner and bank balance

The dashboard now has Send, Receive, Scan, Wallet and Balance actions. The action row scrolls horizontally on small screens. Existing authentication, profile storage, Rust APIs and Neon integration are unchanged.

## Scanner flow

One `camera` controller supplies transient images to ML Kit. QR scanning and fast face detection share each accepted image. The frame gate permits one inference at a time and samples at most once per 300 ms. QR results take priority within a frame. No recognition model, backend matching, image upload or image persistence is performed.

A QR result stops the camera and opens an unverified-content review screen. It never opens a URL, invents a recipient, parses a payable amount or creates a transaction. The existing payment-setup screen remains available from that review.

One face must be detected in three consecutive sampled frames before the same camera enters the two-blink interaction check. Only this phase enables eye classification, sampling at most once per 80 ms. Both eyes must transition from open to closed to open twice. Wink-only readings, missing classifications, multiple faces, loss of tracking, a different tracking ID, a nonfrontal pose, long closures and long sample gaps cannot complete the challenge. The phase times out after 20 seconds.

During the blink check only, an on-device image labeler also samples the same camera feed at most once per 900 ms. Explicit phone, tablet, and display labels stop the check with guidance to scan the person directly. This is a conservative warning signal, **not replay-resistant liveness, presentation-attack detection (PAD), identity verification, or permission to pay**. A video replay, printed face, or unlabeled screen can still pass this warning; secure liveness/PAD, enrolled face matching and payment authorization remain integration work.

Detected results lock further scanning. Returning with Back leaves the scanner paused; Scan again explicitly rearms it with a one-second debounce. Backgrounding, camera switching and leaving the scanner release camera resources and discard late results. Permission denial, restrictions, missing cameras and detector errors display retry guidance. Web and desktop show an unsupported-scanning message without requesting a camera.

## Balance integration

`BankBalanceService` provides the selected account and `fetchBalance`. Inject a production implementation through `AppShell.balanceService`; the Balance UI does not need to change. The default `UnconnectedBankBalanceService` maps only the existing local bank-preview selection and always returns `BankBalanceUnavailable`.

The screen labels the local bank preview honestly and never displays `AppState.balance` as real bank money. No account is automatically selected or created. Fetch and Refresh show that a payment provider is required. Duplicate requests are blocked; changing/unlinking accounts discards pending results. Errors and timeouts allow retry. A future `BankBalanceAvailable` result must come from an authorized provider and supplies minor units, currency, fraction digits and retrieval time. Results remain in screen memory and are not saved to Neon or AppState.

## Dependencies and platform setup

Runtime additions:

- `camera: ^0.12.1`
- `google_mlkit_barcode_scanning: ^0.16.1`
- `google_mlkit_face_detection: ^0.15.1`
- `google_mlkit_image_labeling: ^0.16.1`

`camera_platform_interface: ^2.13.1` is a dev dependency for native-boundary tests. The lockfile also contains the camera platform implementations and ML Kit commons. CameraX is used as the camera package's default Android implementation; a second camera plugin is unnecessary.

Android requires API 24 or newer. Camera permission and an optional camera hardware declaration are configured in the manifest. iOS camera usage text, deployment target 15.5 and CocoaPods configuration are included. Audio is disabled.

After updating the checkout, run `flutter pub get`, then `flutter run` for the desired device. On a Mac, run `flutter build ios --no-codesign` with Xcode/CocoaPods installed; the iOS native build cannot be validated from Windows. Real QR/face images and blink thresholds must be checked on physical Android and iOS devices, including denied permissions, rotation, switching cameras, background/resume, multiple faces and low light.

## Local demo payment

After a local demo bank is chosen, the Send action can record a user-entered recipient and amount as a clearly labelled in-memory demo item. It never changes `AppState.balance`, contacts a bank/PSP, calls the Rust or Neon backends, or survives an app restart. It is for trying the UI only; verified payments require the provider integrations below.

Before production face payments, connect secure liveness/PAD, recognition/enrollment, authenticated recipient lookup, PSP/UPI bank linking, live balance retrieval and payment authorization.

## References

- [Flutter camera package](https://pub.dev/packages/camera)
- [ML Kit barcode Flutter package](https://pub.dev/packages/google_mlkit_barcode_scanning)
- [ML Kit face Flutter package](https://pub.dev/packages/google_mlkit_face_detection)
- [ML Kit image labeling Flutter package](https://pub.dev/packages/google_mlkit_image_labeling)
- [Google face detection concepts](https://developers.google.com/ml-kit/vision/face-detection/face-detection-concepts)
