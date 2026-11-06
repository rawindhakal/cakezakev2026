import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/app_text_field.dart';
import 'package:deliveryboy/commons/widgets/password_requirements_checklist.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/auth/widgets/register_credential_fields.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late TextEditingController name;
  late TextEditingController email;
  late TextEditingController dob;
  late TextEditingController mobile;
  late TextEditingController password;
  late TextEditingController confirmPassword;
  late GlobalKey<FormState> formKey;

  // The password checklist reads PasswordPolicy.fromSettings() -> SettingsHiveBox.
  setUp(() async {
    await HiveTestHelper.setUp(settingsBox);
    name = TextEditingController();
    email = TextEditingController();
    dob = TextEditingController();
    mobile = TextEditingController();
    password = TextEditingController();
    confirmPassword = TextEditingController();
    formKey = GlobalKey<FormState>();
  });

  tearDown(() async {
    name.dispose();
    email.dispose();
    dob.dispose();
    mobile.dispose();
    password.dispose();
    confirmPassword.dispose();
    await HiveTestHelper.tearDown(settingsBox);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpFields(
    WidgetTester tester, {
    bool obscurePassword = true,
    bool obscureConfirm = true,
    VoidCallback? onPickDob,
    VoidCallback? onToggleObscurePassword,
    VoidCallback? onToggleObscureConfirm,
  }) async {
    // Taller than the default 800x600 surface, and devicePixelRatio pinned so
    // physicalSize is also the logical size.
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      pumpTestWidget(
        SingleChildScrollView(
          child: Form(
            key: formKey,
            child: RegisterCredentialFields(
              nameController: name,
              emailController: email,
              dobController: dob,
              mobileController: mobile,
              passwordController: password,
              confirmPasswordController: confirmPassword,
              selectedCountry: null,
              onCountryChanged: (_) {},
              selectedZone: null,
              onZoneChanged: (_) {},
              onPickDob: onPickDob ?? () {},
              obscurePassword: obscurePassword,
              onToggleObscurePassword: onToggleObscurePassword ?? () {},
              obscureConfirm: obscureConfirm,
              onToggleObscureConfirm: onToggleObscureConfirm ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('an empty form fails validation on every required field', (
    tester,
  ) async {
    printTestDivider('an empty form fails validation on every required field');
    await pumpFields(tester);

    final isValid = formKey.currentState!.validate();
    await tester.pump();

    printTestLog('form.validate() → expected: false, actual: $isValid');
    expect(isValid, isFalse);
    // Translations aren't loaded in tests, so LocalizationService falls back
    // to the raw key — the key is what renders as the error text.
    printTestLog('email error → expected: "${LanguageLabelKeys.emailRequired}" visible');
    expect(find.text(LanguageLabelKeys.emailRequired), findsOneWidget);
    printTestLog('password error → expected: "${LanguageLabelKeys.passwordRequired}" visible');
    expect(find.text(LanguageLabelKeys.passwordRequired), findsOneWidget);
    printTestLog(
      'confirm password error → expected: "${LanguageLabelKeys.confirmPasswordRequired}" visible',
    );
    expect(find.text(LanguageLabelKeys.confirmPasswordRequired), findsOneWidget);
  });

  testWidgets('a confirm password that differs from the password is rejected', (
    tester,
  ) async {
    printTestDivider(
      'a confirm password that differs from the password is rejected',
    );
    password.text = 'Passw0rd!';
    confirmPassword.text = 'Different1!';
    await pumpFields(tester);

    formKey.currentState!.validate();
    await tester.pump();

    printTestLog(
      'mismatch error → expected: "${LanguageLabelKeys.passwordsDoNotMatch}" visible',
    );
    expect(find.text(LanguageLabelKeys.passwordsDoNotMatch), findsOneWidget);
  });

  testWidgets('a matching confirm password produces no mismatch error', (
    tester,
  ) async {
    printTestDivider('a matching confirm password produces no mismatch error');
    password.text = 'Passw0rd!';
    confirmPassword.text = 'Passw0rd!';
    await pumpFields(tester);

    formKey.currentState!.validate();
    await tester.pump();

    printTestLog(
      'mismatch error → expected: absent, actual: ${find.text(LanguageLabelKeys.passwordsDoNotMatch).evaluate().length} match(es)',
    );
    expect(find.text(LanguageLabelKeys.passwordsDoNotMatch), findsNothing);
  });

  testWidgets('the password requirements checklist appears only once typing starts', (
    tester,
  ) async {
    printTestDivider(
      'the password requirements checklist appears only once typing starts',
    );
    await pumpFields(tester);

    printTestLog(
      'checklist before typing → expected: absent, actual: ${find.byType(PasswordRequirementsChecklist).evaluate().length} match(es)',
    );
    expect(find.byType(PasswordRequirementsChecklist), findsNothing);

    password.text = 'abc';
    await tester.pump();

    printTestLog(
      'checklist after typing → expected: present, actual: ${find.byType(PasswordRequirementsChecklist).evaluate().length} match(es)',
    );
    expect(find.byType(PasswordRequirementsChecklist), findsOneWidget);
  });

  testWidgets('the date-of-birth field is read-only and opens the picker on tap', (
    tester,
  ) async {
    printTestDivider(
      'the date-of-birth field is read-only and opens the picker on tap',
    );
    var pickerOpened = false;
    await pumpFields(tester, onPickDob: () => pickerOpened = true);

    // Field order: name, email, dob — dob is the third AppTextField.
    final dobField = tester.widget<AppTextField>(
      find.byType(AppTextField).at(2),
    );
    printTestLog('dob readOnly → expected: true, actual: ${dobField.readOnly}');
    expect(dobField.readOnly, isTrue);

    dobField.onTap!();
    await tester.pump();

    printTestLog('onPickDob called → expected: true, actual: $pickerOpened');
    expect(pickerOpened, isTrue);
  });

  testWidgets('obscure flags drive both password fields', (tester) async {
    printTestDivider('obscure flags drive both password fields');
    await pumpFields(tester, obscurePassword: true, obscureConfirm: false);

    final fields = tester
        .widgetList<AppTextField>(find.byType(AppTextField))
        .toList();
    // Password and confirm password are the last two AppTextFields.
    final passwordField = fields[fields.length - 2];
    final confirmField = fields.last;

    printTestLog('password.obscureText → expected: true, actual: ${passwordField.obscureText}');
    expect(passwordField.obscureText, isTrue);
    printTestLog('confirm.obscureText  → expected: false, actual: ${confirmField.obscureText}');
    expect(confirmField.obscureText, isFalse);
  });

  testWidgets('tapping a visibility toggle invokes its callback', (tester) async {
    printTestDivider('tapping a visibility toggle invokes its callback');
    var passwordToggled = false;
    var confirmToggled = false;
    await pumpFields(
      tester,
      onToggleObscurePassword: () => passwordToggled = true,
      onToggleObscureConfirm: () => confirmToggled = true,
    );

    final toggles = find.byType(IconButton);
    await tester.tap(toggles.first);
    await tester.tap(toggles.last);
    await tester.pump();

    printTestLog('password toggle → expected: true, actual: $passwordToggled');
    expect(passwordToggled, isTrue);
    printTestLog('confirm toggle  → expected: true, actual: $confirmToggled');
    expect(confirmToggled, isTrue);
  });
}
