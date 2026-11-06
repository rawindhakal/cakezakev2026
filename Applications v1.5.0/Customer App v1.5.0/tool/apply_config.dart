// ignore_for_file: avoid_print
//
// ─── apply_config.dart ──────────────────────────────────────────────────────
// Reads the active environment from
//   lib/core/configs/app_config.dart  →  static const String environment
// loads the matching `env/<environment>.json` file, then propagates its values
// into:
//   • lib/core/configs/app_config.dart       (BASE_URL, WEB_URL, SOCKET_BASE_URL,
//                                              DEEPLINK_SCHEME, DEEPLINK_HOST,
//                                              appName, appPackageName)
//   • android/app/build.gradle.kts                (applicationId)
//   • android/app/src/main/AndroidManifest.xml     (deep link + app link <data>, android:label)
//   • ios/Runner/Info.plist                        (CFBundleURLSchemes custom scheme entry,
//                                                    CFBundleDisplayName, CFBundleName)
//   • ios/Runner.xcodeproj/project.pbxproj          (PRODUCT_BUNDLE_IDENTIFIER, Runner target only)
//   • ios/Runner/GoogleService-Info.plist    <- copied from GoogleService-Info-<env>.plist (if present)
//   • lib/firebase_options.dart              <- copied from firebase_options_<env>.dart (if present)
//
// The per-env Firebase files are produced once via `flutterfire configure`
// (same Firebase project, one Android/iOS app per env) and saved under their
// env-suffixed name; this script just swaps the active copy into place.
//
// Run from the project root after editing AppConfig.environment OR an env JSON:
//
//   dart run tool/apply_config.dart
//
// Or pass the environment name directly as an argument — this also patches
// AppConfig.environment for you, so no manual file edit is needed:
//
//   dart run tool/apply_config.dart stage
//
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final appConfig = File('lib/core/configs/app_config.dart');
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  final infoPlist = File('ios/Runner/Info.plist');
  final buildGradle = File('android/app/build.gradle.kts');
  final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj');

  if (!appConfig.existsSync()) _fail('AppConfig not found at ${appConfig.path}');
  if (!manifest.existsSync()) _fail('AndroidManifest not found at ${manifest.path}');
  if (!infoPlist.existsSync()) _fail('Info.plist not found at ${infoPlist.path}');
  if (!buildGradle.existsSync()) _fail('build.gradle.kts not found at ${buildGradle.path}');
  if (!pbxproj.existsSync()) _fail('project.pbxproj not found at ${pbxproj.path}');

  // 1. Resolve active environment — from CLI arg if given, else from AppConfig.
  final requestedEnv = args.isNotEmpty ? args[0].trim() : null;
  if (requestedEnv != null && requestedEnv.isEmpty) {
    _fail('Environment argument cannot be empty.');
  }

  if (requestedEnv != null) {
    _patchEnvironmentConst(appConfig, requestedEnv);
  }

  final src = appConfig.readAsStringSync();
  final environment = _readConst(src, 'environment');
  print('• environment    = $environment');

  // 2. Load env/<environment>.json
  final envFile = File('env/$environment.json');
  if (!envFile.existsSync()) {
    final available = Directory('env').existsSync()
        ? Directory('env').listSync().whereType<File>().map((f) => f.path).join(', ')
        : '(env/ folder missing)';
    _fail(
      'Env file not found: ${envFile.path}\n'
      '   AppConfig.environment is "$environment".\n'
      '   Available: $available',
    );
  }

  final json = jsonDecode(envFile.readAsStringSync()) as Map<String, dynamic>;
  final baseUrl = _readJson(json, 'BASE_URL', envFile.path);
  final webUrl = _readJson(json, 'WEB_URL', envFile.path);
  final socketBaseUrl = _readJson(json, 'SOCKET_BASE_URL', envFile.path);
  final scheme = _readJson(json, 'DEEPLINK_SCHEME', envFile.path);
  final host = _readJson(json, 'DEEPLINK_HOST', envFile.path);
  final applicationId = _readJson(json, 'APPLICATION_ID', envFile.path);
  final appName = _readJson(json, 'APP_NAME', envFile.path);

  print('• BASE_URL        = $baseUrl');
  print('• WEB_URL         = $webUrl');
  print('• SOCKET_BASE_URL = $socketBaseUrl');
  print('• DEEPLINK_SCHEME = $scheme');
  print('• DEEPLINK_HOST   = $host');
  print('• APPLICATION_ID  = $applicationId');
  print('• APP_NAME        = $appName');

  // 3. Patch every consumer
  _patchAppConfig(
    appConfig,
    baseUrl: baseUrl,
    webUrl: webUrl,
    socketBaseUrl: socketBaseUrl,
    scheme: scheme,
    host: host,
    applicationId: applicationId,
    appName: appName,
  );
  _patchManifest(manifest, scheme: scheme, host: host, appName: appName);
  _patchInfoPlist(infoPlist, scheme: scheme, appName: appName);
  _patchBuildGradle(buildGradle, applicationId: applicationId);
  _patchPbxproj(pbxproj, applicationId: applicationId);
  _swapFirebaseFiles(environment: environment);

  print('\n✅ Synced "$environment" env into AppConfig + native files.');
  print('   Now run:  flutter clean && flutter run');
}

