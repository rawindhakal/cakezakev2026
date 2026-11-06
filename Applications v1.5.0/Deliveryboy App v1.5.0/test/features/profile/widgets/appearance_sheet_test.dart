import 'package:bloc_test/bloc_test.dart';
import 'package:deliveryboy/commons/widgets/app_radio_option_tile.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_theme.dart';
import 'package:deliveryboy/core/theme/cubit/theme_cubit.dart';
import 'package:deliveryboy/features/profile/widgets/appearance_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_cubits.dart';
import '../../../helpers/test_logging.dart';

/// The appearance sheet is three radio tiles over `ThemeCubit`. The cubit is
/// mocked because the real one persists to `SettingsHiveBox` — a fire-and-forget
/// Hive write, which never completes inside a `testWidgets` body.
void main() {
  late MockThemeCubit themeCubit;

  setUp(() {
    themeCubit = MockThemeCubit();
    when(() => themeCubit.setLight()).thenReturn(null);
    when(() => themeCubit.setDark()).thenReturn(null);
    when(() => themeCubit.setSystem()).thenReturn(null);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Finder appTextWith(String text) =>
      find.byWidgetPredicate((w) => w is AppText && w.text == text);

  Future<void> openSheet(WidgetTester tester, ThemeMode mode) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    whenListen(
      themeCubit,
      const Stream<ThemeState>.empty(),
      initialState: ThemeState(mode),
    );

    await tester.pumpWidget(
      BlocProvider<ThemeCubit>.value(
        value: themeCubit,
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAppearanceSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets('offers system, light and dark, with the active one selected', (
    tester,
  ) async {
    printTestDivider('AppearanceSheet offers the three theme modes');
    await openSheet(tester, ThemeMode.dark);

    printTestLog(
      'title → expected: 1 "${LanguageLabelKeys.appearanceLabel}", '
      'actual: ${appTextWith(LanguageLabelKeys.appearanceLabel).evaluate().length}',
    );
    expect(appTextWith(LanguageLabelKeys.appearanceLabel), findsOneWidget);

    final tiles = tester
        .widgetList<AppRadioOptionTile<ThemeMode>>(
          find.byType(AppRadioOptionTile<ThemeMode>),
        )
        .toList();
    printTestLog(
      'options → expected: [system, light, dark], actual: ${tiles.map((t) => t.value)}',
    );
    expect(tiles.map((t) => t.value), [
      ThemeMode.system,
      ThemeMode.light,
      ThemeMode.dark,
    ]);
    printTestLog(
      'selected → expected: dark only, actual: ${tiles.map((t) => t.selected)}',
    );
    expect(tiles.map((t) => t.selected), [false, false, true]);
  });

  testWidgets('picking light applies it and closes the sheet', (tester) async {
    printTestDivider('AppearanceSheet applies the light theme');
    await openSheet(tester, ThemeMode.system);

    await tester.tap(appTextWith(LanguageLabelKeys.light));
    await tester.pumpAndSettle();

    verify(() => themeCubit.setLight()).called(1);
    verifyNever(() => themeCubit.setDark());
    printTestLog('setLight → verified once, setDark never');
    printTestLog(
      'sheet → expected: closed, '
      'actual: ${find.byType(AppRadioOptionTile<ThemeMode>).evaluate().length} tiles',
    );
    expect(find.byType(AppRadioOptionTile<ThemeMode>), findsNothing);
  });

  testWidgets('picking dark applies it', (tester) async {
    printTestDivider('AppearanceSheet applies the dark theme');
    await openSheet(tester, ThemeMode.system);

    await tester.tap(appTextWith(LanguageLabelKeys.dark));
    await tester.pumpAndSettle();

    verify(() => themeCubit.setDark()).called(1);
    printTestLog('setDark → verified once');
  });

  testWidgets('picking system default applies it', (tester) async {
    printTestDivider('AppearanceSheet applies the system theme');
    await openSheet(tester, ThemeMode.dark);

    await tester.tap(appTextWith(LanguageLabelKeys.systemDefault));
    await tester.pumpAndSettle();

    verify(() => themeCubit.setSystem()).called(1);
    printTestLog('setSystem → verified once');
  });
}
