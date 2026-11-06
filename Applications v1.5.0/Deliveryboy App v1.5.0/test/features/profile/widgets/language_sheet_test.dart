import 'package:bloc_test/bloc_test.dart';
import 'package:deliveryboy/commons/widgets/app_radio_option_tile.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/commons/widgets/shimmer_loading.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/localization/cubit/language_cubit.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/models/language_model.dart';
import 'package:deliveryboy/core/theme/app_theme.dart';
import 'package:deliveryboy/features/auth/cubit/update_fcm_token_cubit.dart';
import 'package:deliveryboy/features/profile/widgets/language_sheet.dart';
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

/// The sheet reads the language list from the app-wide `LanguageCubit` (mocked)
/// but creates its own `LanguageSelectCubit`, whose repository runs against the
/// ApiClient adapter seam.
void main() {
  late MockLanguageCubit languageCubit;
  late MockUpdateFcmTokenCubit fcmTokenCubit;
  late FakeApiAdapter adapter;

  final languages = [
    LanguageJsonData(id: '1', name: 'English', code: 'en', type: '0'),
    LanguageJsonData(id: '2', name: 'Arabic', code: 'ar', type: '1'),
  ];

  setUp(() async {
    // Selecting a language persists it to the settings box, and
    // DioInterceptor reads the auth token and language code per request.
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);

    languageCubit = MockLanguageCubit();
    fcmTokenCubit = MockUpdateFcmTokenCubit();

    when(() => languageCubit.loadLanguages()).thenAnswer((_) async {});
    when(() => languageCubit.updateSelectedId(any())).thenReturn(null);
    when(
      () => fcmTokenCubit.updateFcmToken(
        fcmToken: any(named: 'fcmToken'),
        platform: any(named: 'platform'),
        languageId: any(named: 'languageId'),
      ),
    ).thenAnswer((_) async {});
    whenListen(
      fcmTokenCubit,
      const Stream<UpdateFcmTokenState>.empty(),
      initialState: const UpdateFcmTokenInitial(),
    );

    // A rejected selection keeps the sheet in its failure branch — the success
    // branch persists four settings keys, and Hive writes started inside a
    // `testWidgets` body never complete (they would block `tearDown`'s
    // `box.close()` forever).
    adapter = FakeApiAdapter({
      ApiEndpoints.systemLanguages: (_) => {
        'status': 0,
        'message': 'Language unavailable',
      },
    });
    ApiClient().httpClientAdapter = adapter;
  });

  tearDown(() async {
    await Hive.box(settingsBox).close();
    await Hive.deleteBoxFromDisk(settingsBox);
    await HiveTestHelper.tearDown(authBox);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Finder appTextWith(String text) =>
      find.byWidgetPredicate((w) => w is AppText && w.text == text);

  /// Pass `settle: false` for states that render a [ShimmerRows] — its
  /// animation loops forever, so `pumpAndSettle` never returns.
  Future<void> openSheet(
    WidgetTester tester,
    LanguageState state, {
    bool settle = true,
  }) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    whenListen(
      languageCubit,
      const Stream<LanguageState>.empty(),
      initialState: state,
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<LanguageCubit>.value(value: languageCubit),
          BlocProvider<UpdateFcmTokenCubit>.value(value: fcmTokenCubit),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showLanguageSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets('lists every language with its code and marks the selected one', (
    tester,
  ) async {
    printTestDivider('LanguageSheet lists the languages');
    await openSheet(
      tester,
      LanguageLoaded(languages: languages, selectedId: '2'),
    );

    printTestLog(
      'title → expected: 1 "${LanguageLabelKeys.selectLanguage}", '
      'actual: ${appTextWith(LanguageLabelKeys.selectLanguage).evaluate().length}',
    );
    expect(appTextWith(LanguageLabelKeys.selectLanguage), findsOneWidget);
    final tiles = tester
        .widgetList<AppRadioOptionTile<String>>(
          find.byType(AppRadioOptionTile<String>),
        )
        .toList();
    printTestLog(
      'tiles → expected: 2, actual: ${tiles.length} (${tiles.map((t) => '${t.title}/${t.subtitle}')})',
    );
    expect(tiles.length, 2);
    expect(tiles.first.title, 'English');
    expect(tiles.first.subtitle, 'EN');
    printTestLog(
      'selected → expected: only Arabic, '
      'actual: ${tiles.map((t) => '${t.title}=${t.selected}')}',
    );
    expect(tiles.map((t) => t.selected), [false, true]);
  });

  testWidgets('shows a loader while the language list is being fetched', (
    tester,
  ) async {
    printTestDivider('LanguageSheet shows a loader while loading');
    await openSheet(tester, LanguageLoading(), settle: false);

    printTestLog(
      'loader → expected: 1, actual: ${find.byType(ShimmerRows).evaluate().length}',
    );
    expect(find.byType(ShimmerRows), findsOneWidget);
    printTestLog(
      'tiles → expected: 0, actual: ${find.byType(AppRadioOptionTile<String>).evaluate().length}',
    );
    expect(find.byType(AppRadioOptionTile<String>), findsNothing);
  });

  testWidgets('a failed language list shows the message with a retry', (
    tester,
  ) async {
    printTestDivider('LanguageSheet shows the list error with a retry');
    await openSheet(tester, LanguageError('Languages unavailable'));

    printTestLog(
      'message → expected: 1 "Languages unavailable", '
      'actual: ${appTextWith('Languages unavailable').evaluate().length}',
    );
    expect(appTextWith('Languages unavailable'), findsOneWidget);

    await tester.tap(appTextWith(LanguageLabelKeys.retry));
    await tester.pump();

    verify(() => languageCubit.loadLanguages()).called(1);
    printTestLog('retry → verified a reload');
  });

  testWidgets('tapping a language fetches it by id', (tester) async {
    printTestDivider('LanguageSheet fetches the tapped language by id');
    await openSheet(
      tester,
      LanguageLoaded(languages: languages, selectedId: '1'),
    );

    await tester.tap(appTextWith('Arabic'));
    await tester.pumpAndSettle();

    printTestLog(
      'requests → expected: [${ApiEndpoints.systemLanguages}], actual: ${adapter.requestedPaths}',
    );
    expect(adapter.requestedPaths, [ApiEndpoints.systemLanguages]);
    final query = adapter.requests.single.queryParameters;
    printTestLog('query → expected: id=2, system_type=2, actual: $query');
    expect(query[ApiParameters.id], '2');
    expect(query[ApiParameters.systemType], '2');
  });

  testWidgets('a failed selection shows the error instead of the list', (
    tester,
  ) async {
    printTestDivider('LanguageSheet surfaces a failed selection');
    await openSheet(
      tester,
      LanguageLoaded(languages: languages, selectedId: '1'),
    );

    await tester.tap(appTextWith('Arabic'));
    await tester.pumpAndSettle();

    printTestLog(
      'error → expected: 1 "Language unavailable", '
      'actual: ${appTextWith('Language unavailable').evaluate().length}',
    );
    expect(appTextWith('Language unavailable'), findsOneWidget);
    // The failure branch replaces the list rather than sitting under it.
    printTestLog(
      'tiles → expected: 0, actual: ${find.byType(AppRadioOptionTile<String>).evaluate().length}',
    );
    expect(find.byType(AppRadioOptionTile<String>), findsNothing);
    // Nothing was applied, so neither the app language nor the FCM token moved.
    verifyNever(() => languageCubit.updateSelectedId(any()));
    verifyNever(
      () => fcmTokenCubit.updateFcmToken(
        fcmToken: any(named: 'fcmToken'),
        platform: any(named: 'platform'),
        languageId: any(named: 'languageId'),
      ),
    );
    printTestLog('side effects → expected: none, verified');
  });

  testWidgets('the sheet closes once the FCM token update lands', (
    tester,
  ) async {
    printTestDivider('LanguageSheet closes on a completed FCM token update');
    // The sheet pops itself when UpdateFcmTokenCubit reports success — the
    // last step of applying a new language.
    whenListen(
      fcmTokenCubit,
      Stream<UpdateFcmTokenState>.value(const UpdateFcmTokenLoaded(())),
      initialState: const UpdateFcmTokenInitial(),
    );
    await openSheet(
      tester,
      LanguageLoaded(languages: languages, selectedId: '1'),
    );

    printTestLog(
      'sheet → expected: closed, '
      'actual: ${appTextWith(LanguageLabelKeys.selectLanguage).evaluate().length} title(s)',
    );
    expect(appTextWith(LanguageLabelKeys.selectLanguage), findsNothing);
  });
}
