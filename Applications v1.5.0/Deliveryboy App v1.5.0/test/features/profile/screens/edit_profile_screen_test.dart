import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:deliveryboy/commons/cubit/countries_cubit.dart';
import 'package:deliveryboy/commons/models/countries_model.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_theme.dart';
import 'package:deliveryboy/features/auth/models/auth_model.dart';
import 'package:deliveryboy/features/profile/cubit/profile_detail_cubit.dart';
import 'package:deliveryboy/features/profile/cubit/profile_update_cubit.dart';
import 'package:deliveryboy/features/profile/screens/edit_profile_screen.dart';
import 'package:deliveryboy/features/profile/widgets/edit_profile_bottom_nav.dart';
import 'package:deliveryboy/features/profile/widgets/edit_profile_step1.dart';
import 'package:deliveryboy/features/profile/widgets/edit_profile_step2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_api_adapter.dart';
import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/test_logging.dart';

/// `EditProfileScreen` reads `ProfileDetailCubit`/`ProfileUpdateCubit`/
/// `CountriesCubit` from ambient providers (all app-global, per `main.dart`),
/// so those are mocked here. `ZonesCubit` is instantiated by the screen's
/// own state (`ZonesCubit()`), not injected — the real cubit and repository
/// run against the `ApiClient` adapter seam instead, same shape as
/// `withdrawal_sheet_test.dart`/`notification_screen_test.dart`.
void main() {
  late MockProfileDetailCubit profileCubit;
  late MockProfileUpdateCubit updateCubit;
  late MockCountriesCubit countriesCubit;
  late FakeApiAdapter adapter;
  late AuthModel profile;

  final india = CountriesData(
    id: 1,
    name: 'India',
    isDefault: 1,
    dialCode: '+91',
    minMobileLength: 10,
    maxMobileLength: 10,
  );
  final usa = CountriesData(
    id: 2,
    name: 'USA',
    isDefault: 0,
    dialCode: '+1',
    minMobileLength: 10,
    maxMobileLength: 10,
  );

  setUpAll(() {
    final json =
        jsonDecode(File('test/fixtures/auth/login_response.json').readAsStringSync())
            as Map<String, dynamic>;
    profile = AuthModel.fromJson(json);
  });

  setUp(() async {
    // DioInterceptor reads the token from AuthHiveBox and the active language
    // code from SettingsHiveBox on every request, so both boxes must be open
    // before the real ZonesCubit hits the ApiClient adapter seam.
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);

    profileCubit = MockProfileDetailCubit();
    updateCubit = MockProfileUpdateCubit();
    countriesCubit = MockCountriesCubit();

    adapter = FakeApiAdapter({
      ApiEndpoints.zones: (_) => {
        'status': 1,
        'message': 'ok',
        'data': [
          {'id': 2, 'name': 'North Zone'},
          {'id': 3, 'name': 'South Zone'},
        ],
      },
    });
    ApiClient().httpClientAdapter = adapter;

    whenListen(
      profileCubit,
      const Stream<ProfileDetailState>.empty(),
      initialState: ProfileDetailLoaded(profile),
    );
    whenListen(
      countriesCubit,
      const Stream<CountriesState>.empty(),
      initialState: CountriesLoaded(countries: [india, usa]),
    );
    whenListen(
      updateCubit,
      const Stream<ProfileUpdateState>.empty(),
      initialState: const ProfileUpdateInitial(),
    );
    when(() => updateCubit.updateProfile(
      name: any(named: 'name'),
      mobile: any(named: 'mobile'),
      email: any(named: 'email'),
      address: any(named: 'address'),
      dob: any(named: 'dob'),
      bankAccountNumber: any(named: 'bankAccountNumber'),
      bankName: any(named: 'bankName'),
      accountName: any(named: 'accountName'),
      ifscCode: any(named: 'ifscCode'),
      bonusType: any(named: 'bonusType'),
      bonusPercentage: any(named: 'bonusPercentage'),
      bonusMinAmount: any(named: 'bonusMinAmount'),
      bonusMaxAmount: any(named: 'bonusMaxAmount'),
      returnBonusType: any(named: 'returnBonusType'),
      returnBonusPercentage: any(named: 'returnBonusPercentage'),
      returnBonusMinAmount: any(named: 'returnBonusMinAmount'),
      returnBonusMaxAmount: any(named: 'returnBonusMaxAmount'),
      profileImagePath: any(named: 'profileImagePath'),
      nationalIdImagePath: any(named: 'nationalIdImagePath'),
      drivingLicenseImagePath: any(named: 'drivingLicenseImagePath'),
      countryId: any(named: 'countryId'),
      zoneId: any(named: 'zoneId'),
    )).thenAnswer((_) async {});
  });

  tearDown(() async {
    await Hive.box(settingsBox).close();
    await Hive.deleteBoxFromDisk(settingsBox);
    await HiveTestHelper.tearDown(authBox);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Finder appTextWith(String text) =>
      find.byWidgetPredicate((w) => w is AppText && w.text == text);

  Future<void> pumpScreen(WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 3200);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ProfileDetailCubit>.value(value: profileCubit),
          BlocProvider<ProfileUpdateCubit>.value(value: updateCubit),
          BlocProvider<CountriesCubit>.value(value: countriesCubit),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          // EditProfileScreen builds its own AppScaffold.
          home: const EditProfileScreen(),
        ),
      ),
    );
    await tester.pump();
    // Zone fetch is scheduled via a post-frame callback and resolved through
    // the FakeApiAdapter — settle both.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('prefills the country from the profile and auto-loads its zones', (
    tester,
  ) async {
    printTestDivider(
      'EditProfileScreen prefills country by profile.countryId and loads its zones',
    );
    await pumpScreen(tester);

    printTestLog('country → expected: "India" visible (countryId: 1 match)');
    expect(find.text('India'), findsOneWidget);
    printTestLog(
      'zone → expected: "North Zone" visible (zoneId: 2, prefilled once zones load)',
    );
    expect(find.text('North Zone'), findsOneWidget);
    printTestLog(
      'zones request → expected: [${ApiEndpoints.zones}], actual: ${adapter.requestedPaths}',
    );
    expect(adapter.requestedPaths, [ApiEndpoints.zones]);
  });

  testWidgets('falls back to the default country when the profile.countryId has no match', (
    tester,
  ) async {
    printTestDivider(
      'EditProfileScreen falls back to findDefaultCountry when countryId is unmatched',
    );
    final noMatchProfile = AuthModel.fromJson({
      ...jsonDecode(File('test/fixtures/auth/login_response.json').readAsStringSync())
          as Map<String, dynamic>,
    });
    noMatchProfile.data?.countryId = 999;
    whenListen(
      profileCubit,
      const Stream<ProfileDetailState>.empty(),
      initialState: ProfileDetailLoaded(noMatchProfile),
    );

    await pumpScreen(tester);

    // India is flagged isDefault: 1, so it wins over USA when countryId 999
    // matches nothing.
    printTestLog('country → expected: "India" visible (default flag wins)');
    expect(find.text('India'), findsOneWidget);
  });

  testWidgets('prefills the text fields and commission block from a commission-earning profile', (
    tester,
  ) async {
    printTestDivider(
      'EditProfileScreen prefills fields and shows the commission block for bonusType 1',
    );
    await pumpScreen(tester);

    printTestLog('name → expected: "Alex Johnson" visible');
    expect(find.text('Alex Johnson'), findsWidgets);
    printTestLog('email → expected: "alex@gmail.com" visible');
    expect(find.text('alex@gmail.com'), findsOneWidget);
    printTestLog('mobile → expected: "1234567890" visible');
    expect(find.text('1234567890'), findsOneWidget);
    printTestLog('address → expected: "Mumbai" visible');
    expect(find.text('Mumbai'), findsOneWidget);
    printTestLog(
      'commission label → expected: visible (bonus_type: 1 in the fixture)',
    );
    expect(appTextWith(LanguageLabelKeys.commissionPercent), findsOneWidget);
    printTestLog('commission value → expected: "10" visible');
    expect(find.text('10'), findsWidgets);
  });

  testWidgets('Next validates step 1 and advances to step 2', (tester) async {
    printTestDivider('EditProfileScreen Next advances from step 1 to step 2');
    await pumpScreen(tester);

    printTestLog('step 1 → expected: visible before Next');
    expect(find.byType(EditProfileStep1), findsOneWidget);

    await tester.tap(appTextWith(LanguageLabelKeys.next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    printTestLog('step 2 → expected: visible after Next');
    expect(find.byType(EditProfileStep2), findsOneWidget);
    expect(find.byType(EditProfileStep1), findsNothing);
  });

  testWidgets('Back returns from step 2 to step 1', (tester) async {
    printTestDivider('EditProfileScreen Back returns from step 2 to step 1');
    await pumpScreen(tester);
    await tester.tap(appTextWith(LanguageLabelKeys.next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(appTextWith(LanguageLabelKeys.back));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    printTestLog('step 1 → expected: visible again after Back');
    expect(find.byType(EditProfileStep1), findsOneWidget);
  });

  testWidgets('Cancel at step 1 pops the screen', (tester) async {
    printTestDivider('EditProfileScreen Cancel at step 1 pops the screen');
    GoogleFonts.config.allowRuntimeFetching = false;
    final observer = _RecordingNavigatorObserver();
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ProfileDetailCubit>.value(value: profileCubit),
          BlocProvider<ProfileUpdateCubit>.value(value: updateCubit),
          BlocProvider<CountriesCubit>.value(value: countriesCubit),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(appTextWith(LanguageLabelKeys.cancel));
    await tester.pump();
    // MaterialPageRoute's pop transition needs to fully settle before the
    // popped route's widget leaves the tree.
    await tester.pump(const Duration(milliseconds: 500));

    printTestLog('observer.pops → expected: 1, actual: ${observer.pops}');
    expect(observer.pops, 1);
    printTestLog(
      'edit screen → expected: popped, actual: ${find.byType(EditProfileScreen).evaluate().length}',
    );
    expect(find.byType(EditProfileScreen), findsNothing);
    printTestLog('open button → expected: visible again after pop');
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('Submit forwards the earning-type bonus flags as "1"/"0" strings', (
    tester,
  ) async {
    printTestDivider(
      'EditProfileScreen submit sends bonusType/returnBonusType as "1"/"0"',
    );
    await pumpScreen(tester);
    await tester.tap(appTextWith(LanguageLabelKeys.next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(appTextWith(LanguageLabelKeys.updateProfile));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final captured = verify(
      () => updateCubit.updateProfile(
        name: captureAny(named: 'name'),
        mobile: any(named: 'mobile'),
        email: any(named: 'email'),
        address: any(named: 'address'),
        dob: any(named: 'dob'),
        bankAccountNumber: any(named: 'bankAccountNumber'),
        bankName: any(named: 'bankName'),
        accountName: any(named: 'accountName'),
        ifscCode: any(named: 'ifscCode'),
        bonusType: captureAny(named: 'bonusType'),
        bonusPercentage: any(named: 'bonusPercentage'),
        bonusMinAmount: any(named: 'bonusMinAmount'),
        bonusMaxAmount: any(named: 'bonusMaxAmount'),
        returnBonusType: captureAny(named: 'returnBonusType'),
        returnBonusPercentage: any(named: 'returnBonusPercentage'),
        returnBonusMinAmount: any(named: 'returnBonusMinAmount'),
        returnBonusMaxAmount: any(named: 'returnBonusMaxAmount'),
        profileImagePath: any(named: 'profileImagePath'),
        nationalIdImagePath: any(named: 'nationalIdImagePath'),
        drivingLicenseImagePath: any(named: 'drivingLicenseImagePath'),
        countryId: any(named: 'countryId'),
        zoneId: any(named: 'zoneId'),
      ),
    ).captured;

    // fixture: bonus_type: 1 (commission), return_bonus_type: 1 (commission)
    printTestLog('name → expected: "Alex Johnson", actual: "${captured[0]}"');
    expect(captured[0], 'Alex Johnson');
    printTestLog('bonusType → expected: "1", actual: "${captured[1]}"');
    expect(captured[1], '1');
    printTestLog('returnBonusType → expected: "1", actual: "${captured[2]}"');
    expect(captured[2], '1');
  });

  testWidgets('Submit sends null for trimmed-empty optional fields, not empty strings', (
    tester,
  ) async {
    printTestDivider(
      'EditProfileScreen submit sends null (not "") for a cleared optional field',
    );
    await pumpScreen(tester);

    await tester.enterText(
      find.byWidgetPredicate((w) => w is TextField && w.controller?.text == 'alex@gmail.com'),
      '   ',
    );
    await tester.pump();

    await tester.tap(appTextWith(LanguageLabelKeys.next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(appTextWith(LanguageLabelKeys.updateProfile));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final captured = verify(
      () => updateCubit.updateProfile(
        name: any(named: 'name'),
        mobile: any(named: 'mobile'),
        email: captureAny(named: 'email'),
        address: any(named: 'address'),
        dob: any(named: 'dob'),
        bankAccountNumber: any(named: 'bankAccountNumber'),
        bankName: any(named: 'bankName'),
        accountName: any(named: 'accountName'),
        ifscCode: any(named: 'ifscCode'),
        bonusType: any(named: 'bonusType'),
        bonusPercentage: any(named: 'bonusPercentage'),
        bonusMinAmount: any(named: 'bonusMinAmount'),
        bonusMaxAmount: any(named: 'bonusMaxAmount'),
        returnBonusType: any(named: 'returnBonusType'),
        returnBonusPercentage: any(named: 'returnBonusPercentage'),
        returnBonusMinAmount: any(named: 'returnBonusMinAmount'),
        returnBonusMaxAmount: any(named: 'returnBonusMaxAmount'),
        profileImagePath: any(named: 'profileImagePath'),
        nationalIdImagePath: any(named: 'nationalIdImagePath'),
        drivingLicenseImagePath: any(named: 'drivingLicenseImagePath'),
        countryId: any(named: 'countryId'),
        zoneId: any(named: 'zoneId'),
      ),
    ).captured;

    printTestLog('email → expected: null, actual: ${captured.single}');
    expect(captured.single, isNull);
  });

  testWidgets('a failed update shows the error message and stays on the screen', (
    tester,
  ) async {
    printTestDivider('EditProfileScreen surfaces a failed update, no navigation');
    final updateStream = StreamController<ProfileUpdateState>();
    addTearDown(updateStream.close);
    whenListen(
      updateCubit,
      updateStream.stream,
      initialState: const ProfileUpdateInitial(),
    );
    await pumpScreen(tester);
    await tester.tap(appTextWith(LanguageLabelKeys.next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    updateStream.add(const ProfileUpdateError('Mobile already registered'));
    await tester.pump();

    printTestLog(
      'error message → expected: 1 "Mobile already registered", '
      'actual: ${find.text('Mobile already registered').evaluate().length}',
    );
    expect(find.text('Mobile already registered'), findsOneWidget);
    printTestLog('screen → expected: still EditProfileScreen, no pop');
    expect(find.byType(EditProfileScreen), findsOneWidget);
  });

  testWidgets('the submit button shows a spinner and disables while saving', (
    tester,
  ) async {
    printTestDivider('EditProfileScreen submit button reflects ProfileUpdateLoading');
    whenListen(
      updateCubit,
      const Stream<ProfileUpdateState>.empty(),
      initialState: const ProfileUpdateLoading(),
    );
    await pumpScreen(tester);
    await tester.tap(appTextWith(LanguageLabelKeys.next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final nav = tester.widget<EditProfileBottomNav>(
      find.byType(EditProfileBottomNav),
    );
    printTestLog('isLoading → expected: true, actual: ${nav.isLoading}');
    expect(nav.isLoading, isTrue);
  });
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  int pops = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops++;
  }
}
