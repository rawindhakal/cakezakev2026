import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/cubit/settings_cubit.dart';
import 'package:deliveryboy/commons/models/app_settings_model.dart';
import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/localization/cubit/language_cubit.dart';
import 'package:deliveryboy/core/localization/cubit/localization_cubit.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/core/theme/app_theme.dart';
import 'package:deliveryboy/features/splash/screens/splash_screen.dart';
import 'package:deliveryboy/features/splash/widget/splash_visual.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/test_logging.dart';

/// SplashScreen is a router with a logo on it: three listeners chained
/// settings → languages → translations, and exactly one navigation at the
/// end of the chain. Every cubit it touches is read via `context.read`, so
/// all four are mocked and the emissions are driven by hand.
///
/// Not coverable here: the force-update dialog. `ForceUpdateHelper.getStatus`
/// short-circuits to `UpdateStatus.none` on anything that isn't Android or
/// iOS, and `flutter test` runs on the host — so the splash chain always
/// continues straight to `_loadLanguages`. The dialog's own branches belong
/// to a `ForceUpdateDialog` test.
void main() {
  late MockSettingsCubit settingsCubit;
  late MockLanguageCubit languageCubit;
  late MockLocalizationCubit localizationCubit;
  late MockConnectivityCubit connectivityCubit;

  late StreamController<SettingsState> settingsStream;
  late StreamController<LanguageState> languageStream;
  late StreamController<LocalizationState> localizationStream;
  late StreamController<ConnectivityState> connectivityStream;

  /// Route names pushed onto the host navigator, in order, with whatever
  /// arguments came along.
  late List<RouteSettings> pushed;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    // ForceUpdateHelper reads the installed version through PackageInfo; a
    // real platform call would go to an unimplemented channel here.
    PackageInfo.setMockInitialValues(
      appName: 'deliveryboy',
      packageName: 'com.test.deliveryboy',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  setUp(() async {
    // SplashScreen's _navigate reads AuthHiveBox.isLoggedIn.
    await HiveTestHelper.setUp(authBox);

    settingsCubit = MockSettingsCubit();
    languageCubit = MockLanguageCubit();
    localizationCubit = MockLocalizationCubit();
    connectivityCubit = MockConnectivityCubit();

    settingsStream = StreamController<SettingsState>.broadcast();
    languageStream = StreamController<LanguageState>.broadcast();
    localizationStream = StreamController<LocalizationState>.broadcast();
    connectivityStream = StreamController<ConnectivityState>.broadcast();

    when(() => settingsCubit.loadSettings()).thenAnswer((_) async {});
    when(() => languageCubit.loadLanguages()).thenAnswer((_) async {});
    when(() => localizationCubit.loadFromCache()).thenAnswer((_) async {});
    when(
      () => localizationCubit.loadForLanguage(any()),
    ).thenAnswer((_) async {});

    whenListen(
      settingsCubit,
      settingsStream.stream,
      initialState: SettingsInitial(),
    );
    whenListen(
      languageCubit,
      languageStream.stream,
      initialState: LanguageInitial(),
    );
    whenListen(
      localizationCubit,
      localizationStream.stream,
      initialState: LocalizationInitial(),
    );
    whenListen(
      connectivityCubit,
      connectivityStream.stream,
      initialState: ConnectivityConnected(),
    );

    pushed = [];
  });

  tearDown(() async {
    await settingsStream.close();
    await languageStream.close();
    await localizationStream.close();
    await connectivityStream.close();
    await HiveTestHelper.tearDown(authBox);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  AppSettings settingsWith(Map<String, dynamic> data) =>
      AppSettings(data: AppSettingsData.fromJson(data));

  Future<void> pumpSplash(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
          BlocProvider<LanguageCubit>.value(value: languageCubit),
          BlocProvider<LocalizationCubit>.value(value: localizationCubit),
          BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const SplashScreen(),
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
    // The splash logo sits over an endlessly repeating UltraLoader, so pumps
    // stay bounded here — pumpAndSettle would never return.
    await tester.pump(const Duration(milliseconds: 16));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  /// Pushes [state] through the settings listener and lets the async
  /// force-update check (a real `await`) resolve before returning.
  Future<void> emitSettings(WidgetTester tester, SettingsState state) async {
    settingsStream.add(state);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('fetches settings on first build', (tester) async {
    printTestDivider('SplashScreen fetches settings on first build');
    await pumpSplash(tester);

    verify(() => settingsCubit.loadSettings()).called(1);
    printTestLog('loadSettings → verified');
    printTestLog(
      'visual → expected: 1, actual: ${find.byType(SplashVisual).evaluate().length}',
    );
    expect(find.byType(SplashVisual), findsOneWidget);
  });

  testWidgets('loaded settings continue on to the language list', (
    tester,
  ) async {
    printTestDivider('SplashScreen loaded settings continue to the language list');
    await pumpSplash(tester);

    await emitSettings(
      tester,
      SettingsLoaded(settingsWith({'app_mode_delivery_boy': '0'})),
    );

    verify(() => languageCubit.loadLanguages()).called(1);
    printTestLog('loadLanguages → verified');
    printTestLog('pushed → expected: [], actual: ${pushed.map((r) => r.name)}');
    expect(pushed, isEmpty);
  });

  testWidgets('settings with no data block still continue to the languages', (
    tester,
  ) async {
    printTestDivider('SplashScreen settings with no data still load languages');
    await pumpSplash(tester);

    await emitSettings(tester, SettingsLoaded(AppSettings()));

    verify(() => languageCubit.loadLanguages()).called(1);
    printTestLog('loadLanguages → verified');
  });

  testWidgets('maintenance mode routes straight to the maintenance screen', (
    tester,
  ) async {
    printTestDivider('SplashScreen maintenance mode routes to maintenance');
    await pumpSplash(tester);

    await emitSettings(
      tester,
      SettingsLoaded(
        settingsWith({
          'app_mode_delivery_boy': '1',
          'app_mode_delivery_boy_remark': 'Back at 6pm IST',
        }),
      ),
    );

    printTestLog(
      'pushed → expected: [${RouteNames.maintenance}], '
      'actual: ${pushed.map((r) => r.name)}',
    );
    expect(pushed.map((r) => r.name), [RouteNames.maintenance]);
    printTestLog(
      'argument → expected: "Back at 6pm IST", actual: ${pushed.single.arguments}',
    );
    expect(pushed.single.arguments, 'Back at 6pm IST');
    // The chain stops there — no point loading translations for a screen the
    // user can't leave.
    verifyNever(() => languageCubit.loadLanguages());
    printTestLog('loadLanguages → expected: never called');
  });

  testWidgets('a settings failure falls back to cached translations', (
    tester,
  ) async {
    printTestDivider('SplashScreen a settings failure falls back to cache');
    await pumpSplash(tester);

    await emitSettings(tester, SettingsError('Settings unavailable'));

    verify(() => localizationCubit.loadFromCache()).called(1);
    printTestLog('loadFromCache → verified');
    verifyNever(() => languageCubit.loadLanguages());
  });

  testWidgets('a selected language loads that language\'s translations', (
    tester,
  ) async {
    printTestDivider('SplashScreen a selected language loads its translations');
    await pumpSplash(tester);

    languageStream.add(LanguageLoaded(languages: const [], selectedId: '7'));
    await tester.pump();

    verify(() => localizationCubit.loadForLanguage('7')).called(1);
    printTestLog('loadForLanguage("7") → verified');
  });

  testWidgets('no selected language falls back to cached translations', (
    tester,
  ) async {
    printTestDivider('SplashScreen no selected language falls back to cache');
    await pumpSplash(tester);

    languageStream.add(LanguageLoaded(languages: const [], selectedId: null));
    await tester.pump();

    verify(() => localizationCubit.loadFromCache()).called(1);
    printTestLog('loadFromCache → verified');
    verifyNever(() => localizationCubit.loadForLanguage(any()));
  });

  testWidgets('a language-list failure falls back to cached translations', (
    tester,
  ) async {
    printTestDivider('SplashScreen a language-list failure falls back to cache');
    await pumpSplash(tester);

    languageStream.add(LanguageError('Languages unavailable'));
    await tester.pump();

    verify(() => localizationCubit.loadFromCache()).called(1);
    printTestLog('loadFromCache → verified');
  });

  testWidgets('a logged-out session lands on the login screen', (tester) async {
    printTestDivider('SplashScreen a logged-out session lands on login');
    await pumpSplash(tester);

    localizationStream.add(LocalizationLoaded('7'));
    await tester.pump();

    printTestLog(
      'pushed → expected: [${RouteNames.login}], actual: ${pushed.map((r) => r.name)}',
    );
    expect(pushed.map((r) => r.name), [RouteNames.login]);
  });

  testWidgets('translations failing still lets the app in', (tester) async {
    printTestDivider('SplashScreen translations failing still lets the app in');
    await pumpSplash(tester);

    localizationStream.add(LocalizationError('No translations'));
    await tester.pump();

    // The app is usable with raw keys; a stuck splash screen is not.
    printTestLog(
      'pushed → expected: [${RouteNames.login}], actual: ${pushed.map((r) => r.name)}',
    );
    expect(pushed.map((r) => r.name), [RouteNames.login]);
  });

  testWidgets('navigates exactly once, however often the chain re-fires', (
    tester,
  ) async {
    printTestDivider('SplashScreen navigates exactly once');
    await pumpSplash(tester);

    localizationStream.add(LocalizationLoaded('7'));
    await tester.pump();
    localizationStream.add(LocalizationLoaded('8'));
    await tester.pump();
    localizationStream.add(LocalizationError('No translations'));
    await tester.pump();

    // A settings reload on reconnect re-runs the whole chain; a second
    // pushReplacement would tear down the screen that just replaced splash.
    printTestLog('pushed → expected: 1, actual: ${pushed.length}');
    expect(pushed.length, 1);
  });

  testWidgets('maintenance also counts as the one navigation', (tester) async {
    printTestDivider('SplashScreen maintenance also counts as the one navigation');
    await pumpSplash(tester);

    await emitSettings(
      tester,
      SettingsLoaded(settingsWith({'app_mode_delivery_boy': '1'})),
    );
    localizationStream.add(LocalizationLoaded('7'));
    await tester.pump();

    printTestLog(
      'pushed → expected: [${RouteNames.maintenance}], '
      'actual: ${pushed.map((r) => r.name)}',
    );
    expect(pushed.map((r) => r.name), [RouteNames.maintenance]);
  });

  testWidgets('shows the offline overlay while disconnected', (tester) async {
    printTestDivider('SplashScreen shows the offline overlay while disconnected');
    await pumpSplash(tester);

    connectivityStream.add(ConnectivityDisconnected());
    await tester.pump();

    printTestLog(
      'offline overlay → expected: 1, '
      'actual: ${find.byType(AppNoInternetFullScreen).evaluate().length}',
    );
    expect(find.byType(AppNoInternetFullScreen), findsOneWidget);
  });

  testWidgets('reconnecting retries the settings fetch', (tester) async {
    printTestDivider('SplashScreen reconnecting retries the settings fetch');
    await pumpSplash(tester);

    connectivityStream.add(ConnectivityConnected());
    await tester.pump();

    // Once from initState, once from the reconnect.
    verify(() => settingsCubit.loadSettings()).called(2);
    printTestLog('loadSettings → verified twice');
  });

  testWidgets('reconnecting does not refetch settings already loaded', (
    tester,
  ) async {
    printTestDivider('SplashScreen reconnecting does not refetch loaded settings');
    await pumpSplash(tester);

    when(
      () => settingsCubit.state,
    ).thenReturn(SettingsLoaded(settingsWith(const {})));
    connectivityStream.add(ConnectivityConnected());
    await tester.pump();

    verify(() => settingsCubit.loadSettings()).called(1);
    printTestLog('loadSettings → verified once (initState only)');
  });

  group('with a stored session', () {
    setUp(() => Hive.box(authBox).put(kIsLoggedIn, true));

    testWidgets('a logged-in session lands on the main screen', (tester) async {
      printTestDivider('SplashScreen a logged-in session lands on main');
      await pumpSplash(tester);

      localizationStream.add(LocalizationLoaded('7'));
      await tester.pump();

      printTestLog(
        'pushed → expected: [${RouteNames.main}], actual: ${pushed.map((r) => r.name)}',
      );
      expect(pushed.map((r) => r.name), [RouteNames.main]);
    });
  });
}
