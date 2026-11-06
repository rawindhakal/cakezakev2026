import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/password_requirements_checklist.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/features/auth/widgets/forgot_password_password_section.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  // `AppTextField`'s new-password validator and the requirements checklist
  // both call `PasswordPolicy.fromSettings()`, which reads
  // `SettingsHiveBox.instance.getAppSettings()` unconditionally — even
  // before any text is entered, since the field's validator runs during the
  // very first build. Every test in this file needs the box open, the same
  // gotcha blog's date-formatting widgets hit.
  setUpAll(() => HiveTestHelper.setUp(settingsBox));
  tearDownAll(() async {
    await HiveTestHelper.tearDown(settingsBox);
    printTestDivider('=== All tests run! ===');
  });

  testWidgets('the requirements checklist is hidden until the password field has text', (
    tester,
  ) async {
    printTestDivider(
      'ForgotPasswordPasswordSection the requirements checklist is hidden until the password field has text',
    );
    // Column isn't scrollable and the checklist adds real height — widen the
    // viewport past the default 800x600 so nothing overflows once it mounts
    // (same fix blog's list widget tests needed for an unrelated reason).
    tester.view.physicalSize = const Size(500, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final passwordController = TextEditingController();

    await tester.pumpWidget(
      pumpTestWidget(
        ForgotPasswordPasswordSection(
          passwordController: passwordController,
          confirmPasswordController: TextEditingController(),
          isLoading: false,
          onSubmit: () {},
          submitLabel: 'Reset password',
        ),
      ),
    );

    printTestLog(
      'checklist before typing → expected: absent, actual: ${find.byType(PasswordRequirementsChecklist).evaluate().isEmpty}',
    );
    expect(find.byType(PasswordRequirementsChecklist), findsNothing);

    passwordController.text = 'Weak1';
    await tester.pump();

    printTestLog(
      'checklist after typing → expected: present, actual: ${find.byType(PasswordRequirementsChecklist).evaluate().isNotEmpty}',
    );
    expect(find.byType(PasswordRequirementsChecklist), findsOneWidget);
  });

  testWidgets('the submit button is disabled (onPressed null) while isLoading is true', (
    tester,
  ) async {
    printTestDivider(
      'ForgotPasswordPasswordSection the submit button is disabled while isLoading is true',
    );
    await tester.pumpWidget(
      pumpTestWidget(
        ForgotPasswordPasswordSection(
          passwordController: TextEditingController(),
          confirmPasswordController: TextEditingController(),
          isLoading: true,
          onSubmit: () {},
          submitLabel: 'Reset password',
        ),
      ),
    );

    // AppButton swaps its label for a spinner while isLoading, so the label
    // text isn't even in the tree — assert on onPressed instead.
    final button = tester.widget<AppButton>(find.byType(AppButton));
    printTestLog('onPressed → expected: null, actual: ${button.onPressed}');
    expect(button.onPressed, isNull);
  });

  testWidgets('tapping submit calls onSubmit when not loading', (tester) async {
    printTestDivider(
      'ForgotPasswordPasswordSection tapping submit calls onSubmit when not loading',
    );
    var tapped = false;

    await tester.pumpWidget(
      pumpTestWidget(
        ForgotPasswordPasswordSection(
          passwordController: TextEditingController(),
          confirmPasswordController: TextEditingController(),
          isLoading: false,
          onSubmit: () => tapped = true,
          submitLabel: 'Reset password',
        ),
      ),
    );

    await tester.tap(find.text('Reset password'));
    await tester.pump();

    printTestLog('onSubmit called → expected: true, actual: $tapped');
    expect(tapped, isTrue);
  });
}
