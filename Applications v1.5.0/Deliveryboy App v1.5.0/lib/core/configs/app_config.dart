import 'package:deliveryboy/commons/models/countries_model.dart';
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
///        • patches applicationId, android:label, Info.plist display name
///   4. Build / run:  flutter clean && flutter run
/// ────────────────────────────────────────────────────────────────────────────
abstract final class AppConfig {
  /// Active environment — maps to `env/<environment>.json`.
  static const String environment = 'demo';

  // ─── AUTO-SYNCED FROM env/<environment>.json — DO NOT EDIT BY HAND ────────
  // Run `dart run tool/apply_config.dart` to refresh these values.
  // ──────────────────────────────────────────────────────────────────────────
  static const String baseUrl =
      "https://admin.cakezake.com/delivery_boy/";
  static const String socketBaseUrl =
      "wss://cakezake.com/ws/chat";
  // ──────────────────────────────────────────────────────────────────────────

  // Pagination
  static const int pageLimit = 10;

  // Defaults
  /// Default dial code shown in the phone field, this work only in fallback if setting API failed.
  static CountriesData defaultCountry = CountriesData(
    code: 'IN',
    dialCode: '+91',
  );
  static const String defaultLanguageCode = 'en';

  // Microsoft Clarity project ID (clarity.microsoft.com dashboard).
  static const String clarityProjectId = 'YOUR_CLARITY_PROJECT_ID_HERE';

  // app name
  static const String appName = 'CakeZake Deliveryboy';

  // package name
  static const String appPackageName = 'com.cakezake.delivery';

  //osm map render url
  static const String osmMapRenderUrl =
      "https://tile.openstreetmap.org/{z}/{x}/{y}.png";//https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png";

  // External map deep links — "$lat,$lng" is appended by launchDirection().
  static const String androidNavigationUrl = "google.navigation:q=";
  static const String appleMapsDirectionUrl = "http://maps.apple.com/?daddr=";
  static const String googleMapsDirectionUrl =
      "https://tile.openstreetmap.org/{z}/{x}/{y}.png"; //"https://www.google.com/maps/dir/?api=1&destination=";

  // App-wide font family
  static final String? fontFamily = GoogleFonts.dmSans().fontFamily;

  //Default login detail
  static String defultEmail = '';
  static String defultPassword = '';
}
