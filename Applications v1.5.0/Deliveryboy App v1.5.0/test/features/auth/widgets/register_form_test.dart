import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:deliveryboy/commons/cubit/countries_cubit.dart';
import 'package:deliveryboy/commons/cubit/zones_cubit.dart';
import 'package:deliveryboy/commons/models/earning_type.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/commons/widgets/earning_type_selector.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/auth/widgets/register_form.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockCountriesCubit countriesCubit;
  late MockZonesCubit zonesCubit;

  // The password field's checklist reads PasswordPolicy.fromSettings(), which
  // goes through SettingsHiveBox — so the settings box has to be open even
  // though no test here asserts on settings.
  setUp(() async {
    await HiveTestHelper.setUp(settingsBox);
    countriesCubit = MockCountriesCubit();
    zonesCubit = MockZonesCubit();
    whenListen(
      countriesCubit,
      const Stream<CountriesState>.empty(),
      initialState: CountriesLoaded(countries: const []),
    );
    whenListen(
      zonesCubit,
      const Stream<ZonesState>.empty(),
      initialState: ZonesLoaded(zones: const []),
    );
  });

  tearDown(() => HiveTestHelper.tearDown(settingsBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  // The full form is far taller than the default 800x600 surface, so buttons
  // and fields further down would sit outside the render tree and never get
  // hit-tested. devicePixelRatio is pinned so physical == logical size.
  void useTallViewport(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1.0;
  }

  // A label rendered with isRequired: true becomes a RichText with " *"
  // appended, so an exact find.text(key) misses it — match the AppText's own
  // text property instead, which is the untranslated key either way.
  Finder findLabel(String key) => find.byWidgetPredicate(
    (w) => w is AppText && w.text == key,
  );

  Widget buildSubject(GlobalKey<RegisterFormState> key, void Function() onCall) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CountriesCubit>.value(value: countriesCubit),
        BlocProvider<ZonesCubit>.value(value: zonesCubit),
      ],
      child: pumpTestWidget(
        RegisterForm(
          key: key,
          onRegister:
              ({
                required String name,
                required String mobile,
                required String password,
                required String confirmPassword,
                required String email,
                required String dob,
                String? profileImagePath,
                String? nationalIdImagePath,
                String? drivingLicenseImagePath,
                required String bonusType,
                required String bonusPercentage,
                String? bonusMinAmount,
                String? bonusMaxAmount,
                required String returnBonusType,
                String? returnBonusPercentage,
                String? returnBonusMinAmount,
                String? returnBonusMaxAmount,
                String? countryId,
                String? countryCode,
                String? zoneId,
              }) => onCall(),
        ),
      ),
    );
  }

  testWidgets('submit() on an empty form does not invoke onRegister', (
    tester,
  ) async {
    printTestDivider('submit() on an empty form does not invoke onRegister');
    useTallViewport(tester);
    final key = GlobalKey<RegisterFormState>();
    var called = false;
    await tester.pumpWidget(buildSubject(key, () => called = true));
    await tester.pump();

    key.currentState!.submit();
    await tester.pump();

    printTestLog('onRegister called → expected: false, actual: $called');
    expect(called, isFalse);
  });

  testWidgets('submit() without identity documents shows both document errors', (
    tester,
  ) async {
    printTestDivider(
      'submit() without identity documents shows both document errors',
    );
    useTallViewport(tester);
    final key = GlobalKey<RegisterFormState>();
    await tester.pumpWidget(buildSubject(key, () {}));
    await tester.pump();

    key.currentState!.submit();
    await tester.pump();

    // Translations aren't loaded in tests, so LocalizationService falls back
    // to the raw key — the key is what renders as the error text.
    printTestLog('national ID error → expected: "${LanguageLabelKeys.nationalIdRequired}" visible');
    expect(find.text(LanguageLabelKeys.nationalIdRequired), findsWidgets);
    printTestLog(
      'driving license error → expected: "${LanguageLabelKeys.drivingLicenseRequired}" visible',
    );
    expect(find.text(LanguageLabelKeys.drivingLicenseRequired), findsWidgets);
  });

  testWidgets('commission fields appear only after picking the commission earning type', (
    tester,
  ) async {
    printTestDivider(
      'commission fields appear only after picking the commission earning type',
    );
    useTallViewport(tester);
    final key = GlobalKey<RegisterFormState>();
    await tester.pumpWidget(buildSubject(key, () {}));
    await tester.pump();

    printTestLog(
      'commission label before → expected: absent, actual: ${findLabel(LanguageLabelKeys.commissionPercent).evaluate().length} match(es)',
    );
    expect(findLabel(LanguageLabelKeys.commissionPercent), findsNothing);

    // Driving the selector's own onChanged rather than tapping a radio tile —
    // the tile's tap target is nested inside RadioGroup and its exact hit box
    // is an implementation detail of EarningTypeSelector.
    final selector = tester.widget<EarningTypeSelector>(
      find.byType(EarningTypeSelector).first,
    );
    selector.onChanged(EarningType.commission);
    await tester.pump();

    printTestLog(
      'commission label after → expected: present, actual: ${findLabel(LanguageLabelKeys.commissionPercent).evaluate().length} match(es)',
    );
    expect(findLabel(LanguageLabelKeys.commissionPercent), findsOneWidget);
    printTestLog(
      'min/max labels → expected: present, actual: min=${findLabel(LanguageLabelKeys.minAmount).evaluate().length}, max=${findLabel(LanguageLabelKeys.maxAmount).evaluate().length}',
    );
    expect(findLabel(LanguageLabelKeys.minAmount), findsOneWidget);
    expect(findLabel(LanguageLabelKeys.maxAmount), findsOneWidget);
  });

  testWidgets('return commission fields toggle independently of the earning type', (
    tester,
  ) async {
    printTestDivider(
      'return commission fields toggle independently of the earning type',
    );
    useTallViewport(tester);
    final key = GlobalKey<RegisterFormState>();
    await tester.pumpWidget(buildSubject(key, () {}));
    await tester.pump();

    // The second selector is the return-earning one.
    final returnSelector = tester.widget<EarningTypeSelector>(
      find.byType(EarningTypeSelector).at(1),
    );
    returnSelector.onChanged(EarningType.commission);
    await tester.pump();

    printTestLog(
      'return commission label → expected: present, actual: ${findLabel(LanguageLabelKeys.returnCommissionPercent).evaluate().length} match(es)',
    );
    expect(findLabel(LanguageLabelKeys.returnCommissionPercent), findsOneWidget);
    printTestLog(
      'plain commission label → expected: absent, actual: ${findLabel(LanguageLabelKeys.commissionPercent).evaluate().length} match(es)',
    );
    expect(findLabel(LanguageLabelKeys.commissionPercent), findsNothing);
  });
}
