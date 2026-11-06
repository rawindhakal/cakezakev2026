import 'package:deliveryboy/commons/models/countries_model.dart';
import 'package:deliveryboy/commons/models/earning_type.dart';
import 'package:deliveryboy/commons/models/zones_model.dart';
import 'package:deliveryboy/commons/widgets/app_image_upload_field.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/commons/widgets/app_text_field.dart';
import 'package:deliveryboy/commons/widgets/country_phone_field.dart';
import 'package:deliveryboy/commons/widgets/earning_type_selector.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/profile/widgets/edit_profile_step1.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late GlobalKey<FormState> formKey;
  late TextEditingController username;
  late TextEditingController email;
  late TextEditingController dob;
  late TextEditingController mobile;
  late TextEditingController address;
  late TextEditingController commission;
  late TextEditingController bonusMin;
  late TextEditingController bonusMax;
  late TextEditingController returnCommission;
  late TextEditingController returnBonusMin;
  late TextEditingController returnBonusMax;

  setUp(() {
    formKey = GlobalKey<FormState>();
    username = TextEditingController();
    email = TextEditingController();
    dob = TextEditingController();
    mobile = TextEditingController();
    address = TextEditingController();
    commission = TextEditingController();
    bonusMin = TextEditingController();
    bonusMax = TextEditingController();
    returnCommission = TextEditingController();
    returnBonusMin = TextEditingController();
    returnBonusMax = TextEditingController();
  });

  tearDown(() {
    username.dispose();
    email.dispose();
    dob.dispose();
    mobile.dispose();
    address.dispose();
    commission.dispose();
    bonusMin.dispose();
    bonusMax.dispose();
    returnCommission.dispose();
    returnBonusMin.dispose();
    returnBonusMax.dispose();
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Finder appTextWith(String text) =>
      find.byWidgetPredicate((w) => w is AppText && w.text == text);

  Future<void> pumpStep(
    WidgetTester tester, {
    EarningType earningType = EarningType.salaried,
    EarningType returnEarningType = EarningType.salaried,
    String? nationalIdError,
    String? drivingLicenseError,
    VoidCallback? onPickDob,
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 3200);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      pumpTestWidget(
        SingleChildScrollView(
          child: EditProfileStep1(
            formKey: formKey,
            usernameController: username,
            emailController: email,
            dobController: dob,
            mobileController: mobile,
            addressController: address,
            commissionController: commission,
            bonusMinController: bonusMin,
            bonusMaxController: bonusMax,
            returnCommissionController: returnCommission,
            returnBonusMinController: returnBonusMin,
            returnBonusMaxController: returnBonusMax,
            returnEarningType: returnEarningType,
            nationalIdImage: null,
            nationalIdImageUrl: null,
            drivingLicenseImage: null,
            drivingLicenseImageUrl: null,
            nationalIdError: nationalIdError,
            drivingLicenseError: drivingLicenseError,
            earningType: earningType,
            selectedCountry: CountriesData(id: 1, name: 'India', dialCode: '+91'),
            selectedZone: ZonesData(id: 2, name: 'North Zone'),
            onZoneChanged: (_) {},
            onEarningTypeChanged: (_) {},
            onNationalIdPicked: (_) {},
            onDrivingLicensePicked: (_) {},
            onPickDob: onPickDob ?? () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('an empty form fails validation on fullName and address only', (
    tester,
  ) async {
    printTestDivider(
      'EditProfileStep1 rejects an empty form on fullName/address, leaves email alone',
    );
    await pumpStep(tester);

    final isValid = formKey.currentState!.validate();
    await tester.pump();

    printTestLog('validate() → expected: false, actual: $isValid');
    expect(isValid, isFalse);
    printTestLog(
      'errors → expected: 2 (fullName + address), actual: ${find.textContaining(LanguageLabelKeys.fieldRequired).evaluate().length}',
    );
    expect(find.textContaining(LanguageLabelKeys.fieldRequired), findsNWidgets(2));
  });

  testWidgets('fullName and address filled, email left empty, passes validation', (
    tester,
  ) async {
    printTestDivider('EditProfileStep1 accepts an empty optional email');
    await pumpStep(tester);

    // ApiCountryPhoneField falls back to its own validateMobile validator
    // when step1 doesn't pass one, so mobile is required too even though it
    // uses a different error message than the "field is required" template
    // (the empty-form test above only counts that template).
    await tester.enterText(
      find.byWidgetPredicate((w) => w is AppTextField && w.controller == username),
      'Alex Johnson',
    );
    await tester.enterText(
      find.byWidgetPredicate((w) => w is AppTextField && w.controller == address),
      'Mumbai',
    );
    await tester.enterText(
      find.byWidgetPredicate((w) => w is AppTextField && w.controller == mobile),
      '1234567890',
    );
    await tester.pump();

    final isValid = formKey.currentState!.validate();
    await tester.pump();

    printTestLog('validate() → expected: true, actual: $isValid');
    expect(isValid, isTrue);
  });

  testWidgets('an invalid email fails validation even though the field is optional', (
    tester,
  ) async {
    printTestDivider('EditProfileStep1 rejects a malformed email');
    await pumpStep(tester);

    await tester.enterText(
      find.byWidgetPredicate((w) => w is AppTextField && w.controller == username),
      'Alex Johnson',
    );
    await tester.enterText(
      find.byWidgetPredicate((w) => w is AppTextField && w.controller == address),
      'Mumbai',
    );
    await tester.enterText(
      find.byWidgetPredicate((w) => w is AppTextField && w.controller == email),
      'not-an-email',
    );
    await tester.pump();

    final isValid = formKey.currentState!.validate();
    await tester.pump();

    printTestLog('validate() → expected: false, actual: $isValid');
    expect(isValid, isFalse);
  });

  testWidgets('the DOB field is read-only and opens the picker via onPickDob on tap', (
    tester,
  ) async {
    printTestDivider('EditProfileStep1 DOB field is read-only and calls onPickDob');
    var picked = false;
    await pumpStep(tester, onPickDob: () => picked = true);

    final dobField = tester.widget<AppTextField>(
      find.byWidgetPredicate((w) => w is AppTextField && w.controller == dob),
    );
    printTestLog('readOnly → expected: true, actual: ${dobField.readOnly}');
    expect(dobField.readOnly, isTrue);

    await tester.tap(find.byWidgetPredicate((w) => w is AppTextField && w.controller == dob));
    await tester.pump();

    printTestLog('onPickDob called → expected: true, actual: $picked');
    expect(picked, isTrue);
  });

  testWidgets('the mobile field keeps the country picker read-only', (
    tester,
  ) async {
    printTestDivider('EditProfileStep1 mobile field has countryReadOnly true');
    await pumpStep(tester);

    final phoneField = tester.widget<ApiCountryPhoneField>(
      find.byType(ApiCountryPhoneField),
    );
    printTestLog(
      'countryReadOnly → expected: true, actual: ${phoneField.countryReadOnly}',
    );
    expect(phoneField.countryReadOnly, isTrue);
  });

  testWidgets('national id and driving license tiles show their own error text', (
    tester,
  ) async {
    printTestDivider('EditProfileStep1 image tiles show their errorText');
    await pumpStep(
      tester,
      nationalIdError: 'National ID is required',
      drivingLicenseError: 'Driving license is required',
    );

    final tiles = tester.widgetList<AppImageUploadField>(
      find.byType(AppImageUploadField),
    ).toList();
    printTestLog('image tiles → expected: 2, actual: ${tiles.length}');
    expect(tiles.length, 2);
    printTestLog(
      'national id error → expected: "National ID is required", actual: "${tiles[0].errorText}"',
    );
    expect(tiles[0].errorText, 'National ID is required');
    printTestLog(
      'driving license error → expected: "Driving license is required", actual: "${tiles[1].errorText}"',
    );
    expect(tiles[1].errorText, 'Driving license is required');
  });

  testWidgets('both earning-type selectors are display-only (disabled)', (
    tester,
  ) async {
    printTestDivider('EditProfileStep1 earning-type selectors are disabled');
    await pumpStep(tester);

    final selectors = tester.widgetList<IgnorePointer>(
      find.descendant(
        of: find.byType(EarningTypeSelector),
        matching: find.byType(IgnorePointer),
      ),
    ).toList();
    printTestLog(
      'ignoring on both selectors → expected: [true, true], '
      'actual: ${selectors.map((w) => w.ignoring).toList()}',
    );
    expect(selectors.every((w) => w.ignoring), isTrue);
  });

  testWidgets('the commission block is hidden when earningType is salaried', (
    tester,
  ) async {
    printTestDivider('EditProfileStep1 hides the commission block when salaried');
    await pumpStep(tester, earningType: EarningType.salaried);

    printTestLog(
      'commission label → expected: absent, actual: ${appTextWith(LanguageLabelKeys.commissionPercent).evaluate().length}',
    );
    expect(appTextWith(LanguageLabelKeys.commissionPercent), findsNothing);
  });

  testWidgets('the commission block shows and requires a value when earningType is commission', (
    tester,
  ) async {
    printTestDivider(
      'EditProfileStep1 shows and validates the commission block when earningType is commission',
    );
    await pumpStep(tester, earningType: EarningType.commission);
    await tester.enterText(
      find.byWidgetPredicate((w) => w is AppTextField && w.controller == username),
      'Alex Johnson',
    );
    await tester.enterText(
      find.byWidgetPredicate((w) => w is AppTextField && w.controller == address),
      'Mumbai',
    );
    await tester.enterText(
      find.byWidgetPredicate((w) => w is AppTextField && w.controller == mobile),
      '1234567890',
    );
    await tester.pump();

    printTestLog(
      'commission label → expected: visible, actual: ${appTextWith(LanguageLabelKeys.commissionPercent).evaluate().length}',
    );
    expect(appTextWith(LanguageLabelKeys.commissionPercent), findsOneWidget);

    // Commission left empty — the main commission field has a validator wired.
    final isValid = formKey.currentState!.validate();
    await tester.pump();
    printTestLog('validate() with empty commission → expected: false, actual: $isValid');
    expect(isValid, isFalse);
  });

  testWidgets('the return-earning commission field has no validator wired, unlike the main one', (
    tester,
  ) async {
    printTestDivider(
      'EditProfileStep1 leaves the return-commission field unvalidated (documented asymmetry)',
    );
    await pumpStep(
      tester,
      earningType: EarningType.salaried,
      returnEarningType: EarningType.commission,
    );
    await tester.enterText(
      find.byWidgetPredicate((w) => w is AppTextField && w.controller == username),
      'Alex Johnson',
    );
    await tester.enterText(
      find.byWidgetPredicate((w) => w is AppTextField && w.controller == address),
      'Mumbai',
    );
    await tester.enterText(
      find.byWidgetPredicate((w) => w is AppTextField && w.controller == mobile),
      '1234567890',
    );
    await tester.pump();

    // returnCommission stays empty on purpose — only fullName/address are
    // required here, so the form must still pass.
    final isValid = formKey.currentState!.validate();
    await tester.pump();
    printTestLog(
      'validate() with empty return-commission → expected: true, actual: $isValid',
    );
    expect(isValid, isTrue);
  });

  testWidgets('commission and min/max fields are read-only with a digits-only formatter', (
    tester,
  ) async {
    printTestDivider(
      'EditProfileStep1 commission/min/max fields are read-only digits-only (display-only, filled by the app itself)',
    );
    await pumpStep(tester, earningType: EarningType.commission);

    for (final controller in [commission, bonusMin, bonusMax]) {
      final field = tester.widget<AppTextField>(
        find.byWidgetPredicate((w) => w is AppTextField && w.controller == controller),
      );
      printTestLog('readOnly → expected: true, actual: ${field.readOnly}');
      expect(field.readOnly, isTrue);
      printTestLog(
        'digitsOnly formatter present → expected: true, actual: ${field.inputFormatters?.any((f) => f is FilteringTextInputFormatter)}',
      );
      expect(
        field.inputFormatters?.any((f) => f is FilteringTextInputFormatter),
        isTrue,
      );
    }
  });
}
