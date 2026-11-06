import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/models/countries_model.dart';
import 'package:customer/features/auth/cubits/auth_cubit.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/features/auth/widgets/sign_up_form.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  // The password field's validator (`v.validatePassword(context)`) reads
  // `PasswordPolicy.fromSettings()` → `SettingsHiveBox` during its very
  // first build, same gotcha `forgot_password_password_section_test.dart`
  // hit — every test that renders with `showPassword: true` needs the box.
  setUpAll(() => HiveTestHelper.setUp(settingsBox));
  tearDownAll(() async {
    await HiveTestHelper.tearDown(settingsBox);
    printTestDivider('=== All tests run! ===');
  });

  final country = CountriesData(id: 1, name: 'US', dialCode: '+1', minMobileLength: 10);

  Widget buildForm({
    required bool showEmail,
    required bool showPhone,
    required bool showPassword,
    AuthType mode = AuthType.email,
  }) {
    return SignUpForm(
      formKey: GlobalKey<FormState>(),
      nameController: TextEditingController(),
      emailController: TextEditingController(),
      phoneController: TextEditingController(),
      passwordController: TextEditingController(),
      confirmPasswordController: TextEditingController(),
      referralController: TextEditingController(),
      mode: mode,
      showEmail: showEmail,
      showPhone: showPhone,
      showPassword: showPassword,
      phoneReadOnly: false,
      onPhoneChanged: (_, _) {},
      selectedCountry: country,
      onCountryChanged: (_) {},
    );
  }

  testWidgets('always renders the name field and the country dropdown', (tester) async {
    printTestDivider('SignUpForm always renders the name field and the country dropdown');
    await tester.pumpWidget(
      pumpTestWidget(
        buildForm(showEmail: false, showPhone: false, showPassword: false),
      ),
    );

    printTestLog(
      'Full name label → expected: present, actual: ${find.text('${LanguageLabelKeys.fullName} *', findRichText: true).evaluate().isNotEmpty}',
    );
    expect(find.text('${LanguageLabelKeys.fullName} *', findRichText: true), findsOneWidget);
    printTestLog(
      'Country label → expected: present, actual: ${find.text(LanguageLabelKeys.country, findRichText: true).evaluate().isNotEmpty}',
    );
    expect(find.text(LanguageLabelKeys.country, findRichText: true), findsOneWidget);
  });

  testWidgets('hides the email/phone/password fields when their show flags are false', (
    tester,
  ) async {
    printTestDivider(
      'SignUpForm hides the email/phone/password fields when their show flags are false',
    );
    await tester.pumpWidget(
      pumpTestWidget(
        buildForm(showEmail: false, showPhone: false, showPassword: false),
      ),
    );

    printTestLog(
      'Email label → expected: absent, actual: ${find.text('${LanguageLabelKeys.email} *', findRichText: true).evaluate().isEmpty}',
    );
    expect(find.text('${LanguageLabelKeys.email} *', findRichText: true), findsNothing);
    printTestLog(
      'Phone label → expected: absent, actual: ${find.text('${LanguageLabelKeys.phoneNumber} *', findRichText: true).evaluate().isEmpty}',
    );
    expect(find.text('${LanguageLabelKeys.phoneNumber} *', findRichText: true), findsNothing);
    printTestLog(
      'Password label → expected: absent, actual: ${find.text(LanguageLabelKeys.password, findRichText: true).evaluate().isEmpty}',
    );
    expect(find.text(LanguageLabelKeys.password, findRichText: true), findsNothing);
  });

  testWidgets('shows the email/phone/password fields when their show flags are true', (
    tester,
  ) async {
    printTestDivider(
      'SignUpForm shows the email/phone/password fields when their show flags are true',
    );
    await tester.pumpWidget(
      pumpTestWidget(
        buildForm(showEmail: true, showPhone: true, showPassword: true),
      ),
    );

    printTestLog(
      'Email label → expected: present, actual: ${find.text('${LanguageLabelKeys.email} *', findRichText: true).evaluate().isNotEmpty}',
    );
    expect(find.text('${LanguageLabelKeys.email} *', findRichText: true), findsOneWidget);
    printTestLog(
      'Phone label → expected: present, actual: ${find.text('${LanguageLabelKeys.phoneNumber} *', findRichText: true).evaluate().isNotEmpty}',
    );
    expect(find.text('${LanguageLabelKeys.phoneNumber} *', findRichText: true), findsOneWidget);
    printTestLog(
      'Password label → expected: present, actual: ${find.text(LanguageLabelKeys.password, findRichText: true).evaluate().isNotEmpty}',
    );
    expect(find.text(LanguageLabelKeys.password, findRichText: true), findsOneWidget);
    printTestLog(
      'Referral field → expected: absent (isReferalOn not 1 on fixture country), actual: ${find.text(LanguageLabelKeys.referralCode, findRichText: true).evaluate().isEmpty}',
    );
    expect(find.text(LanguageLabelKeys.referralCode, findRichText: true), findsNothing);
  });

  testWidgets('the name field is read-only in social (google/apple) mode', (tester) async {
    printTestDivider('SignUpForm the name field is read-only in social (google/apple) mode');
    await tester.pumpWidget(
      pumpTestWidget(
        buildForm(
          showEmail: false,
          showPhone: false,
          showPassword: false,
          mode: AuthType.google,
        ),
      ),
    );

    final nameField = tester.widget<AppTextField>(find.byType(AppTextField).first);
    printTestLog('name field readOnly → expected: true, actual: ${nameField.readOnly}');
    expect(nameField.readOnly, isTrue);
  });
}
