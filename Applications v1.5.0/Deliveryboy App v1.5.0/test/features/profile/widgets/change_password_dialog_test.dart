import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/commons/widgets/password_requirements_checklist.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_theme.dart';
import 'package:deliveryboy/features/profile/widgets/change_password_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/fake_api_adapter.dart';
import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/test_logging.dart';

/// The change-password sheet builds its own `ChangePasswordCubit`, so the real
/// cubit and repository run against the ApiClient adapter seam.
void main() {
  late FakeApiAdapter adapter;

  /// Rejects every submit, so the sheet's failure branch renders instead of
  /// the success branch — which clears the auth box, and a Hive write started
  /// inside a `testWidgets` body never completes (it would block `tearDown`'s
  /// `box.close()` forever). The success path is covered end-to-end in
  /// `integration_test/profile_flow_test.dart`.
  void stubRejectedWith(String message) {
    adapter = FakeApiAdapter({
      ApiEndpoints.resetPassword: (_) => {'status': 0, 'message': message},
    });
    ApiClient().httpClientAdapter = adapter;
  }

  setUp(() async {
    // The password checklist reads the policy out of the settings box, and
    // DioInterceptor reads the active language from it on every request.
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);
    stubRejectedWith('Old password is incorrect');
  });

  tearDown(() async {
    await Hive.box(settingsBox).close();
    await Hive.deleteBoxFromDisk(settingsBox);
    await HiveTestHelper.tearDown(authBox);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Finder appTextWith(String text) =>
      find.byWidgetPredicate((w) => w is AppText && w.text == text);

  Future<void> openSheet(WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Three fields plus the checklist are taller than the default surface.
    // Pin the pixel ratio too — physicalSize alone is divided by 3.0.
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showChangePasswordSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  Future<void> fillForm(
    WidgetTester tester, {
    String oldPassword = 'OldPass1!',
    String password = 'NewPass1!',
    String confirm = 'NewPass1!',
  }) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), oldPassword);
    await tester.enterText(fields.at(1), password);
    await tester.enterText(fields.at(2), confirm);
    await tester.pump();
  }

  testWidgets('renders the three password fields and the submit button', (
    tester,
  ) async {
    printTestDivider('ChangePasswordSheet renders its fields');
    await openSheet(tester);

    printTestLog(
      'fields → expected: 3, actual: ${find.byType(TextFormField).evaluate().length}',
    );
    expect(find.byType(TextFormField), findsNWidgets(3));
    for (final key in [
      LanguageLabelKeys.oldPassword,
      LanguageLabelKeys.newPassword,
      LanguageLabelKeys.confirmPassword,
      LanguageLabelKeys.updatePassword,
    ]) {
      printTestLog(
        'label → expected: 1 "$key", actual: ${appTextWith(key).evaluate().length}',
      );
      expect(appTextWith(key), findsOneWidget);
    }
  });

  testWidgets('an empty form does not submit and shows the required errors', (
    tester,
  ) async {
    printTestDivider('ChangePasswordSheet blocks an empty submit');
    await openSheet(tester);

    await tester.tap(appTextWith(LanguageLabelKeys.updatePassword));
    await tester.pump();

    printTestLog('requests → expected: none, actual: ${adapter.requestedPaths}');
    expect(adapter.requestedPaths, isEmpty);
    for (final key in [
      LanguageLabelKeys.oldPasswordRequired,
      LanguageLabelKeys.passwordRequired,
      LanguageLabelKeys.confirmPasswordRequired,
    ]) {
      printTestLog(
        'error → expected: 1 "$key", actual: ${find.text(key).evaluate().length}',
      );
      expect(find.text(key), findsOneWidget);
    }
  });

  testWidgets('a mismatched confirmation blocks the submit', (tester) async {
    printTestDivider('ChangePasswordSheet blocks a mismatched confirmation');
    await openSheet(tester);
    await fillForm(tester, confirm: 'Different1!');

    await tester.tap(appTextWith(LanguageLabelKeys.updatePassword));
    await tester.pump();

    printTestLog(
      'error → expected: 1 "${LanguageLabelKeys.passwordsDoNotMatch}", '
      'actual: ${find.text(LanguageLabelKeys.passwordsDoNotMatch).evaluate().length}',
    );
    expect(find.text(LanguageLabelKeys.passwordsDoNotMatch), findsOneWidget);
    printTestLog('requests → expected: none, actual: ${adapter.requestedPaths}');
    expect(adapter.requestedPaths, isEmpty);
  });

  testWidgets('a new password below the policy blocks the submit', (
    tester,
  ) async {
    printTestDivider('ChangePasswordSheet enforces the password policy');
    await openSheet(tester);
    // Default policy with no app settings stored: at least 5 characters.
    await fillForm(tester, password: 'abc', confirm: 'abc');

    await tester.tap(appTextWith(LanguageLabelKeys.updatePassword));
    await tester.pump();

    printTestLog(
      'error → expected: 1 "${LanguageLabelKeys.passwordRequirementsNotMet}", '
      'actual: ${find.text(LanguageLabelKeys.passwordRequirementsNotMet).evaluate().length}',
    );
    expect(
      find.text(LanguageLabelKeys.passwordRequirementsNotMet),
      findsOneWidget,
    );
    printTestLog('requests → expected: none, actual: ${adapter.requestedPaths}');
    expect(adapter.requestedPaths, isEmpty);
  });

  testWidgets('the requirements checklist appears once typing starts', (
    tester,
  ) async {
    printTestDivider('ChangePasswordSheet shows the requirements checklist');
    await openSheet(tester);

    printTestLog(
      'checklist before typing → expected: 0, '
      'actual: ${find.byType(PasswordRequirementsChecklist).evaluate().length}',
    );
    expect(find.byType(PasswordRequirementsChecklist), findsNothing);

    await tester.enterText(find.byType(TextFormField).at(1), 'N');
    await tester.pump();

    printTestLog(
      'checklist after typing → expected: 1, '
      'actual: ${find.byType(PasswordRequirementsChecklist).evaluate().length}',
    );
    expect(find.byType(PasswordRequirementsChecklist), findsOneWidget);
  });

  testWidgets('the eye button toggles the old-password field obscuring', (
    tester,
  ) async {
    printTestDivider('ChangePasswordSheet toggles password visibility');
    await openSheet(tester);

    final hiddenIcon = find.byWidgetPredicate(
      (w) => w is AppSvgIcon && w.path == AssetsConstants.passwordHideIcon,
    );
    printTestLog(
      'hidden icons → expected: 3, actual: ${hiddenIcon.evaluate().length}',
    );
    expect(hiddenIcon, findsNWidgets(3));

    await tester.tap(find.byType(IconButton).first);
    await tester.pump();

    final visibleIcon = find.byWidgetPredicate(
      (w) => w is AppSvgIcon && w.path == AssetsConstants.passwordVisibleIcon,
    );
    printTestLog(
      'visible icons after tap → expected: 1, actual: ${visibleIcon.evaluate().length}',
    );
    expect(visibleIcon, findsOneWidget);
    printTestLog(
      'hidden icons after tap → expected: 2, actual: ${hiddenIcon.evaluate().length}',
    );
    expect(hiddenIcon, findsNWidgets(2));
  });

  testWidgets('a valid form posts the trimmed passwords', (tester) async {
    printTestDivider('ChangePasswordSheet posts the trimmed passwords');
    await openSheet(tester);
    await fillForm(tester, oldPassword: '  OldPass1!  ');

    await tester.tap(appTextWith(LanguageLabelKeys.updatePassword));
    await tester.pumpAndSettle();

    printTestLog(
      'requests → expected: [${ApiEndpoints.resetPassword}], actual: ${adapter.requestedPaths}',
    );
    expect(adapter.requestedPaths, [ApiEndpoints.resetPassword]);
    final body = adapter.requests.single.data as Map<String, dynamic>;
    printTestLog('body → expected: trimmed passwords, actual: $body');
    expect(body[ApiParameters.oldPassword], 'OldPass1!');
    expect(body[ApiParameters.newPassword], 'NewPass1!');
    expect(body[ApiParameters.confirmPassword], 'NewPass1!');
  });

  testWidgets('a rejected change shows the server message and keeps the sheet open', (
    tester,
  ) async {
    printTestDivider('ChangePasswordSheet surfaces a rejected change');
    stubRejectedWith('Old password is incorrect');
    await openSheet(tester);
    await fillForm(tester);

    await tester.tap(appTextWith(LanguageLabelKeys.updatePassword));
    await tester.pumpAndSettle();

    printTestLog(
      'error banner → expected: 1 "Old password is incorrect", '
      'actual: ${appTextWith('Old password is incorrect').evaluate().length}',
    );
    expect(appTextWith('Old password is incorrect'), findsOneWidget);
    printTestLog(
      'sheet → expected: still open, '
      'actual: ${find.byType(TextFormField).evaluate().length} fields',
    );
    expect(find.byType(TextFormField), findsNWidgets(3));
  });
}
