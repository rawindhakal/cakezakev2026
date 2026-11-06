import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/cubit/settings_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/localization/cubit/language_cubit.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_theme.dart';
import 'package:deliveryboy/core/theme/cubit/theme_cubit.dart';
import 'package:deliveryboy/features/auth/cubit/update_fcm_token_cubit.dart';
import 'package:deliveryboy/features/profile/cubit/profile_detail_cubit.dart';
import 'package:deliveryboy/features/profile/screens/profile_screen.dart';
import 'package:deliveryboy/features/profile/widgets/profile_account_section.dart';
import 'package:deliveryboy/features/profile/widgets/profile_header.dart';
import 'package:deliveryboy/features/profile/widgets/profile_preferences_section.dart';
import 'package:deliveryboy/features/profile/widgets/profile_quick_help_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/test_logging.dart';

/// The profile tab itself owns very little: it refetches the profile whenever
/// connectivity comes back, swaps its body for the offline placeholder while
/// there's no connection, and stacks the three sections otherwise.
void main() {
  late MockProfileDetailCubit profileCubit;
  late MockConnectivityCubit connectivityCubit;
  late MockThemeCubit themeCubit;
  late MockLanguageCubit languageCubit;
  late MockSettingsCubit settingsCubit;
  late MockUpdateFcmTokenCubit fcmTokenCubit;
  late StreamController<ConnectivityState> connectivityStream;

  setUp(() async {
    // ProfileHeader reads the auth box; the preferences section reads the
    // settings box. Both boxes have to be open before the screen builds.
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);

    profileCubit = MockProfileDetailCubit();
    connectivityCubit = MockConnectivityCubit();
    themeCubit = MockThemeCubit();
    languageCubit = MockLanguageCubit();
    settingsCubit = MockSettingsCubit();
    fcmTokenCubit = MockUpdateFcmTokenCubit();
    connectivityStream = StreamController<ConnectivityState>.broadcast();

    when(() => profileCubit.loadProfile()).thenAnswer((_) async {});

    whenListen(
      profileCubit,
      const Stream<ProfileDetailState>.empty(),
      initialState: const ProfileDetailInitial(),
    );
    whenListen(
      themeCubit,
      const Stream<ThemeState>.empty(),
      initialState: const ThemeState(ThemeMode.light),
    );
    whenListen(
      languageCubit,
      const Stream<LanguageState>.empty(),
      initialState: LanguageInitial(),
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

  tearDown(() async {
    await connectivityStream.close();
    await Hive.box(settingsBox).close();
    await Hive.deleteBoxFromDisk(settingsBox);
    await HiveTestHelper.tearDown(authBox);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Finder appTextWith(String text) =>
      find.byWidgetPredicate((w) => w is AppText && w.text == text);

  Future<void> pumpScreen(
    WidgetTester tester, {
    ConnectivityState? initialConnectivity,
  }) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // The three sections stacked together are taller than the default 800×600
    // surface.
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1.0;

    whenListen(
      connectivityCubit,
      connectivityStream.stream,
      initialState: initialConnectivity ?? ConnectivityConnected(),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ProfileDetailCubit>.value(value: profileCubit),
          BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
          BlocProvider<ThemeCubit>.value(value: themeCubit),
          BlocProvider<LanguageCubit>.value(value: languageCubit),
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
          BlocProvider<UpdateFcmTokenCubit>.value(value: fcmTokenCubit),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          // ProfileScreen builds its own AppScaffold.
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the header and all three sections when online', (
    tester,
  ) async {
    printTestDivider('ProfileScreen renders header and sections when online');
    await pumpScreen(tester);

    printTestLog(
      'title → expected: 1 "${LanguageLabelKeys.myProfile}", '
      'actual: ${appTextWith(LanguageLabelKeys.myProfile).evaluate().length}',
    );
    expect(appTextWith(LanguageLabelKeys.myProfile), findsOneWidget);
    for (final type in [
      ProfileHeader,
      ProfilePreferencesSection,
      ProfileQuickHelpSection,
      ProfileAccountSection,
    ]) {
      printTestLog(
        '$type → expected: 1, actual: ${find.byType(type).evaluate().length}',
      );
      expect(find.byType(type), findsOneWidget);
    }
    printTestLog(
      'offline placeholder → expected: 0, '
      'actual: ${find.byType(AppNoInternetFullScreen).evaluate().length}',
    );
    expect(find.byType(AppNoInternetFullScreen), findsNothing);
  });

  testWidgets('swaps the body for the offline placeholder while disconnected', (
    tester,
  ) async {
    printTestDivider('ProfileScreen shows the offline placeholder');
    await pumpScreen(tester, initialConnectivity: ConnectivityDisconnected());

    printTestLog(
      'offline placeholder → expected: 1, '
      'actual: ${find.byType(AppNoInternetFullScreen).evaluate().length}',
    );
    expect(find.byType(AppNoInternetFullScreen), findsOneWidget);
    printTestLog(
      'sections → expected: 0, actual: ${find.byType(ProfileAccountSection).evaluate().length}',
    );
    expect(find.byType(ProfileAccountSection), findsNothing);
    // The app bar stays mounted so the screen keeps its identity offline.
    printTestLog(
      'title → expected: still 1, '
      'actual: ${appTextWith(LanguageLabelKeys.myProfile).evaluate().length}',
    );
    expect(appTextWith(LanguageLabelKeys.myProfile), findsOneWidget);
  });

  testWidgets('refetches the profile when connectivity comes back', (
    tester,
  ) async {
    printTestDivider('ProfileScreen refetches the profile when back online');
    await pumpScreen(tester, initialConnectivity: ConnectivityDisconnected());

    // The listener only fires on a transition, so nothing is fetched yet.
    verifyNever(() => profileCubit.loadProfile());
    printTestLog('loadProfile while offline → expected: never called');

    connectivityStream.add(ConnectivityConnected());
    await tester.pump();

    verify(() => profileCubit.loadProfile()).called(1);
    printTestLog('loadProfile after reconnect → verified once');
  });

  testWidgets('the offline retry callback refetches the profile', (tester) async {
    printTestDivider('ProfileScreen offline retry refetches the profile');
    await pumpScreen(tester, initialConnectivity: ConnectivityDisconnected());

    // The button itself first polls the platform through
    // `ConnectivityService().recheck()`, which has no implementation under
    // `flutter test` — so the wiring is checked by invoking the callback the
    // screen handed the widget.
    final offline = tester.widget<AppNoInternetFullScreen>(
      find.byType(AppNoInternetFullScreen),
    );
    offline.onRetry!();
    await tester.pump();

    verify(() => profileCubit.loadProfile()).called(1);
    printTestLog('loadProfile after retry → verified once');
  });
}
