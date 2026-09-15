# Firebase Phone OTP setup

FacePay now defaults to the deployed API at `https://facepay-rtyr.onrender.com`.
The current Render API deliberately has no SMS delivery configured, so it cannot
send real OTPs yet. Firebase Phone Authentication is the next authentication
provider; do not enable it with a demo or hard-coded OTP.

## Android Firebase project

1. In the Firebase console, create or select the FacePay Firebase project.
2. Add an Android app using this exact package name: `com.example.face_payment`.
3. Download the generated `google-services.json` and put it at
   `android/app/google-services.json` in this Flutter project.
4. In **Authentication → Sign-in method**, enable **Phone**.
5. Add the debug SHA-1 and SHA-256 fingerprints to the Android app settings.
   Run this on the development computer to display them:

   ```powershell
   keytool -list -v -alias androiddebugkey -keystore "$HOME\.android\debug.keystore" -storepass android -keypass android
   ```

6. For Firebase test sign-ins, add the chosen test phone number and its test
   code in Firebase Authentication. Firebase controls those codes; FacePay must
   never contain a built-in test OTP in a production build.

## What is needed before the app can use Firebase OTP

`google-services.json` configures the Android app only. It is not a server
credential. The Rust API must verify the Firebase ID token and then issue its
existing FacePay session token before profile and Neon requests can be trusted.

Provide the Firebase project ID to configure Render. Keep any Firebase
Admin service-account JSON private and store it only in Render's encrypted
environment settings, never in this Flutter project or GitHub. Once the Android
file and Firebase project ID are present, the next code update will add
`firebase_core`, `firebase_auth`, Android's Google Services Gradle plugin, and
the Rust token-verification endpoint.
