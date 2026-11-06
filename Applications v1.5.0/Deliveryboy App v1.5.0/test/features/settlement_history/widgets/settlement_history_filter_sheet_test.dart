import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import 'package:deliveryboy/commons/widgets/date_range_filter_field.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/settlement_history/cubit/settlement_history_cubit.dart';
import 'package:deliveryboy/features/settlement_history/models/settlement_entry_type.dart';
import 'package:deliveryboy/features/settlement_history/models/settlement_history_model.dart';
import 'package:deliveryboy/features/settlement_history/widgets/settlement_history_filter_sheet.dart';

import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockSettlementHistoryCubit cubit;

  setUp(() {
    cubit = MockSettlementHistoryCubit();
    whenListen(
      cubit,
      const Stream<PaginationState<SettlementHistoryData>>.empty(),
      initialState: const PaginationInitial<SettlementHistoryData>(),
    );
    when(
      () => cubit.updateFilters(
        search: any(named: 'search'),
        entryType: any(named: 'entryType'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async {});
    when(() => cubit.clearFilters()).thenAnswer((_) async {});
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpSheet(
    WidgetTester tester, {
    String entryType = '',
    String? startDate,
    String? endDate,
    bool hasActiveFilters = false,
    VoidCallback? onClearSearch,
  }) async {
    when(() => cubit.entryType).thenReturn(entryType);
    when(() => cubit.startDate).thenReturn(startDate);
    when(() => cubit.endDate).thenReturn(endDate);
    when(() => cubit.hasActiveFilters).thenReturn(hasActiveFilters);

    await tester.pumpWidget(
      BlocProvider<SettlementHistoryCubit>.value(
        value: cubit,
        child: pumpTestWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showSettlementHistoryFilterSheet(
                context,
                onClearSearch: onClearSearch,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    // The sheet's children slide in; a still-animating button is not
    // hit-testable, so wait out the entrance before tapping.
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('shows the date-range field and all six entry-type options', (
    tester,
  ) async {
    printTestDivider('shows the date-range field and all six entry-type options');
    await pumpSheet(tester);

    printTestLog(
      'date-range field → expected: 1, actual: ${find.byType(DateRangeFilterField).evaluate().length}',
    );
    expect(find.byType(DateRangeFilterField), findsOneWidget);
    printTestLog(
      'radio options → expected: 6, actual: ${find.byType(RadioListTile<SettlementEntryType>).evaluate().length}',
    );
    expect(find.byType(RadioListTile<SettlementEntryType>), findsNWidgets(6));
    for (final label in [
      LanguageLabelKeys.all,
      LanguageLabelKeys.deliveryCommission,
      LanguageLabelKeys.returnCommission,
      LanguageLabelKeys.withdrawal,
      LanguageLabelKeys.cashDepositCash,
      LanguageLabelKeys.cashDepositWallet,
    ]) {
      printTestLog('option "$label" → expected: visible');
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('preselects the entry type the cubit already has applied', (
    tester,
  ) async {
    printTestDivider('preselects the entry type the cubit already has applied');
    await pumpSheet(tester, entryType: 'withdrawal');

    final group = tester.widget<RadioGroup<SettlementEntryType>>(
      find.byType(RadioGroup<SettlementEntryType>),
    );
    printTestLog(
      'groupValue → expected: withdrawal, actual: ${group.groupValue?.name}',
    );
    expect(group.groupValue, SettlementEntryType.withdrawal);
  });

  testWidgets('defaults the selection to All when no entry type is applied', (
    tester,
  ) async {
    printTestDivider('defaults the selection to All when no entry type is applied');
    await pumpSheet(tester);

    final group = tester.widget<RadioGroup<SettlementEntryType>>(
      find.byType(RadioGroup<SettlementEntryType>),
    );
    printTestLog('groupValue → expected: all, actual: ${group.groupValue?.name}');
    expect(group.groupValue, SettlementEntryType.all);
  });

  testWidgets('shows the cubit dates in the date-range field when a range is applied', (
    tester,
  ) async {
    printTestDivider(
      'shows the cubit dates in the date-range field when a range is applied',
    );
    await pumpSheet(
      tester,
      startDate: '2026-08-01',
      endDate: '2026-08-17',
      hasActiveFilters: true,
    );

    printTestLog('date range → expected: "2026-08-01 → 2026-08-17" visible');
    expect(find.text('2026-08-01 → 2026-08-17'), findsOneWidget);
  });

  testWidgets('selecting a type and applying sends its wire value with the dates', (
    tester,
  ) async {
    printTestDivider('selecting a type and applying sends its wire value with the dates');
    await pumpSheet(tester, startDate: '2026-08-01', endDate: '2026-08-17');

    await tester.tap(find.text(LanguageLabelKeys.withdrawal));
    await tester.pump();
    await tester.tap(find.text(LanguageLabelKeys.apply));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(
      () => cubit.updateFilters(
        entryType: 'withdrawal',
        startDate: '2026-08-01',
        endDate: '2026-08-17',
      ),
    ).called(1);
    printTestLog('updateFilters(entryType: "withdrawal", dates kept) → verified');
    printTestLog(
      'sheet closed → expected: no radio options, actual: ${find.byType(RadioListTile<SettlementEntryType>).evaluate().length}',
    );
    expect(find.byType(RadioListTile<SettlementEntryType>), findsNothing);
  });

  testWidgets('applying without touching anything re-sends the current filters unchanged', (
    tester,
  ) async {
    printTestDivider(
      'applying without touching anything re-sends the current filters unchanged',
    );
    await pumpSheet(
      tester,
      entryType: 'delivery_commission',
      startDate: '2026-08-01',
      endDate: '2026-08-17',
    );

    await tester.tap(find.text(LanguageLabelKeys.apply));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(
      () => cubit.updateFilters(
        entryType: 'delivery_commission',
        startDate: '2026-08-01',
        endDate: '2026-08-17',
      ),
    ).called(1);
    printTestLog('updateFilters with unchanged filters → verified');
  });

  testWidgets('picking All sends the empty wire value, clearing the type filter', (
    tester,
  ) async {
    printTestDivider('picking All sends the empty wire value, clearing the type filter');
    await pumpSheet(tester, entryType: 'withdrawal', hasActiveFilters: true);

    await tester.tap(find.text(LanguageLabelKeys.all));
    await tester.pump();
    await tester.tap(find.text(LanguageLabelKeys.apply));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(
      () => cubit.updateFilters(
        entryType: '',
        startDate: null,
        endDate: null,
      ),
    ).called(1);
    printTestLog('updateFilters(entryType: "") → verified');
  });

  testWidgets('clearing the date range inside the sheet applies without dates', (
    tester,
  ) async {
    printTestDivider('clearing the date range inside the sheet applies without dates');
    await pumpSheet(
      tester,
      startDate: '2026-08-01',
      endDate: '2026-08-17',
      hasActiveFilters: true,
    );

    // The X inside the date field is the second InkWell in the field — tap
    // it rather than the field itself, which would open the date picker.
    await tester.tap(
      find.descendant(
        of: find.byType(DateRangeFilterField),
        matching: find.byType(InkWell),
      ).last,
    );
    await tester.pump();

    printTestLog(
      'date range text → expected: cleared, actual: ${find.text('2026-08-01 → 2026-08-17').evaluate().length}',
    );
    expect(find.text('2026-08-01 → 2026-08-17'), findsNothing);

    await tester.tap(find.text(LanguageLabelKeys.apply));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(
      () => cubit.updateFilters(
        entryType: '',
        startDate: null,
        endDate: null,
      ),
    ).called(1);
    printTestLog('updateFilters with both dates null → verified');
  });

  group('Clear button', () {
    testWidgets('only closes the sheet when nothing is filtered', (tester) async {
      printTestDivider('Clear button only closes the sheet when nothing is filtered');
      var searchCleared = false;
      await pumpSheet(
        tester,
        onClearSearch: () => searchCleared = true,
      );

      await tester.tap(find.text(LanguageLabelKeys.clear));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      printTestLog('cubit.clearFilters() → expected: not called');
      verifyNever(() => cubit.clearFilters());
      printTestLog('onClearSearch → expected: false, actual: $searchCleared');
      expect(searchCleared, isFalse);
      printTestLog(
        'sheet closed → expected: no radio options, actual: ${find.byType(RadioListTile<SettlementEntryType>).evaluate().length}',
      );
      expect(find.byType(RadioListTile<SettlementEntryType>), findsNothing);
    });

    testWidgets('clears the cubit filters and the search box when a filter is applied', (
      tester,
    ) async {
      printTestDivider(
        'Clear button clears the cubit filters and the search box when a filter is applied',
      );
      var searchCleared = false;
      await pumpSheet(
        tester,
        entryType: 'withdrawal',
        hasActiveFilters: true,
        onClearSearch: () => searchCleared = true,
      );

      await tester.tap(find.text(LanguageLabelKeys.clear));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(() => cubit.clearFilters()).called(1);
      printTestLog('cubit.clearFilters() → verified');
      printTestLog('onClearSearch → expected: true, actual: $searchCleared');
      expect(searchCleared, isTrue);
    });

    testWidgets('never calls updateFilters — clearing is not an apply', (
      tester,
    ) async {
      printTestDivider('Clear button never calls updateFilters — clearing is not an apply');
      await pumpSheet(tester, entryType: 'withdrawal', hasActiveFilters: true);

      await tester.tap(find.text(LanguageLabelKeys.clear));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verifyNever(
        () => cubit.updateFilters(
          search: any(named: 'search'),
          entryType: any(named: 'entryType'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      );
      printTestLog('cubit.updateFilters() → expected: not called');
    });
  });
}
