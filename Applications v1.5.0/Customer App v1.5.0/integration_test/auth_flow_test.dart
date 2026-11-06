import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:customer/core/api/api_client.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/location/screens/location_required_screen.dart';
import 'package:customer/firebase_options.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'helpers/auth_fixtures.dart';
import 'helpers/auth_test_app.dart';
import 'helpers/fake_api_adapter.dart';

/// The sign-in screen end to end: real router, real `SignInScreen`, real
/// `SignInCubit`/`AuthRepository`, only the network faked at the `ApiClient`
/// adapter seam. Mounted via `AuthTestApp` directly at `RouteNames.login`.
///
/// Unlike faq/blog, `AuthRepository`'s login methods call `getFcmToken()`
/// first, which hits real `FirebaseMessaging.instance` — that only resolves
/// without throwing once `Firebase.initializeApp()` has actually run, which
/// only works here (not in `flutter test`'s widget/unit runners) because an
/// integration test runs as the real compiled app on a device/simulator,
/// with the same bundled `GoogleService-Info.plist`/`google-services.json`
/// `main.dart` itself uses — `setUpAll` below calls it the same way
/// `main.dart` does.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeApiAdapter adapter;

  setUpAll(() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    final dir = await Directory.systemTemp.createTemp('integration_hive_');
    Hive.init(dir.path);
    await Hive.openBox(settingsBox);
    await Hive.openBox(authBox);
    await Hive.openBox(guestCartBox);
  });

  setUp(() async {
    // A fresh box per test — `AuthHiveBox.saveLoginData`/`clearAuth` should
    // not leak a token from one test's login into the next's assertions.
    await AuthHiveBox.instance.clearAuth();
    adapter = FakeApiAdapter({
      ApiEndpoints.settings: (_) => settingsFixture,
      ApiEndpoints.countries: (_) => countriesFixture,
      ApiEndpoints.login: (options) {
        final data = options.data;
        final email = data is Map ? data['id']?.toString() : null;
        return email == 'jordan@example.com'
            ? loginSuccessFixture
            : loginInvalidCredentialsFixture;
      },
    });
    ApiClient().httpClientAdapter = adapter;
  });

  Future<void> waitForResponse(WidgetTester tester) async {
    // The live binding runs on real time, so pump(Duration) alone doesn't
    // let a pending network future complete.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const AuthTestApp());
    await waitForResponse(tester);
  }

  testWidgets('loads the sign-in screen with the email form once settings/countries load', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(adapter.requestedPaths, contains(ApiEndpoints.settings));
    expect(adapter.requestedPaths, contains(ApiEndpoints.countries));
    expect(find.text(LanguageLabelKeys.welcomeBack), findsOneWidget);
    expect(
      find.text('${LanguageLabelKeys.email} *', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets(
    'a successful login persists the session and lands on the location-required gate',
    (tester) async {
      await pumpScreen(tester);

      await tester.enterText(
        find.byType(TextFormField).first,
        'jordan@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Passw0rd!');
      await tester.tap(find.text(LanguageLabelKeys.signIn, findRichText: true));
      await waitForResponse(tester);

      expect(adapter.requestedPaths, contains(ApiEndpoints.login));
      // `SignInLoaded` → `GuestCartSyncHelper.syncAndNavigate` → an empty
      // guest cart skips the merge branch and replaces the stack with
      // `RouteNames.locationRequired` (a fresh `SettingsHiveBox` has no
      // saved location) — that screen builds its own
      // `BlocProvider<UserLocationCubit>`, so landing on it needs nothing
      // more from this harness.
      expect(find.byType(LocationRequiredScreen), findsOneWidget);
      expect(AuthHiveBox.instance.getToken(), 'integration-test-access-token');
      expect(AuthHiveBox.instance.isLoggedIn, isTrue);
    },
  );

  testWidgets('invalid credentials surface the api message and keep the user on sign-in', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      'wrong@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password');
    await tester.tap(find.text(LanguageLabelKeys.signIn, findRichText: true));
    await waitForResponse(tester);

    expect(find.text('Invalid email or password'), findsOneWidget);
    expect(find.byType(LocationRequiredScreen), findsNothing);
    expect(AuthHiveBox.instance.isLoggedIn, isFalse);
  });
}
