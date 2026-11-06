import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/features/auth/models/auth_model.dart';
import 'package:deliveryboy/features/auth/screens/sign_in_screen.dart';
import 'package:deliveryboy/features/profile/widgets/delete_account_dialog.dart';
import 'package:deliveryboy/features/profile/widgets/logout_dialog.dart';
import 'package:deliveryboy/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'helpers/auth_fixtures.dart';
import 'helpers/auth_test_app.dart';
import 'helpers/fake_api_adapter.dart';

/// Ending a session — logout and account deletion. Both dialogs live in the
/// profile feature but drive auth cubits, clear `AuthHiveBox` and send the
/// rider back to the login route, so they are exercised here alongside the
/// rest of the auth surface.
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
    // Every test here starts from a logged-in rider, the way the real app
    // reaches the profile tab.
    await AuthHiveBox.instance.saveLoginData(
      auth: AuthModel.fromJson(loginResponseFixture),
    );
    adapter = FakeApiAdapter({
      ApiEndpoints.logout: (_) => {'status': 1, 'message': 'Logged out'},
      ApiEndpoints.deleteDeliveryBoyAccount: (_) => {
        'status': 1,
        'message': 'Account deleted',
      },
    });
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

  /// Mounts the real auth stack on the post-login placeholder, then opens
  /// [openDialog] from a button on it — standing in for the profile tab's own
  /// entry point without pulling the whole profile feature into this test.
  Future<void> pumpWithDialog(
    WidgetTester tester,
    void Function(BuildContext) openDialog,
  ) async {
    await tester.pumpWidget(
      AuthTestApp(
        initialRoute: RouteNames.main,
        mainScreenBuilder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => openDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tapConfirm(WidgetTester tester, String labelKey) async {
    await tester.tap(
      find.text(LocalizationService.instance.translate(labelKey)),
    );
    await waitForResponse(tester);
  }

  testWidgets('logging out clears the session and returns to the sign-in screen', (
    tester,
  ) async {
    await pumpWithDialog(tester, showLogoutDialog);

    expect(AuthHiveBox.instance.isLoggedIn, isTrue);

    await tapConfirm(tester, LanguageLabelKeys.logoutAnyway);

    expect(adapter.requestedPaths, contains(ApiEndpoints.logout));
    expect(AuthHiveBox.instance.isLoggedIn, isFalse);
    expect(AuthHiveBox.instance.getToken(), isNull);
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('cancelling the logout dialog keeps the session', (tester) async {
    await pumpWithDialog(tester, showLogoutDialog);

    await tester.tap(
      find.text(
        LocalizationService.instance.translate(LanguageLabelKeys.keepLogin),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(adapter.requestedPaths, isNot(contains(ApiEndpoints.logout)));
    expect(AuthHiveBox.instance.isLoggedIn, isTrue);
    expect(find.byType(SignInScreen), findsNothing);
  });

  testWidgets('a failed logout keeps the session and stays put', (tester) async {
    adapter = FakeApiAdapter({
      ApiEndpoints.logout: (_) => {
        'status': 0,
        'message': 'Could not log out',
      },
    });
    ApiClient().httpClientAdapter = adapter;

    await pumpWithDialog(tester, showLogoutDialog);
    await tapConfirm(tester, LanguageLabelKeys.logoutAnyway);

    // LogoutCubit surfaces the failure instead of clearing local data — unlike
    // AuthCubit.logout, which swallows API errors and clears regardless.
    expect(AuthHiveBox.instance.isLoggedIn, isTrue);
    expect(find.byType(SignInScreen), findsNothing);
  });

  testWidgets('deleting the account clears the session and returns to the sign-in screen', (
    tester,
  ) async {
    await pumpWithDialog(tester, showDeleteAccountDialog);

    await tapConfirm(tester, LanguageLabelKeys.delete);

    expect(
      adapter.requestedPaths,
      contains(ApiEndpoints.deleteDeliveryBoyAccount),
    );
    expect(AuthHiveBox.instance.isLoggedIn, isFalse);
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('cancelling the delete dialog keeps the account', (tester) async {
    await pumpWithDialog(tester, showDeleteAccountDialog);

    await tester.tap(
      find.text(
        LocalizationService.instance.translate(LanguageLabelKeys.cancel),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      adapter.requestedPaths,
      isNot(contains(ApiEndpoints.deleteDeliveryBoyAccount)),
    );
    expect(AuthHiveBox.instance.isLoggedIn, isTrue);
  });
}
