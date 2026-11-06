import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/features/auth/models/auth_model.dart';
import 'package:deliveryboy/features/auth/screens/sign_in_screen.dart';
import 'package:deliveryboy/features/splash/screens/maintenance_screen.dart';
import 'package:deliveryboy/features/splash/screens/splash_screen.dart';
import 'package:deliveryboy/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'helpers/auth_fixtures.dart';
import 'helpers/auth_test_app.dart';
import 'helpers/fake_api_adapter.dart';
import 'helpers/splash_fixtures.dart';

/// Splash end to end: real router, real SplashScreen, real settings/language/
/// localization cubits and repositories, only the network faked. This is the
/// one flow that legitimately crosses feature boundaries — deciding where the
/// app opens *is* what splash does — but it stops at the destination route
/// mounting. `RouteNames.main` still resolves to `AuthTestApp`'s
/// `PostLoginPlaceholder`, so nothing here depends on the dashboard.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeApiAdapter adapter;

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final dir = await Directory.systemTemp.createTemp('integration_hive_');
    Hive.init(dir.path);
    await Hive.openBox(authBox);
    await Hive.openBox(settingsBox);
    await LocalizationService.instance.loadFromAssets();
  });

  setUp(() async {
    await Hive.box(authBox).clear();
    await Hive.box(settingsBox).clear();
    adapter = _splashAdapter();
    ApiClient().httpClientAdapter = adapter;
  });

  Future<void> waitForResponse(WidgetTester tester) async {
    // The live binding runs on real time, so pump(Duration) alone doesn't let
    // a pending network future complete.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> pumpSplash(WidgetTester tester) async {
    await tester.pumpWidget(
      const AuthTestApp(initialRoute: RouteNames.splash),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('a cold start with no session opens the login screen', (
    tester,
  ) async {
    await pumpSplash(tester);
    expect(find.byType(SplashScreen), findsOneWidget);

    await waitForResponse(tester);
    await waitForResponse(tester);

    // The full chain ran: settings, then the language list, then that
    // language's translations.
    expect(adapter.requestedPaths, contains(ApiEndpoints.settings));
    expect(adapter.requestedPaths, contains(ApiEndpoints.systemLanguages));
    expect(
      adapter.requests
          .where((r) => r.path == ApiEndpoints.systemLanguages)
          .any((r) => r.queryParameters[ApiParameters.id] != null),
      isTrue,
    );
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('a stored session opens the app instead of the login screen', (
    tester,
  ) async {
    await AuthHiveBox.instance.saveLoginData(
      auth: AuthModel.fromJson(loginResponseFixture),
    );

    await pumpSplash(tester);
    await waitForResponse(tester);
    await waitForResponse(tester);

    expect(find.byType(PostLoginPlaceholder), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
  });

  testWidgets('maintenance mode blocks the app at the maintenance screen', (
    tester,
  ) async {
    adapter = _splashAdapter(settings: maintenanceSettingsResponseFixture);
    ApiClient().httpClientAdapter = adapter;

    await pumpSplash(tester);
    await waitForResponse(tester);

    expect(find.byType(MaintenanceScreen), findsOneWidget);
    // The server's remark replaces the generic subtitle, and the chain stops
    // before the language list — there is nothing past this screen to load.
    expect(find.text('Scheduled upgrade — back at 6pm IST'), findsOneWidget);
    expect(
      adapter.requestedPaths.contains(ApiEndpoints.systemLanguages),
      isFalse,
    );
  });

  testWidgets('a settings failure still lets the app in, on cached copy', (
    tester,
  ) async {
    // Nothing stubbed → the adapter answers 404, which is what a backend
    // outage looks like to SettingsCubit.
    adapter = FakeApiAdapter({});
    ApiClient().httpClientAdapter = adapter;

    await pumpSplash(tester);
    await waitForResponse(tester);
    await waitForResponse(tester);

    // LocalizationCubit.loadFromCache falls through to the bundled English
    // asset, emits Loaded, and splash navigates on rather than hanging.
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('splash navigates once, even as the chain keeps firing', (
    tester,
  ) async {
    await pumpSplash(tester);
    await waitForResponse(tester);
    await waitForResponse(tester);
    // Long enough for any late settings/language emission to land.
    await waitForResponse(tester);

    // A second pushReplacement would have torn the sign-in screen back down.
    expect(find.byType(SignInScreen), findsOneWidget);
  });
}

/// Answers the whole splash chain: settings, the language list, and the
/// selected language's translations (same endpoint, told apart by `id`).
FakeApiAdapter _splashAdapter({
  Map<String, dynamic> settings = settingsResponseFixture,
}) {
  return FakeApiAdapter({
    ApiEndpoints.settings: (_) => settings,
    ApiEndpoints.systemLanguages: (options) =>
        options.queryParameters[ApiParameters.id] == null
        ? systemLanguagesListFixture
        : systemLanguageDetailFixture,
    ApiEndpoints.countrySettings: (_) => {
      'status': 1,
      'data': {'currency': '₹'},
    },
    ApiEndpoints.editProfile: (_) => loginResponseFixture,
    ApiEndpoints.countries: (_) => emptyListFixture,
  });
}
