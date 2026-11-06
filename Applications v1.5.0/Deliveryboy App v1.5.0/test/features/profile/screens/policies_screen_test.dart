import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/commons/models/country_settings_model.dart';
import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/commons/widgets/shimmer_loading.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/profile/screens/policies_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

/// One screen serving two documents: which title, which HTML field, and which
/// empty-state copy it uses all switch on [PoliciesType].
void main() {
  late MockCountrySettingsCubit settingsCubit;
  late MockConnectivityCubit connectivityCubit;
  late StreamController<ConnectivityState> connectivityStream;

  setUp(() {
    settingsCubit = MockCountrySettingsCubit();
    connectivityCubit = MockConnectivityCubit();
    connectivityStream = StreamController<ConnectivityState>.broadcast();

    when(
      () => settingsCubit.loadCountrySettings(force: any(named: 'force')),
    ).thenAnswer((_) async {});
  });

  tearDown(() => connectivityStream.close());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Finder appTextWith(String text) =>
      find.byWidgetPredicate((w) => w is AppText && w.text == text);

  CountrySettingsLoaded loadedWith({String? privacy, String? terms}) =>
      CountrySettingsLoaded(
        CountrySettings(
          status: 1,
          data: CountrySettingsData(
            privacyPolicy: privacy,
            termsConditions: terms,
          ),
        ),
      );

  Future<void> pumpScreen(
    WidgetTester tester, {
    required CountrySettingsState state,
    PoliciesType type = PoliciesType.privacyPolicy,
    ConnectivityState? connectivity,
  }) async {
    whenListen(
      settingsCubit,
      const Stream<CountrySettingsState>.empty(),
      initialState: state,
    );
    whenListen(
      connectivityCubit,
      connectivityStream.stream,
      initialState: connectivity ?? ConnectivityConnected(),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<CountrySettingsCubit>.value(value: settingsCubit),
          BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
        ],
        // PoliciesScreen builds its own AppScaffold.
        child: pumpTestWidget(
          PoliciesScreen(type: type),
          wrapInScaffold: false,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the privacy policy HTML under the privacy title', (
    tester,
  ) async {
    printTestDivider('PoliciesScreen renders the privacy policy HTML');
    await pumpScreen(
      tester,
      state: loadedWith(privacy: '<p>We keep your data safe.</p>'),
    );

    printTestLog(
      'title → expected: 1 "${LanguageLabelKeys.privacyPolicy}", '
      'actual: ${appTextWith(LanguageLabelKeys.privacyPolicy).evaluate().length}',
    );
    expect(appTextWith(LanguageLabelKeys.privacyPolicy), findsOneWidget);
    printTestLog(
      'html → expected: 1 HtmlWidget, actual: ${find.byType(HtmlWidget).evaluate().length}',
    );
    expect(find.byType(HtmlWidget), findsOneWidget);
    printTestLog(
      'html source → expected: the privacy field, '
      'actual: "${tester.widget<HtmlWidget>(find.byType(HtmlWidget)).html}"',
    );
    expect(
      tester.widget<HtmlWidget>(find.byType(HtmlWidget)).html,
      '<p>We keep your data safe.</p>',
    );
  });

  testWidgets('renders the terms HTML under the terms title', (tester) async {
    printTestDivider('PoliciesScreen renders the terms HTML');
    await pumpScreen(
      tester,
      type: PoliciesType.termsConditions,
      state: loadedWith(
        privacy: '<p>Privacy</p>',
        terms: '<p>Terms of use.</p>',
      ),
    );

    printTestLog(
      'title → expected: 1 "${LanguageLabelKeys.termsAndConditions}", '
      'actual: ${appTextWith(LanguageLabelKeys.termsAndConditions).evaluate().length}',
    );
    expect(appTextWith(LanguageLabelKeys.termsAndConditions), findsOneWidget);
    printTestLog(
      'html source → expected: the terms field, '
      'actual: "${tester.widget<HtmlWidget>(find.byType(HtmlWidget)).html}"',
    );
    expect(
      tester.widget<HtmlWidget>(find.byType(HtmlWidget)).html,
      '<p>Terms of use.</p>',
    );
  });

  testWidgets('shows the privacy-specific empty state when the field is empty', (
    tester,
  ) async {
    printTestDivider('PoliciesScreen shows the privacy empty state');
    await pumpScreen(tester, state: loadedWith(privacy: ''));

    printTestLog(
      'empty state → expected: 1, actual: ${find.byType(EmptyStateWidget).evaluate().length}',
    );
    expect(find.byType(EmptyStateWidget), findsOneWidget);
    printTestLog(
      'copy → expected: "${LanguageLabelKeys.privacyPolicyNotAvailable}", '
      'actual: ${appTextWith(LanguageLabelKeys.privacyPolicyNotAvailable).evaluate().length}',
    );
    expect(
      appTextWith(LanguageLabelKeys.privacyPolicyNotAvailable),
      findsOneWidget,
    );
  });

  testWidgets('shows the terms-specific empty state when the field is null', (
    tester,
  ) async {
    printTestDivider('PoliciesScreen shows the terms empty state');
    await pumpScreen(
      tester,
      type: PoliciesType.termsConditions,
      state: loadedWith(privacy: '<p>Privacy</p>'),
    );

    printTestLog(
      'copy → expected: "${LanguageLabelKeys.termsNotAvailable}", '
      'actual: ${appTextWith(LanguageLabelKeys.termsNotAvailable).evaluate().length}',
    );
    expect(appTextWith(LanguageLabelKeys.termsNotAvailable), findsOneWidget);
  });

  testWidgets('shows a loader while the settings are in flight', (tester) async {
    printTestDivider('PoliciesScreen shows a loader while loading');
    await pumpScreen(tester, state: CountrySettingsLoading());

    printTestLog(
      'loader → expected: 1, actual: ${find.byType(ShimmerRows).evaluate().length}',
    );
    expect(find.byType(ShimmerRows), findsOneWidget);
  });

  testWidgets('fetches the settings itself when they were never loaded', (
    tester,
  ) async {
    printTestDivider('PoliciesScreen fetches settings from the initial state');
    await pumpScreen(tester, state: CountrySettingsInitial());

    // The initial branch kicks off the fetch and shows a loader meanwhile.
    verify(() => settingsCubit.loadCountrySettings()).called(1);
    printTestLog('loadCountrySettings → verified once');
    printTestLog(
      'loader → expected: 1, actual: ${find.byType(ShimmerRows).evaluate().length}',
    );
    expect(find.byType(ShimmerRows), findsOneWidget);
  });

  testWidgets('shows the error message with a retry that forces a refetch', (
    tester,
  ) async {
    printTestDivider('PoliciesScreen shows the error state with a retry');
    await pumpScreen(tester, state: CountrySettingsError('Server unreachable'));

    printTestLog(
      'message → expected: 1 "Server unreachable", '
      'actual: ${appTextWith('Server unreachable').evaluate().length}',
    );
    expect(appTextWith('Server unreachable'), findsOneWidget);

    tester.widget<EmptyStateWidget>(find.byType(EmptyStateWidget)).onRetry!();
    await tester.pump();

    verify(() => settingsCubit.loadCountrySettings(force: true)).called(1);
    printTestLog('retry → verified a forced refetch');
  });

  testWidgets('keeps the app bar and swaps the body when offline', (
    tester,
  ) async {
    printTestDivider('PoliciesScreen shows the offline placeholder');
    await pumpScreen(
      tester,
      state: loadedWith(privacy: '<p>Privacy</p>'),
      connectivity: ConnectivityDisconnected(),
    );

    printTestLog(
      'offline placeholder → expected: 1, '
      'actual: ${find.byType(AppNoInternetFullScreen).evaluate().length}',
    );
    expect(find.byType(AppNoInternetFullScreen), findsOneWidget);
    printTestLog(
      'html → expected: 0, actual: ${find.byType(HtmlWidget).evaluate().length}',
    );
    expect(find.byType(HtmlWidget), findsNothing);
    // The back button has to survive, so the app bar stays put.
    printTestLog(
      'title → expected: still 1, '
      'actual: ${appTextWith(LanguageLabelKeys.privacyPolicy).evaluate().length}',
    );
    expect(appTextWith(LanguageLabelKeys.privacyPolicy), findsOneWidget);
  });

  testWidgets('refetches the settings when connectivity comes back', (
    tester,
  ) async {
    printTestDivider('PoliciesScreen refetches settings when back online');
    await pumpScreen(
      tester,
      state: loadedWith(privacy: '<p>Privacy</p>'),
      connectivity: ConnectivityDisconnected(),
    );

    connectivityStream.add(ConnectivityConnected());
    await tester.pump();

    verify(() => settingsCubit.loadCountrySettings()).called(1);
    printTestLog('loadCountrySettings after reconnect → verified once');
  });
}
