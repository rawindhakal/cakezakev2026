import 'package:deliveryboy/commons/widgets/app_confirm_dialog.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/core/theme/app_theme.dart';
import 'package:deliveryboy/features/profile/screens/account_settings_screen.dart';
import 'package:deliveryboy/features/profile/widgets/profile_menu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/fake_api_adapter.dart';
import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/test_logging.dart';

/// The settings screen is a single menu card whose three rows lead to a route,
/// a sheet, and a dialog. The logout/delete dialogs build their own cubits
/// internally, so the real cubits and repositories run against the ApiClient
/// adapter seam rather than an injected mock.
void main() {
  late FakeApiAdapter adapter;
  late List<RouteSettings> pushed;

  setUp(() async {
    // LogoutCubit's repository reads the stored FCM token, and its success
    // path clears the auth box.
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);

    adapter = FakeApiAdapter({
      ApiEndpoints.logout: (_) => {'status': 1, 'message': 'Logged out'},
      ApiEndpoints.deleteDeliveryBoyAccount: (_) => {
        'status': 1,
        'message': 'Account deleted',
      },
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

  Future<void> pumpScreen(WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        // AccountSettingsScreen builds its own AppScaffold.
        home: const AccountSettingsScreen(),
        onGenerateRoute: (settings) {
          pushed.add(settings);
          return MaterialPageRoute(
            builder: (_) => Scaffold(body: Text('route:${settings.name}')),
            settings: settings,
          );
        },
      ),
    );
    await tester.pump();
  }

  testWidgets('lists notifications, change password and delete account', (
    tester,
  ) async {
    printTestDivider('AccountSettingsScreen lists its three rows');
    await pumpScreen(tester);

    printTestLog(
      'title → expected: 1 "${LanguageLabelKeys.settings}", '
      'actual: ${appTextWith(LanguageLabelKeys.settings).evaluate().length}',
    );
    expect(appTextWith(LanguageLabelKeys.settings), findsOneWidget);
    printTestLog(
      'card → expected: 1, actual: ${find.byType(ProfileMenuCard).evaluate().length}',
    );
    expect(find.byType(ProfileMenuCard), findsOneWidget);
    for (final key in [
      LanguageLabelKeys.general,
      LanguageLabelKeys.notifications,
      LanguageLabelKeys.changePassword,
      LanguageLabelKeys.deleteAccount,
    ]) {
      printTestLog(
        'row → expected: 1 "$key", actual: ${appTextWith(key).evaluate().length}',
      );
      expect(appTextWith(key), findsOneWidget);
    }
  });

  testWidgets('the notifications row pushes the notifications route', (
    tester,
  ) async {
    printTestDivider('AccountSettingsScreen pushes the notifications route');
    await pumpScreen(tester);

    await tester.tap(appTextWith(LanguageLabelKeys.notifications));
    await tester.pump();

    printTestLog(
      'pushed → expected: [${RouteNames.notifications}], actual: ${pushed.map((r) => r.name)}',
    );
    expect(pushed.map((r) => r.name), [RouteNames.notifications]);
  });

  testWidgets('the change-password row opens the change-password sheet', (
    tester,
  ) async {
    printTestDivider('AccountSettingsScreen opens the change-password sheet');
    await pumpScreen(tester);

    await tester.tap(appTextWith(LanguageLabelKeys.changePassword));
    await tester.pumpAndSettle();

    // The row label and the sheet heading share the same key, so the sheet
    // shows up as a second occurrence.
    printTestLog(
      'sheet heading → expected: 2 "${LanguageLabelKeys.changePassword}", '
      'actual: ${appTextWith(LanguageLabelKeys.changePassword).evaluate().length}',
    );
    expect(appTextWith(LanguageLabelKeys.changePassword), findsNWidgets(2));
    printTestLog(
      'update button → expected: 1 "${LanguageLabelKeys.updatePassword}", '
      'actual: ${appTextWith(LanguageLabelKeys.updatePassword).evaluate().length}',
    );
    expect(appTextWith(LanguageLabelKeys.updatePassword), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the delete-account row opens a destructive confirm dialog', (
    tester,
  ) async {
    printTestDivider('AccountSettingsScreen opens the delete-account dialog');
    await pumpScreen(tester);

    await tester.tap(appTextWith(LanguageLabelKeys.deleteAccount));
    await tester.pumpAndSettle();

    final dialog = tester.widget<AppConfirmDialog>(
      find.byType(AppConfirmDialog),
    );
    printTestLog(
      'isDestructive → expected: true, actual: ${dialog.isDestructive}',
    );
    expect(dialog.isDestructive, isTrue);
    printTestLog(
      'message → expected: "${LanguageLabelKeys.deleteAccountWarning}", '
      'actual: "${dialog.message}"',
    );
    expect(dialog.message, LanguageLabelKeys.deleteAccountWarning);
    printTestLog(
      'confirm label → expected: "${LanguageLabelKeys.delete}", '
      'actual: "${dialog.confirmLabel}"',
    );
    expect(dialog.confirmLabel, LanguageLabelKeys.delete);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cancelling the delete dialog closes it without calling the API', (
    tester,
  ) async {
    printTestDivider('AccountSettingsScreen delete dialog cancels cleanly');
    await pumpScreen(tester);

    await tester.tap(appTextWith(LanguageLabelKeys.deleteAccount));
    await tester.pumpAndSettle();
    await tester.tap(appTextWith(LanguageLabelKeys.cancel));
    await tester.pumpAndSettle();

    printTestLog(
      'dialog → expected: closed, actual: ${find.byType(AppConfirmDialog).evaluate().length}',
    );
    expect(find.byType(AppConfirmDialog), findsNothing);
    printTestLog(
      'requests → expected: none, actual: ${adapter.requestedPaths}',
    );
    expect(adapter.requestedPaths, isEmpty);
  });

  testWidgets('confirming the delete dialog calls the API and lands on login', (
    tester,
  ) async {
    printTestDivider('AccountSettingsScreen delete confirm hits the API');
    await pumpScreen(tester);

    await tester.tap(appTextWith(LanguageLabelKeys.deleteAccount));
    await tester.pumpAndSettle();
    await tester.tap(appTextWith(LanguageLabelKeys.delete));
    await tester.pumpAndSettle();

    printTestLog(
      'requests → expected: [${ApiEndpoints.deleteDeliveryBoyAccount}], '
      'actual: ${adapter.requestedPaths}',
    );
    expect(adapter.requestedPaths, [ApiEndpoints.deleteDeliveryBoyAccount]);
    printTestLog(
      'pushed → expected: [${RouteNames.login}], actual: ${pushed.map((r) => r.name)}',
    );
    expect(pushed.map((r) => r.name), [RouteNames.login]);
  });
}
