# CakeZake Customer (Flutter)

A full-featured e-commerce customer app for the CakeZake platform — product browsing, cart & checkout, order tracking, promo codes, wallet, in-app chat, and Firebase push notifications.

---

## Requirements

- Flutter SDK `^3.44.8` (see `environment.sdk` in `pubspec.yaml`: `^3.10.8`)
- Dart SDK `^3.10.8`
- Android: minSdk per `flutter.minSdkVersion`
- iOS: 15.0+
- A Firebase project
- A Google Maps API key (Android, for `google_maps_flutter`)

---

## Setup Instructions

### 1. Firebase Configuration

1. Create a project at [Firebase Console](https://console.firebase.google.com/).
2. Add Android and iOS apps to the project.
3. Download `google-services.json` → place in `android/app/`.
4. Download `GoogleService-Info.plist` → place in `ios/Runner/`.
5. Update `lib/firebase_options.dart` with your Firebase credentials (replace all `YOUR_*` placeholders).

### 2. Google Sign-In (iOS)

In `ios/Runner/Info.plist`, replace the reversed OAuth client ID under `CFBundleURLSchemes` with the `REVERSED_CLIENT_ID` value from your `GoogleService-Info.plist`.

### 3. Google Maps API Key (Android)

In `android/app/src/main/AndroidManifest.xml`, replace the `com.google.android.geo.API_KEY` meta-data value with your Google Maps API key.

### 4. Deep Linking

In `android/app/src/main/AndroidManifest.xml`:
- Replace the `cakezake` custom scheme with the `deep_link_scheme` value from your API.
- Replace the `https://cakezake.com` host with your `AppConstants.webUrl` domain.

### 5. Backend API URL

1. Edit the matching `env/<name>.json` file (`env/demo.json`, `env/dev.json`, `env/stage.json`) with your `baseUrl` / `socketBaseUrl`.
2. Run:
   ```bash
   dart run tool/apply_config.dart
   ```
   This syncs the JSON values into `lib/core/configs/app_config.dart`.
3. Set the active environment via `AppConfig.environment` in `lib/core/configs/app_config.dart`.

### 6. Android Signing

Update `android/key.properties` with your keystore details before building a release APK.

### 7. Run

```bash
flutter clean
flutter pub get
flutter run
```

---

## Environment Files

Environments live in `env/` (`demo.json`, `dev.json`, `stage.json`). Edit the target file, then run `dart run tool/apply_config.dart` to regenerate the constants in `lib/core/configs/app_config.dart` — do not hand-edit the auto-synced block.

---

## Features

- Product browsing, categories & search
- Cart, checkout & multiple payment methods
- Order placement & tracking
- Promo codes, wallet & favourites
- Address management & location-based delivery
- In-app chat (buyer/seller/delivery) via WebSocket
- Deep linking (`cakezake://product/{id}` + universal links)
- Firebase push notifications, analytics, auth & crashlytics
- Google Sign-In
- Blog / FAQ / onboarding
- RTL & multi-language support
- Dark/light theme