// ─── Readers ────────────────────────────────────────────────────────────────

/// Extracts `static const String <name> = '<value>';` from the AppConfig source.
String _readConst(String src, String name) {
  final pattern = RegExp(
    '''static\\s+const\\s+String\\s+$name\\s*=\\s*['"]([^'"]+)['"]\\s*;''',
  );
  final match = pattern.firstMatch(src);
  if (match == null) _fail('Constant `$name` not found in AppConfig');
  return match.group(1)!;
}

String _readJson(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    _fail('Key `$key` missing or empty in $path');
  }
  return value;
}

// ─── Writers ────────────────────────────────────────────────────────────────

/// Patches `AppConfig.environment` itself so the CLI-arg flow needs no
/// manual file edit. Fails fast if `env/<name>.json` doesn't exist.
void _patchEnvironmentConst(File file, String environment) {
  final envFile = File('env/$environment.json');
  if (!envFile.existsSync()) {
    final available = Directory('env').existsSync()
        ? Directory('env').listSync().whereType<File>().map((f) => f.path).join(', ')
        : '(env/ folder missing)';
    _fail(
      'Env file not found: ${envFile.path}\n'
      '   Requested environment is "$environment".\n'
      '   Available: $available',
    );
  }

  final original = file.readAsStringSync();
  final patched = _replaceConst(original, 'environment', environment);
  if (patched != original) {
    file.writeAsStringSync(patched);
    print('✓ Patched environment -> $environment in ${file.path}');
  }
}

void _patchAppConfig(
  File file, {
  required String baseUrl,
  required String webUrl,
  required String socketBaseUrl,
  required String scheme,
  required String host,
  required String applicationId,
  required String appName,
}) {
  final original = file.readAsStringSync();

  var patched = original;
  patched = _replaceConst(patched, 'baseUrl', baseUrl);
  patched = _replaceConst(patched, 'webUrl', webUrl);
  patched = _replaceConst(patched, 'socketBaseUrl', socketBaseUrl);
  patched = _replaceConst(patched, 'deeplinkScheme', scheme);
  patched = _replaceConst(patched, 'deeplinkHost', host);
  patched = _replaceConst(patched, 'appPackageName', applicationId);
  patched = _replaceConst(patched, 'appName', appName);

  if (patched != original) {
    file.writeAsStringSync(patched);
    print('✓ Patched ${file.path}');
  } else {
    print('• ${file.path} already up to date');
  }
}

String _replaceConst(String src, String name, String value) {
  final pattern = RegExp(
    '''(static\\s+const\\s+String\\s+$name\\s*=\\s*['"])([^'"]*)(['"]\\s*;)''',
  );
  if (!pattern.hasMatch(src)) {
    _fail('Constant `$name` not found in AppConfig — cannot sync');
  }
  return src.replaceFirstMapped(
    pattern,
    (m) => '${m.group(1)}$value${m.group(3)}',
  );
}

/// Patches the custom-scheme `<data android:scheme="..."/>` deep link and the
/// `https` App Link `<data android:scheme="https" android:host="..." .../>`.
void _patchManifest(
  File file, {
  required String scheme,
  required String host,
  required String appName,
}) {
  final original = file.readAsStringSync();
  var patched = original;
  var replacements = 0;

  final customScheme = RegExp(r'<data android:scheme="[^"]*"/>');
  patched = patched.replaceFirstMapped(customScheme, (m) {
    replacements++;
    return '<data android:scheme="$scheme"/>';
  });

  final appLink = RegExp(
    r'<data android:scheme="https" android:host="[^"]*"(\s+android:pathPrefix="[^"]*")?/>',
  );
  patched = patched.replaceAllMapped(appLink, (m) {
    replacements++;
    final pathPrefix = m.group(1) ?? '';
    return '<data android:scheme="https" android:host="$host"$pathPrefix/>';
  });

  final label = RegExp(r'android:label="[^"]*"');
  if (label.hasMatch(patched)) {
    patched = patched.replaceFirstMapped(label, (m) {
      replacements++;
      return 'android:label="$appName"';
    });
  }

  if (replacements == 0) {
    _fail('No deep link <data> tags found in AndroidManifest.xml.');
  }

  if (patched != original) {
    file.writeAsStringSync(patched);
    print('✓ Patched $replacements entries in ${file.path}');
  } else {
    print('• ${file.path} already up to date');
  }
}

