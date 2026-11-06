import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:deliveryboy/commons/cubit/countries_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_button.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/features/auth/screens/sign_up_screen.dart';
import 'package:deliveryboy/features/auth/widgets/register_form.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockCountriesCubit countriesCubit;

  // The register form's password checklist reads SettingsHiveBox, and the
  // screen creates its own SignUpCubit -> AuthRepository, so a real box has
  // to exist even though nothing here asserts on settings.
  setUp(() async {
    await HiveTestHelper.setUp(settingsBox);
    countriesCubit = MockCountriesCubit();
    whenListen(
      countriesCubit,
      const Stream<CountriesState>.empty(),
      initialState: CountriesLoaded(countries: const []),
    );
  });

  tearDown(() => HiveTestHelper.tearDown(settingsBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpScreen(WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MultiBlocProvider(
        // SignUpScreen creates its own SignUpCubit and ZonesCubit but reads
        // CountriesCubit from above it.
        providers: [BlocProvider<CountriesCubit>.value(value: countriesCubit)],
        // SignUpScreen builds its own AppScaffold.
        child: pumpTestWidget(const SignUpScreen(), wrapInScaffold: false),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the registration form and a submit button', (
    tester,
  ) async {
    printTestDivider('renders the registration form and a submit button');
    await pumpScreen(tester);

    printTestLog('RegisterForm → expected: 1, actual: ${find.byType(RegisterForm).evaluate().length}');
    expect(find.byType(RegisterForm), findsOneWidget);
    printTestLog('AppButton → expected: 1, actual: ${find.byType(AppButton).evaluate().length}');
    expect(find.byType(AppButton), findsOneWidget);
  });

  testWidgets('the submit button is not in its loading state initially', (
    tester,
  ) async {
    printTestDivider('the submit button is not in its loading state initially');
    await pumpScreen(tester);

    final button = tester.widget<AppButton>(find.byType(AppButton));
    printTestLog('AppButton.isLoading → expected: false, actual: ${button.isLoading}');
    expect(button.isLoading, isFalse);
  });

  testWidgets('tapping submit on an empty form surfaces validation instead of navigating away', (
    tester,
  ) async {
    printTestDivider(
      'tapping submit on an empty form surfaces validation instead of navigating away',
    );
    await pumpScreen(tester);

    await tester.tap(find.byType(AppButton));
    await tester.pump();

    // The screen's button delegates to RegisterFormState.submit(), which
    // validates locally before ever reaching the cubit — so the form stays.
    printTestLog('RegisterForm → expected: still 1, actual: ${find.byType(RegisterForm).evaluate().length}');
    expect(find.byType(RegisterForm), findsOneWidget);
    final button = tester.widget<AppButton>(find.byType(AppButton));
    printTestLog('AppButton.isLoading → expected: false, actual: ${button.isLoading}');
    expect(button.isLoading, isFalse);
  });
}
