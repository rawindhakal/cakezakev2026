# CakeZake Deliveryboy (Flutter)

A full-featured delivery partner app for the CakeZake platform — order pickup/delivery tracking, live chat with buyers/sellers, wallet & earnings, cash collection, settlement history, and Firebase push notifications.

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

### 2. Google Maps API Key (Android)

In `android/app/src/main/AndroidManifest.xml`, replace the `com.google.android.geo.API_KEY` meta-data value with your Google Maps API key.

### 3. Backend API URL

1. Edit the matching `env/<name>.json` file (`env/demo.json`, `env/dev.json`, `env/stage.json`) with your `baseUrl` / `socketBaseUrl`.
2. Run:
   ```bash
   dart run tool/apply_config.dart
   ```
   This syncs the JSON values into `lib/core/configs/app_config.dart`.
3. Set the active environment via `AppConfig.environment` in `lib/core/configs/app_config.dart`.

### 4. Android Signing

Update `android/key.properties` with your keystore details before building a release APK.

### 5. Run

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

- Order pickup & delivery flow tracking
- OSM-based live map/route rendering + Google/Apple Maps navigation deep links
- In-app chat (buyer/seller) via WebSocket
- Wallet, earnings & salary tracking
- Cash collection & settlement history
- Firebase push notifications, analytics & crashlytics
- Microsoft Clarity session tracking
- RTL & multi-language support
- Dark/light theme