/// Replaces the custom-scheme `<string>` inside the SECOND `CFBundleURLSchemes`
/// array in Info.plist — the first array holds the Google Sign-In reversed
/// client ID and must be left untouched.
void _patchInfoPlist(File file, {required String scheme, required String appName}) {
  final original = file.readAsStringSync();

  var withNames = original;
  for (final key in ['CFBundleDisplayName', 'CFBundleName']) {
    final pattern = RegExp('(<key>$key</key>\\s*<string>)[^<]*(</string>)');
    if (pattern.hasMatch(withNames)) {
      withNames = withNames.replaceFirstMapped(
        pattern,
        (m) => '${m.group(1)}$appName${m.group(2)}',
      );
    }
  }

  final blocks = RegExp(
    r'<key>CFBundleURLSchemes</key>\s*<array>\s*<string>[^<]*</string>\s*</array>',
    multiLine: true,
    dotAll: true,
  ).allMatches(withNames).toList();

  if (blocks.length < 2) {
    _fail(
      'Expected at least 2 `CFBundleURLSchemes` arrays in Info.plist '
      '(Google Sign-In + custom scheme), found ${blocks.length}.',
    );
  }

  final target = blocks[1];
  final replacement = target.group(0)!.replaceFirstMapped(
    RegExp(r'(<array>\s*<string>)[^<]*(</string>)'),
    (m) => '${m.group(1)}$scheme${m.group(2)}',
  );

  final patched = withNames.replaceRange(target.start, target.end, replacement);

  if (patched != original) {
    file.writeAsStringSync(patched);
    print('✓ Patched ${file.path}');
  } else {
    print('• ${file.path} already up to date');
  }
}

/// Patches the Android `applicationId` in `android/app/build.gradle.kts`.
/// `namespace` is intentionally left untouched — it only affects generated
/// R/BuildConfig class package, not app identity, and changing it needlessly
/// risks breaking Kotlin/Java imports that reference it.
void _patchBuildGradle(File file, {required String applicationId}) {
  final original = file.readAsStringSync();
  final pattern = RegExp(r'(applicationId\s*=\s*")[^"]*(")');
  if (!pattern.hasMatch(original)) {
    _fail('`applicationId` not found in ${file.path}');
  }
  final patched = original.replaceFirstMapped(
    pattern,
    (m) => '${m.group(1)}$applicationId${m.group(2)}',
  );

  if (patched != original) {
    file.writeAsStringSync(patched);
    print('✓ Patched applicationId -> $applicationId in ${file.path}');
  } else {
    print('• ${file.path} already up to date');
  }
}

/// Patches `PRODUCT_BUNDLE_IDENTIFIER` for the Runner app target only
/// (Debug/Release/Profile) — the `.RunnerTests` target entries are left
/// alone since the test target's bundle id doesn't affect app identity.
void _patchPbxproj(File file, {required String applicationId}) {
  final original = file.readAsStringSync();
  final pattern = RegExp(r'(PRODUCT_BUNDLE_IDENTIFIER = )(?!.*\.RunnerTests;)[^;]+;');
  var replacements = 0;
  final patched = original.replaceAllMapped(pattern, (m) {
    replacements++;
    return '${m.group(1)}$applicationId;';
  });

  if (replacements == 0) {
    _fail('No Runner-target `PRODUCT_BUNDLE_IDENTIFIER` found in ${file.path}');
  }

  if (patched != original) {
    file.writeAsStringSync(patched);
    print('✓ Patched $replacements PRODUCT_BUNDLE_IDENTIFIER entries in ${file.path}');
  } else {
    print('• ${file.path} already up to date');
  }
}

/// Swaps the env-specific Firebase files into the paths Firebase/Xcode
/// actually read from. These per-env files are produced once via
/// `flutterfire configure` (one Firebase Android/iOS app per env, same
/// project) and saved under an env-suffixed name; this just copies the
/// active one into place. Missing files are skipped with a warning rather
/// than failing, so envs not yet wired into Firebase still sync everything
/// else.
void _swapFirebaseFiles({required String environment}) {
  final plistSrc = File('ios/Runner/GoogleService-Info-$environment.plist');
  final plistDest = File('ios/Runner/GoogleService-Info.plist');
  if (plistSrc.existsSync()) {
    plistDest.writeAsBytesSync(plistSrc.readAsBytesSync());
    print('✓ Copied ${plistSrc.path} -> ${plistDest.path}');
  } else {
    print('⚠ ${plistSrc.path} not found — GoogleService-Info.plist left as-is. '
        'Run `flutterfire configure` for "$environment" and save its output there.');
  }

  final optionsSrc = File('lib/firebase_options_$environment.dart');
  final optionsDest = File('lib/firebase_options.dart');
  if (optionsSrc.existsSync()) {
    optionsDest.writeAsStringSync(optionsSrc.readAsStringSync());
    print('✓ Copied ${optionsSrc.path} -> ${optionsDest.path}');
  } else {
    print('⚠ ${optionsSrc.path} not found — firebase_options.dart left as-is. '
        'Run `flutterfire configure` for "$environment" and save its output there.');
  }

  // android/app/google-services.json intentionally untouched — it already
  // contains every registered Android app (all envs) in the Firebase
  // project, and the Google Services Gradle plugin auto-picks the client
  // entry matching the active `applicationId` at build time.
}

Never _fail(String msg) {
  stderr.writeln('❌ $msg');
  exit(1);
}
