import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/features/cash_collection/cubit/cash_collection_cubit.dart';
import 'package:deliveryboy/features/cash_collection/models/cash_collection_model.dart';
import 'package:deliveryboy/features/cash_collection/widgets/cash_collection_summary_card.dart';

import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockCashCollectionCubit cashCollectionCubit;
  late MockCountrySettingsCubit countrySettingsCubit;

  setUp(() {
    cashCollectionCubit = MockCashCollectionCubit();
    countrySettingsCubit = MockCountrySettingsCubit();
    when(() => countrySettingsCubit.getCurrencySymbol()).thenReturn('₹');
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpCard(
    WidgetTester tester,
    PaginationState<CashCollectionModel> state, {
    dynamic cashInHand,
    dynamic cashCollected,
  }) async {
    whenListen(
      cashCollectionCubit,
      const Stream<PaginationState<CashCollectionModel>>.empty(),
      initialState: state,
    );
    // cashInHand/cashCollected are getters on the real cubit that read off
    // state.meta; on a mocktail Mock they're stubbed independently rather
    // than computed, so the widget's is-loaded check and its getter reads
    // are exercised as two separate seams here.
    when(() => cashCollectionCubit.cashInHand).thenReturn(cashInHand);
    when(() => cashCollectionCubit.cashCollected).thenReturn(cashCollected);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<CashCollectionCubit>.value(value: cashCollectionCubit),
          BlocProvider<CountrySettingsCubit>.value(value: countrySettingsCubit),
        ],
        child: pumpTestWidget(const CashCollectionSummaryCard()),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows an em dash for both stats outside the loaded state', (
    tester,
  ) async {
    printTestDivider('shows an em dash for both stats outside the loaded state');
    await pumpCard(tester, const PaginationInitial<CashCollectionModel>());

    // The currency symbol comes from CountrySettingsCubit (country-specific,
    // not hardcoded) — stubbed to '₹' in setUp for this test only, so the
    // placeholder is prefixed with whatever that stub returns.
    final placeholder = '₹—';
    printTestLog('placeholders → expected: 2, actual: ${find.text(placeholder).evaluate().length}');
    expect(find.text(placeholder), findsNWidgets(2));
  });

  testWidgets('shows cash-in-hand and cash-collected with the currency symbol', (
    tester,
  ) async {
    printTestDivider(
      'shows cash-in-hand and cash-collected with the currency symbol',
    );
    await pumpCard(
      tester,
      const PaginationLoaded<CashCollectionModel>(data: [], total: 0),
      cashInHand: '1245.50',
      cashCollected: '8420.75',
    );

    printTestLog('cashInHand → expected: "₹1245.50" visible');
    expect(find.text('₹1245.50'), findsOneWidget);
    printTestLog('cashCollected → expected: "₹8420.75" visible');
    expect(find.text('₹8420.75'), findsOneWidget);
  });

  testWidgets('formats a numeric meta value to two decimals', (tester) async {
    printTestDivider('formats a numeric meta value to two decimals');
    await pumpCard(
      tester,
      const PaginationLoaded<CashCollectionModel>(data: [], total: 0),
      cashInHand: 1245.5,
      cashCollected: 8420,
    );

    printTestLog('cashInHand → expected: "₹1245.50" visible');
    expect(find.text('₹1245.50'), findsOneWidget);
    printTestLog('cashCollected → expected: "₹8420.00" visible');
    expect(find.text('₹8420.00'), findsOneWidget);
  });

  testWidgets('falls back to 0 for a null/empty/"null" meta value', (
    tester,
  ) async {
    printTestDivider('falls back to 0 for a null/empty/"null" meta value');
    await pumpCard(
      tester,
      const PaginationLoaded<CashCollectionModel>(data: [], total: 0),
      cashInHand: null,
      cashCollected: 'null',
    );

    printTestLog('both values → expected: "₹0" shown twice');
    expect(find.text('₹0'), findsNWidgets(2));
  });
}
