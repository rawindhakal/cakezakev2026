import 'package:bloc_test/bloc_test.dart';
import 'package:deliveryboy/commons/cubit/settings_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/localization/cubit/language_cubit.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/models/language_model.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/core/theme/app_theme.dart';
import 'package:deliveryboy/core/theme/cubit/theme_cubit.dart';
import 'package:deliveryboy/features/auth/cubit/update_fcm_token_cubit.dart';
import 'package:deliveryboy/features/profile/screens/policies_screen.dart';
import 'package:deliveryboy/features/profile/widgets/profile_account_section.dart';
import 'package:deliveryboy/features/profile/widgets/profile_menu_widgets.dart';
import 'package:deliveryboy/features/profile/widgets/profile_preferences_section.dart';
import 'package:deliveryboy/features/profile/widgets/profile_quick_help_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/test_logging.dart';

/// The three sections that make up the profile tab's body. Each one is a thin
/// wrapper over [ProfileMenuCard], so these tests check the labels, the
/// trailing values, and where each row leads — the card's own rendering is
/// covered by `profile_menu_widgets_test.dart`.
void main() {
  late MockThemeCubit themeCubit;
  late MockLanguageCubit languageCubit;
  late MockSettingsCubit settingsCubit;
  late MockUpdateFcmTokenCubit fcmTokenCubit;
  late List<RouteSettings> pushed;

  setUp(() async {
    // The preferences section falls back to the language code stored in
    // SettingsHiveBox whenever the language list isn't loaded.
    await HiveTestHelper.setUp(settingsBox);

    themeCubit = MockThemeCubit();
    languageCubit = MockLanguageCubit();
    settingsCubit = MockSettingsCubit();
    fcmTokenCubit = MockUpdateFcmTokenCubit();
    pushed = [];

    whenListen(
      themeCubit,
      const Stream<ThemeState>.empty(),
      initialState: const ThemeState(ThemeMode.light),
    );
    whenListen(
      settingsCubit,
      const Stream<SettingsState>.empty(),
      initialState: SettingsInitial(),
    );
    whenListen(
      fcmTokenCubit,
      const Stream<UpdateFcmTokenState>.empty(),
      initialState: const UpdateFcmTokenInitial(),
    );
  });

  tearDown(() => HiveTestHelper.tearDown(settingsBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Finder appTextWith(String text) =>
      find.byWidgetPredicate((w) => w is AppText && w.text == text);

  Future<void> pumpSection(WidgetTester tester, Widget section) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ThemeCubit>.value(value: themeCubit),
          BlocProvider<LanguageCubit>.value(value: languageCubit),
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
          BlocProvider<UpdateFcmTokenCubit>.value(value: fcmTokenCubit),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(body: SingleChildScrollView(child: section)),
          onGenerateRoute: (settings) {
            pushed.add(settings);
            return MaterialPageRoute(
              builder: (_) => Scaffold(body: Text('route:${settings.name}')),
              settings: settings,
            );
          },
        ),
      ),
    );
    await tester.pump();
  }

  group('ProfilePreferencesSection', () {
    void stubLanguages(LanguageState state) => whenListen(
      languageCubit,
      const Stream<LanguageState>.empty(),
      initialState: state,
    );

    testWidgets('shows the selected language as "Name (CODE)"', (tester) async {
      printTestDivider('ProfilePreferencesSection shows "Name (CODE)"');
      stubLanguages(
        LanguageLoaded(
          languages: [
            LanguageJsonData(id: '1', name: 'English', code: 'en'),
            LanguageJsonData(id: '2', name: 'Arabic', code: 'ar'),
          ],
          selectedId: '2',
        ),
      );
      await pumpSection(tester, const ProfilePreferencesSection());

      printTestLog(
        'trailing → expected: 1 "Arabic (AR)", actual: ${appTextWith('Arabic (AR)').evaluate().length}',
      );
      expect(appTextWith('Arabic (AR)'), findsOneWidget);
      printTestLog(
        'row label → expected: 1 "${LanguageLabelKeys.changeLanguage}", '
        'actual: ${appTextWith(LanguageLabelKeys.changeLanguage).evaluate().length}',
      );
      expect(appTextWith(LanguageLabelKeys.changeLanguage), findsOneWidget);
    });

    testWidgets('falls back to the stored code when the list has no match', (
      tester,
    ) async {
      printTestDivider(
        'ProfilePreferencesSection falls back to the stored language code',
      );
      // A selected ID that isn't in the list (e.g. removed in the admin panel)
      // leaves only SettingsHiveBox's code to show.
      await tester.runAsync(() => Hive.box(settingsBox).put(kLanguageCode, 'fr'));
      stubLanguages(
        LanguageLoaded(
          languages: [LanguageJsonData(id: '1', name: 'English', code: 'en')],
          selectedId: '99',
        ),
      );
      await pumpSection(tester, const ProfilePreferencesSection());

      printTestLog(
        'trailing → expected: 1 "FR", actual: ${appTextWith('FR').evaluate().length}',
      );
      expect(appTextWith('FR'), findsOneWidget);
    });

    testWidgets('shows the stored code while the language list is loading', (
      tester,
    ) async {
      printTestDivider(
        'ProfilePreferencesSection shows the stored code while loading',
      );
      await tester.runAsync(() => Hive.box(settingsBox).put(kLanguageCode, 'de'));
      stubLanguages(LanguageLoading());
      await pumpSection(tester, const ProfilePreferencesSection());

      printTestLog(
        'trailing → expected: 1 "DE", actual: ${appTextWith('DE').evaluate().length}',
      );
      expect(appTextWith('DE'), findsOneWidget);
    });

    testWidgets('tapping the row opens the language sheet', (tester) async {
      printTestDivider('ProfilePreferencesSection opens the language sheet');
      stubLanguages(
        LanguageLoaded(
          languages: [LanguageJsonData(id: '1', name: 'English', code: 'en')],
          selectedId: '1',
        ),
      );
      await pumpSection(tester, const ProfilePreferencesSection());

      await tester.tap(appTextWith(LanguageLabelKeys.changeLanguage));
      await tester.pumpAndSettle();

      printTestLog(
        'sheet title → expected: 1 "${LanguageLabelKeys.selectLanguage}", '
        'actual: ${appTextWith(LanguageLabelKeys.selectLanguage).evaluate().length}',
      );
      expect(appTextWith(LanguageLabelKeys.selectLanguage), findsOneWidget);
      // Close it again so the sheet's route doesn't outlive the test.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('ProfileQuickHelpSection', () {
    testWidgets('lists support chat, rate us, and a collapsed policies group', (
      tester,
    ) async {
      printTestDivider('ProfileQuickHelpSection lists its rows');
      await pumpSection(tester, const ProfileQuickHelpSection());

      for (final key in [
        LanguageLabelKeys.chatWithSupport,
        LanguageLabelKeys.rateUs,
      ]) {
        printTestLog(
          'row → expected: 1 "$key", actual: ${appTextWith(key).evaluate().length}',
        );
        expect(appTextWith(key), findsOneWidget);
      }
      // "Help & policies" is both the group's title and its header row.
      printTestLog(
        'policies group → expected: 2 "${LanguageLabelKeys.helpPolicies}", '
        'actual: ${appTextWith(LanguageLabelKeys.helpPolicies).evaluate().length}',
      );
      expect(appTextWith(LanguageLabelKeys.helpPolicies), findsNWidgets(2));
      // The policy rows sit inside the group's AnimatedCrossFade, which keeps
      // both branches in the tree — collapsed means `showFirst`, not absent.
      final crossFade = tester.widget<AnimatedCrossFade>(
        find.byType(AnimatedCrossFade),
      );
      printTestLog(
        'policies group → expected: showFirst (collapsed), actual: ${crossFade.crossFadeState}',
      );
      expect(crossFade.crossFadeState, CrossFadeState.showFirst);
    });

    testWidgets('the privacy policy row pushes the policies route with its type', (
      tester,
    ) async {
      printTestDivider('ProfileQuickHelpSection pushes the privacy policy route');
      await pumpSection(tester, const ProfileQuickHelpSection());

      await tester.tap(appTextWith(LanguageLabelKeys.helpPolicies).last);
      await tester.pumpAndSettle();
      await tester.tap(appTextWith(LanguageLabelKeys.privacyPolicy));
      await tester.pump();

      printTestLog(
        'pushed → expected: [${RouteNames.policies}], actual: ${pushed.map((r) => r.name)}',
      );
      expect(pushed.map((r) => r.name), [RouteNames.policies]);
      printTestLog(
        'argument → expected: PoliciesType.privacyPolicy, actual: ${pushed.single.arguments}',
      );
      expect(pushed.single.arguments, PoliciesType.privacyPolicy);
    });

    testWidgets('the terms row pushes the policies route with its own type', (
      tester,
    ) async {
      printTestDivider('ProfileQuickHelpSection pushes the terms route');
      await pumpSection(tester, const ProfileQuickHelpSection());

      await tester.tap(appTextWith(LanguageLabelKeys.helpPolicies).last);
      await tester.pumpAndSettle();
      await tester.tap(appTextWith(LanguageLabelKeys.termsAndConditions));
      await tester.pump();

      printTestLog(
        'argument → expected: PoliciesType.termsConditions, actual: ${pushed.single.arguments}',
      );
      expect(pushed.single.arguments, PoliciesType.termsConditions);
    });
  });

  group('ProfileAccountSection', () {
    testWidgets('lists settings and logout under one card', (tester) async {
      printTestDivider('ProfileAccountSection lists settings and logout');
      await pumpSection(tester, const ProfileAccountSection());

      printTestLog(
        'card → expected: 1, actual: ${find.byType(ProfileMenuCard).evaluate().length}',
      );
      expect(find.byType(ProfileMenuCard), findsOneWidget);
      for (final key in [
        LanguageLabelKeys.account,
        LanguageLabelKeys.settings,
        LanguageLabelKeys.logout,
      ]) {
        printTestLog(
          'row → expected: 1 "$key", actual: ${appTextWith(key).evaluate().length}',
        );
        expect(appTextWith(key), findsOneWidget);
      }
    });

    testWidgets('the settings row pushes the account-settings route', (
      tester,
    ) async {
      printTestDivider('ProfileAccountSection pushes the account-settings route');
      await pumpSection(tester, const ProfileAccountSection());

      await tester.tap(appTextWith(LanguageLabelKeys.settings));
      await tester.pump();

      printTestLog(
        'pushed → expected: [${RouteNames.accountSettings}], actual: ${pushed.map((r) => r.name)}',
      );
      expect(pushed.map((r) => r.name), [RouteNames.accountSettings]);
    });
  });
}
