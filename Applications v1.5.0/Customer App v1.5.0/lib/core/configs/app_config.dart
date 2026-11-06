import 'package:customer/commons/models/countries_model.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central configuration file for buyers to customise.
///
/// ─── HOW TO CONFIGURE ───────────────────────────────────────────────────────
///   1. Pick the active environment — either edit [environment] below,
///      or just pass it as an argument in step 3 (no manual edit needed).
///      Available environments live as JSON files in `env/`:
///        env/demo.json, env/dev.json, env/stage.json
///   2. Edit the URLs/host in the matching `env/<name>.json` file.
///   3. Run:  dart run tool/apply_config.dart `<environment>`
///      e.g.: dart run tool/apply_config.dart stage
///            dart run tool/apply_config.dart dev
///            dart run tool/apply_config.dart demo
///      (or just `dart run tool/apply_config.dart` to re-sync the
///      environment already set in [environment] below)
///      The script reads the selected env JSON and:
///        • sets [environment] below (when passed as an argument)
///        • rewrites the URL constants below
///        • patches AndroidManifest.xml, Info.plist
///   4. Build / run:  flutter clean && flutter run
/// ────────────────────────────────────────────────────────────────────────────
abstract final class AppConfig {
  /// Active environment — maps to `env/<environment>.json`.
  static const String environment = 'demo';

  // ─── AUTO-SYNCED FROM env/<environment>.json — DO NOT EDIT BY HAND ────────
  // Run `dart run tool/apply_config.dart` to refresh these values.
  // ──────────────────────────────────────────────────────────────────────────
  static const String baseUrl = 'https://admin.cakezake.com/customer/';
  static const String webUrl = 'https://cakezake.com';
  static const String socketBaseUrl =
      'wss://admin.cakezake.com/app/2226d654dde1eac564d7';

  /// Custom scheme deep link (e.g. `cakezake://product/{id}`).
  static const String deeplinkScheme = 'cakezake';

  /// App Links host (must match [webUrl]'s host).
  static const String deeplinkHost = 'cakezake.com';
  // ──────────────────────────────────────────────────────────────────────────

  // app name
  static const String appName = 'CakeZake';

  // package name
  static const String appPackageName = 'com.cakezake';

  // Pagination
  static const int pageLimit = 10;
  static const int gridPageLimit = 12;

  /// Category tab (4-column grid) — 10 is under 3 rows and leaves the screen
  /// looking empty with no hint that it scrolls. 20 fills a phone viewport.
  static const int categoryPageLimit = 20;

  // Defaults
  /// Default dial code shown in the phone field, this work only in fallback if setting API failed.
  static CountriesData defaultCountry = CountriesData(
    code: 'IN',
    dialCode: '+91',
  );
  static const String defaultLanguageCode = 'en';

  /// Countdown, in seconds, before "Resend OTP" becomes enabled.
  static const int otpResendTimerSeconds = 60;

  // Microsoft Clarity project ID (clarity.microsoft.com dashboard).
  static const String clarityProjectId = 'YOUR_CLARITY_PROJECT_ID_HERE';

  //osm map render url
  static const String osmMapRenderUrl =
      "https://tile.openstreetmap.org/{z}/{x}/{y}.png"; //"https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png";

  // App-wide font family
  static final String? fontFamily = GoogleFonts.dmSans().fontFamily;
}
