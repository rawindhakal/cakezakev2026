import 'package:deliveryboy/commons/widgets/app_confirm_dialog.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_theme.dart';
import 'package:deliveryboy/features/profile/widgets/logout_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/fake_api_adapter.dart';
import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/test_logging.dart';

/// `showLogoutDialog` creates its own `LogoutCubit`, so the real cubit and
/// repository run against the ApiClient adapter seam. The dialog is always
/// opened from a host screen through its real entry point — popping a dialog
/// that is the only route on the navigator hangs the runner.
void main() {
  late FakeApiAdapter adapter;
  late List<RouteSettings> pushed;

  setUp(() async {
    // AuthRepository.logout reads the stored FCM token and the cubit clears
    // the auth box on success; DioInterceptor reads the active language code
    // out of the settings box on every request, so both boxes must be open.
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);

    adapter = FakeApiAdapter({
      ApiEndpoints.logout: (_) => {'status': 1, 'message': 'Logged out'},
    });
    ApiClient().httpClientAdapter = adapter;
    pushed = [];
  });

  tearDown(() async {
    await Hive.box(settingsBox).close();
    await Hive.deleteBoxFromDisk(settingsBox);
    await HiveTestHelper.tearDown(authBox);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Finder appTextWith(String text) =>
      find.byWidgetPredicate((w) => w is AppText && w.text == text);

  Future<void> openDialog(WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showLogoutDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
        onGenerateRoute: (settings) {
          pushed.add(settings);
          return MaterialPageRoute(
            builder: (_) => Scaffold(body: Text('route:${settings.name}')),
            settings: settings,
          );
        },
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('asks for confirmation with staying as the emphasised action', (
    tester,
  ) async {
    printTestDivider('LogoutDialog asks for confirmation');
    await openDialog(tester);

    final dialog = tester.widget<AppConfirmDialog>(
      find.byType(AppConfirmDialog),
    );
    printTestLog('title → expected: "${LanguageLabelKeys.logout}", actual: "${dialog.title}"');
    expect(dialog.title, LanguageLabelKeys.logout);
    printTestLog(
      'message → expected: "${LanguageLabelKeys.areSureLogout}", actual: "${dialog.message}"',
    );
    expect(dialog.message, LanguageLabelKeys.areSureLogout);
    // Staying logged in is the emphasised choice, so the buttons are swapped.
    printTestLog(
      'swapButtonEmphasis → expected: true, actual: ${dialog.swapButtonEmphasis}',
    );
    expect(dialog.swapButtonEmphasis, isTrue);
    printTestLog('isLoading → expected: false, actual: ${dialog.isLoading}');
    expect(dialog.isLoading, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('"keep login" closes the dialog without calling the API', (
    tester,
  ) async {
    printTestDivider('LogoutDialog cancel closes without an API call');
    await openDialog(tester);

    await tester.tap(appTextWith(LanguageLabelKeys.keepLogin));
    await tester.pumpAndSettle();

    printTestLog(
      'dialog → expected: closed, actual: ${find.byType(AppConfirmDialog).evaluate().length}',
    );
    expect(find.byType(AppConfirmDialog), findsNothing);
    printTestLog('requests → expected: none, actual: ${adapter.requestedPaths}');
    expect(adapter.requestedPaths, isEmpty);
    printTestLog('pushed → expected: [], actual: ${pushed.map((r) => r.name)}');
    expect(pushed, isEmpty);
  });

  // The success path is not covered here. `LogoutCubit` clears the auth box
  // on success, and a Hive write started inside a `testWidgets` body never
  // completes — the test's fake clock never runs the event loop it finishes
  // on, and the pending future then blocks `tearDown`'s `box.close()` forever,
  // with no failure message. `integration_test/profile_flow_test.dart` drives
  // that path under the live binding instead.

  testWidgets('a failed logout closes the dialog and surfaces the message', (
    tester,
  ) async {
    printTestDivider('LogoutDialog surfaces a failed logout');
    adapter = FakeApiAdapter({
      ApiEndpoints.logout: (_) => {'status': 0, 'message': 'Session expired'},
    });
    ApiClient().httpClientAdapter = adapter;
    await openDialog(tester);

    await tester.tap(appTextWith(LanguageLabelKeys.logoutAnyway));
    // No Hive write on this path, so the dismiss animation can be settled.
    await tester.pumpAndSettle();

    printTestLog(
      'requests → expected: [${ApiEndpoints.logout}], actual: ${adapter.requestedPaths}',
    );
    expect(adapter.requestedPaths, [ApiEndpoints.logout]);
    printTestLog(
      'dialog → expected: closed, actual: ${find.byType(AppConfirmDialog).evaluate().length}',
    );
    expect(find.byType(AppConfirmDialog), findsNothing);
    printTestLog(
      'error message → expected: 1 "Session expired", '
      'actual: ${find.text('Session expired').evaluate().length}',
    );
    expect(find.text('Session expired'), findsOneWidget);
    // A failed logout keeps the user where they are.
    printTestLog('pushed → expected: [], actual: ${pushed.map((r) => r.name)}');
    expect(pushed, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
