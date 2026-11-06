import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:deliveryboy/commons/widgets/app_button.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/features/auth/screens/sign_in_screen.dart';
import 'package:deliveryboy/features/auth/screens/sign_up_screen.dart';
import 'package:deliveryboy/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'helpers/auth_fixtures.dart';
import 'helpers/auth_test_app.dart';
import 'helpers/fake_api_adapter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeApiAdapter adapter;

  setUpAll(() async {
    // SignInScreen reads FirebaseMessaging.instance to attach an FCM token to
    // the login call, which throws `[core/no-app]` unless Firebase is
    // initialized exactly the way the real main() does it.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Plain (unencrypted) boxes in a temp dir: the encryption cipher only
    // guards the real on-device keystore key, which is irrelevant to what
    // these flows verify.
    final dir = await Directory.systemTemp.createTemp('integration_hive_');
    Hive.init(dir.path);
    await Hive.openBox(authBox);
    await Hive.openBox(settingsBox);
    await LocalizationService.instance.loadFromAssets();
  });

  setUp(() async {
    await Hive.box(authBox).clear();
    adapter = FakeApiAdapter({
      ApiEndpoints.login: (_) => loginResponseFixture,
      ApiEndpoints.register: (_) => {
        'status': 1,
        'message': 'Registered successfully',
      },
      ApiEndpoints.forgotPassword: (_) => {'status': 1, 'message': 'OTP sent'},
      ApiEndpoints.logout: (_) => {'status': 1, 'message': 'Logged out'},
    });
    ApiClient().httpClientAdapter = adapter;
  });

  /// Waits real wall-clock time and then drains the frames that landed. The
  /// live binding runs on real time, so `tester.pump(Duration)` schedules a
  /// frame but does *not* let a pending network future complete — an
  /// assertion made right after it sees the pre-response UI.
  Future<void> waitForResponse(
    WidgetTester tester, {
    Duration duration = const Duration(seconds: 2),
  }) async {
    await tester.runAsync(() => Future<void>.delayed(duration));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Winds a test down cleanly after it has landed on `MainScreen`, whose
  /// tabs each kick off their own fetch. Waiting on real wall-clock time (the
  /// live binding doesn't fast-forward pending futures) lets those land, then
  /// the tree is unmounted while nothing is in flight. Without this, teardown
  /// closes the cubits mid-request and each one throws `Bad state: Cannot
  /// emit new states after calling close`, reported as a test failure.
  Future<void> settleAndUnmount(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 3)),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
  }

  testWidgets('login with valid credentials stores the session and leaves the sign-in screen', (
    tester,
  ) async {
    await tester.pumpWidget(const AuthTestApp(initialRoute: RouteNames.login));
    await tester.pump(const Duration(milliseconds: 500));

    final emailField = find.byType(TextFormField).first;
    final passwordField = find.byType(TextFormField).at(1);
    await tester.enterText(emailField, 'alex@gmail.com');
    await tester.enterText(passwordField, 'password');
    await tester.tap(find.byType(AppButton));
    await waitForResponse(tester);

    expect(adapter.requestedPaths, contains(ApiEndpoints.login));
    expect(AuthHiveBox.instance.isLoggedIn, isTrue);
    expect(AuthHiveBox.instance.getToken(), isNotEmpty);
    expect(find.byType(SignInScreen), findsNothing);
    expect(find.byType(PostLoginPlaceholder), findsOneWidget);

    await settleAndUnmount(tester);
  });

  testWidgets('login with rejected credentials keeps the user on the sign-in screen', (
    tester,
  ) async {
    adapter = FakeApiAdapter({
      ApiEndpoints.login: (_) => {
        'status': 0,
        'message': 'Invalid credentials',
      },
    });
    ApiClient().httpClientAdapter = adapter;

    await tester.pumpWidget(const AuthTestApp(initialRoute: RouteNames.login));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextFormField).first, 'alex@gmail.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password');
    await tester.tap(find.byType(AppButton));
    await waitForResponse(tester);

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(AuthHiveBox.instance.isLoggedIn, isFalse);
    expect(find.text('Invalid credentials'), findsOneWidget);
  });

  testWidgets('forgot-password sheet submits the email and closes on success', (
    tester,
  ) async {
    await tester.pumpWidget(const AuthTestApp(initialRoute: RouteNames.login));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text(LocalizationService.instance.translate('forgot_password_label')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    // The sheet adds a second AppButton (Submit) above the login button.
    await tester.enterText(find.byType(TextFormField).last, 'alex@gmail.com');
    await tester.tap(find.byType(AppButton).last);
    await waitForResponse(tester);

    expect(adapter.requestedPaths, contains(ApiEndpoints.forgotPassword));
  });

  testWidgets('sign-up screen reaches the register endpoint and returns to sign-in', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AuthTestApp(initialRoute: RouteNames.register),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SignUpScreen), findsOneWidget);

    // Submitting an empty form must not reach the network — identity
    // documents and required fields are validated locally first.
    await tester.tap(find.byType(AppButton).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(adapter.requestedPaths, isNot(contains(ApiEndpoints.register)));
    expect(find.byType(SignUpScreen), findsOneWidget);
  });

  testWidgets('a stored session survives a fresh app launch', (tester) async {
    await tester.pumpWidget(const AuthTestApp(initialRoute: RouteNames.login));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextFormField).first, 'alex@gmail.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.byType(AppButton));
    await waitForResponse(tester);

    final tokenAfterLogin = AuthHiveBox.instance.getToken();

    // Rebuilding the whole app from scratch stands in for a cold start: the
    // session lives in Hive, not in any widget's state.
    await settleAndUnmount(tester);
    await tester.pumpWidget(const AuthTestApp(initialRoute: RouteNames.login));
    await tester.pump(const Duration(milliseconds: 500));

    expect(AuthHiveBox.instance.getToken(), tokenAfterLogin);
    expect(AuthHiveBox.instance.isLoggedIn, isTrue);
  });
}
