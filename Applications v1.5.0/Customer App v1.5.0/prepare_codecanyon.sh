#!/bin/bash
# CodeCanyon release prep — strips machine/project-specific files before packaging.
# Run from project root: ./prepare_codecanyon.sh

set -e

echo "Setting environment to 'demo' in lib/core/configs/app_config.dart"
sed -i '' -E "s/static const String environment = '[^']*';/static const String environment = 'demo';/" lib/core/configs/app_config.dart

echo "Setting clarityProjectId placeholder in lib/core/configs/app_config.dart"
sed -i '' -E "s/static const String clarityProjectId = '[^']*';/static const String clarityProjectId = 'YOUR_CLARITY_PROJECT_ID_HERE';/" lib/core/configs/app_config.dart

echo "Running dart run tool/apply_config.dart"
dart run tool/apply_config.dart

echo "Removing android/app/google-services.json"
rm -f android/app/google-services.json

echo "Removing android/app/cakezake.jks"
rm -f android/app/cakezake.jks

echo "Removing pubspec.lock"
rm -f pubspec.lock

echo "Removing ios/Runner/GoogleService-Info.plist"
rm -f ios/Runner/GoogleService-Info.plist

echo "Removing ios/Podfile.lock"
rm -f ios/Podfile.lock

echo "Removing ios/Pods"
rm -rf ios/Pods

echo "Removing android/.gradle"
rm -rf android/.gradle

echo "Removing android/.kotlin"
rm -rf android/.kotlin

echo "Removing .git"
rm -rf .git

echo "Removing .dart_tool"
rm -rf .dart_tool

echo "Removing .idea"
rm -rf .idea

echo "Removing .claude"
rm -rf .claude

echo "Removing build"
rm -rf build

echo "Removing reskin.sh backups/output (.reskin_backup, reskin_output)"
rm -rf .reskin_backup reskin_output

echo "Setting placeholders in android/key.properties"
cat > android/key.properties <<'EOF'
storePassword=KEY_STORE_PASSWORD
keyPassword=KEY_STORE_PASSWORD
keyAlias=KEY_STORE_ALIAS
storeFile=KEY_STORE_FILE
EOF

echo "Clearing values in lib/firebase_options.dart"
perl -0777 -pi -e "
  s/(apiKey:\s*)'[^']*'/\1''/g;
  s/(appId:\s*)'[^']*'/\1''/g;
  s/(messagingSenderId:\s*)'[^']*'/\1''/g;
  s/(projectId:\s*)'[^']*'/\1''/g;
  s/(storageBucket:\s*)'[^']*'/\1''/g;
  s/(androidClientId:\s*)'[^']*'/\1''/g;
  s/(iosClientId:\s*)'[^']*'/\1''/g;
  s/(iosBundleId:\s*)'[^']*'/\1''/g;
" lib/firebase_options.dart

echo "Removing per-env Firebase backup files (lib/firebase_options_<env>.dart, ios/Runner/GoogleService-Info-<env>.plist)"
rm -f lib/firebase_options_demo.dart lib/firebase_options_dev.dart lib/firebase_options_stage.dart
rm -f ios/Runner/GoogleService-Info-demo.plist ios/Runner/GoogleService-Info-dev.plist ios/Runner/GoogleService-Info-stage.plist

echo "Clearing values in firebase.json"
perl -0777 -pi -e 's/(:\s*)"[^"]*"/$1""/g' firebase.json

echo "Setting placeholders in env/dev.json"
cat > env/dev.json <<'EOF'
{
  "APPLICATION_ID": "YOUR_DEV_APPLICATION_ID_HERE",
  "APP_NAME": "YOUR_DEV_APP_NAME_HERE",
  "BASE_URL": "YOUR_DEV_BASE_URL_HERE",
  "WEB_URL": "YOUR_DEV_WEB_URL_HERE",
  "SOCKET_BASE_URL": "YOUR_DEV_SOCKET_BASE_URL_HERE",
  "DEEPLINK_SCHEME": "YOUR_DEV_DEEPLINK_SCHEME_HERE",
  "DEEPLINK_HOST": "YOUR_DEV_DEEPLINK_HOST_HERE"
}
EOF

echo "Setting placeholders in env/stage.json"
cat > env/stage.json <<'EOF'
{
  "APPLICATION_ID": "YOUR_STAGE_APPLICATION_ID_HERE",
  "APP_NAME": "YOUR_STAGE_APP_NAME_HERE",
  "BASE_URL": "YOUR_STAGE_BASE_URL_HERE",
  "WEB_URL": "YOUR_STAGE_WEB_URL_HERE",
  "SOCKET_BASE_URL": "YOUR_STAGE_SOCKET_BASE_URL_HERE",
  "DEEPLINK_SCHEME": "YOUR_STAGE_DEEPLINK_SCHEME_HERE",
  "DEEPLINK_HOST": "YOUR_STAGE_DEEPLINK_HOST_HERE"
}
EOF

echo "Setting placeholder in android/app/src/main/AndroidManifest.xml"
sed -i '' -E \
  -e '/android:name="com.google.android.geo.API_KEY"/{n;s/android:value="[^"]*"/android:value="YOUR_MAP_API_KEY_HERE"/;}' \
  android/app/src/main/AndroidManifest.xml

echo "Setting placeholder in ios/Runner/AppDelegate.swift"
sed -i '' -E \
  -e 's/GMSServices\.provideAPIKey\("[^"]*"\)/GMSServices.provideAPIKey("YOUR_MAP_API_KEY_HERE")/' \
  ios/Runner/AppDelegate.swift

echo "Setting placeholder in ios/Runner/Info.plist"
sed -i '' -E \
  -e 's/com\.googleusercontent\.apps\.[A-Za-z0-9-]*/com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID_HERE/' \
  ios/Runner/Info.plist

echo "Setting Facebook App Events placeholders in android/app/src/main/res/values/strings.xml"
sed -i '' -E \
  -e 's#(<string name="facebook_app_id">)[^<]*(</string>)#\1YOUR_FACEBOOK_APP_ID\2#' \
  -e 's#(<string name="facebook_client_token">)[^<]*(</string>)#\1YOUR_FACEBOOK_CLIENT_TOKEN\2#' \
  android/app/src/main/res/values/strings.xml

echo "Setting Facebook App Events placeholders in ios/Runner/Info.plist"
sed -i '' -E \
  -e '/<key>FacebookAppID<\/key>/{n;s#<string>[^<]*</string>#<string>YOUR_FACEBOOK_APP_ID</string>#;}' \
  -e '/<key>FacebookClientToken<\/key>/{n;s#<string>[^<]*</string>#<string>YOUR_FACEBOOK_CLIENT_TOKEN</string>#;}' \
  ios/Runner/Info.plist

echo "Setting product version in pubspec.yaml"
read -p "Enter product version (e.g. 1.0.0): " PRODUCT_VERSION
sed -i '' -E "s/^#Product Version: .*/#Product Version: ${PRODUCT_VERSION}/" pubspec.yaml

echo "Done."
