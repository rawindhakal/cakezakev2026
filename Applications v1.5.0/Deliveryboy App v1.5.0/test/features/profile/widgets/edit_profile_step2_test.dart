import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/profile/widgets/edit_profile_step2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

/// Step 2 is the bank-details form: four required fields, one of them
/// digits-only.
void main() {
  late GlobalKey<FormState> formKey;
  late TextEditingController bankName;
  late TextEditingController accountNumber;
  late TextEditingController ifscCode;
  late TextEditingController accountName;

  setUp(() {
    formKey = GlobalKey<FormState>();
    bankName = TextEditingController();
    accountNumber = TextEditingController();
    ifscCode = TextEditingController();
    accountName = TextEditingController();
  });

  tearDown(() {
    bankName.dispose();
    accountNumber.dispose();
    ifscCode.dispose();
    accountName.dispose();
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Finder appTextWith(String text) =>
      find.byWidgetPredicate((w) => w is AppText && w.text == text);

  Future<void> pumpStep(WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Four labelled fields need more than the default 800×600 surface — and
    // physicalSize alone is divided by a default ratio of 3.0.
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      pumpTestWidget(
        SingleChildScrollView(
          child: EditProfileStep2(
            formKey: formKey,
            bankNameController: bankName,
            accountNumberController: accountNumber,
            ifscCodeController: ifscCode,
            accountNameController: accountName,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the four bank fields with their labels', (tester) async {
    printTestDivider('EditProfileStep2 renders the four bank fields');
    await pumpStep(tester);

    printTestLog(
      'fields → expected: 4, actual: ${find.byType(TextFormField).evaluate().length}',
    );
    expect(find.byType(TextFormField), findsNWidgets(4));
    for (final key in [
      LanguageLabelKeys.bankName,
      LanguageLabelKeys.accountNumber,
      LanguageLabelKeys.ifscCode,
      LanguageLabelKeys.accountHolderName,
    ]) {
      printTestLog(
        'label → expected: 1 "$key", actual: ${appTextWith(key).evaluate().length}',
      );
      expect(appTextWith(key), findsOneWidget);
    }
  });

  testWidgets('an empty form fails validation on every field', (tester) async {
    printTestDivider('EditProfileStep2 rejects an empty form');
    await pumpStep(tester);

    final isValid = formKey.currentState!.validate();
    await tester.pump();

    printTestLog('validate() → expected: false, actual: $isValid');
    expect(isValid, isFalse);
    // Every field uses the same "{field} is required" template, so the four
    // errors differ only by the field name substituted into it.
    printTestLog(
      'errors → expected: 4, actual: ${find.textContaining(LanguageLabelKeys.fieldRequired).evaluate().length}',
    );
    expect(
      find.textContaining(LanguageLabelKeys.fieldRequired),
      findsNWidgets(4),
    );
  });

  testWidgets('a fully filled form passes validation', (tester) async {
    printTestDivider('EditProfileStep2 accepts a filled form');
    await pumpStep(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Bank of Globe');
    await tester.enterText(find.byType(TextFormField).at(1), '9000323402965');
    await tester.enterText(find.byType(TextFormField).at(2), 'BANGLOB');
    await tester.enterText(find.byType(TextFormField).at(3), 'Alex Johnson');

    final isValid = formKey.currentState!.validate();
    await tester.pump();

    printTestLog('validate() → expected: true, actual: $isValid');
    expect(isValid, isTrue);
    printTestLog(
      'controllers → expected: the typed values, '
      'actual: ${[bankName.text, accountNumber.text, ifscCode.text, accountName.text]}',
    );
    expect(bankName.text, 'Bank of Globe');
    expect(accountNumber.text, '9000323402965');
    expect(ifscCode.text, 'BANGLOB');
    expect(accountName.text, 'Alex Johnson');
  });

  testWidgets('the account number field drops non-digits', (tester) async {
    printTestDivider('EditProfileStep2 account number accepts digits only');
    await pumpStep(tester);

    await tester.enterText(find.byType(TextFormField).at(1), '12ab34-56');
    await tester.pump();

    printTestLog(
      'account number → expected: "123456", actual: "${accountNumber.text}"',
    );
    expect(accountNumber.text, '123456');
  });

  testWidgets('prefilled controllers show up in the fields', (tester) async {
    printTestDivider('EditProfileStep2 shows prefilled values');
    bankName.text = 'Bank of Globe';
    accountName.text = 'Alex Johnson';
    await pumpStep(tester);

    printTestLog(
      'prefilled bank name → expected: 1, actual: ${find.text('Bank of Globe').evaluate().length}',
    );
    expect(find.text('Bank of Globe'), findsOneWidget);
    printTestLog(
      'prefilled holder → expected: 1, actual: ${find.text('Alex Johnson').evaluate().length}',
    );
    expect(find.text('Alex Johnson'), findsOneWidget);
  });
}
