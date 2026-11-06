import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/commons/widgets/paginated_list_footer.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/features/wallet/cubit/wallet_cubit.dart';
import 'package:deliveryboy/features/wallet/models/withdrawal_request_model.dart';
import 'package:deliveryboy/features/wallet/widgets/wallet_balance_card.dart';
import 'package:deliveryboy/features/wallet/widgets/wallet_loaded_body.dart';
import 'package:deliveryboy/features/wallet/widgets/wallet_transaction_item.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockWalletCubit walletCubit;
  late MockCountrySettingsCubit countrySettingsCubit;

  List<WithdrawRequests> entries(int count) => List.generate(
    count,
    (i) => WithdrawRequests.fromJson({'id': '${i + 1}', 'status': '0'}),
  );

  setUp(() async {
    await HiveTestHelper.setUp(settingsBox);
    walletCubit = MockWalletCubit();
    countrySettingsCubit = MockCountrySettingsCubit();
    when(() => walletCubit.balance).thenReturn(4520.75);
    when(() => walletCubit.loadWallet()).thenAnswer((_) {});
    when(() => countrySettingsCubit.getCurrencySymbol()).thenReturn('₹');
  });

  tearDown(() => HiveTestHelper.tearDown(settingsBox));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpBody(
    WidgetTester tester,
    WalletLoaded state,
  ) async {
    whenListen(
      walletCubit,
      const Stream<PaginationState<WithdrawRequests>>.empty(),
      initialState: state,
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<WalletCubit>.value(value: walletCubit),
          BlocProvider<CountrySettingsCubit>.value(value: countrySettingsCubit),
        ],
        child: pumpTestWidget(
          WalletLoadedBody(state: state, scrollController: ScrollController()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the balance card', (tester) async {
    printTestDivider('shows the balance card');
    await pumpBody(
      tester,
      WalletLoaded(data: entries(2), total: 2),
    );

    printTestLog(
      'balance card → expected: 1, actual: ${find.byType(WalletBalanceCard).evaluate().length}',
    );
    expect(find.byType(WalletBalanceCard), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no transactions', (
    tester,
  ) async {
    printTestDivider('shows the empty state when there are no transactions');
    await pumpBody(
      tester,
      WalletLoaded(data: const [], total: 0, hasMore: false),
    );

    printTestLog(
      'empty state → expected: 1, actual: ${find.byType(EmptyStateWidget).evaluate().length}',
    );
    expect(find.byType(EmptyStateWidget), findsOneWidget);
    printTestLog(
      'transaction items → expected: 0, actual: ${find.byType(WalletTransactionItem).evaluate().length}',
    );
    expect(find.byType(WalletTransactionItem), findsNothing);
  });

  testWidgets('renders one item per transaction', (tester) async {
    printTestDivider('renders one item per transaction');
    await pumpBody(
      tester,
      WalletLoaded(data: entries(3), total: 3, hasMore: false),
    );

    printTestLog(
      'items → expected: 3, actual: ${find.byType(WalletTransactionItem).evaluate().length}',
    );
    expect(find.byType(WalletTransactionItem), findsNWidgets(3));
  });

  testWidgets('shows a loading footer while hasMore is true', (tester) async {
    printTestDivider('shows a loading footer while hasMore is true');
    await pumpBody(
      tester,
      WalletLoaded(data: entries(2), total: 10, hasMore: true),
    );

    printTestLog(
      'loading widget → expected: 1, actual: ${find.byType(PaginatedListFooter).evaluate().length}',
    );
    expect(find.byType(PaginatedListFooter), findsOneWidget);
  });

  testWidgets('pull to refresh calls loadWallet', (tester) async {
    printTestDivider('pull to refresh calls loadWallet');
    await pumpBody(
      tester,
      WalletLoaded(data: entries(2), total: 2, hasMore: false),
    );

    final refreshIndicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refreshIndicator.onRefresh();

    verify(() => walletCubit.loadWallet()).called(1);
    printTestLog('loadWallet → verified');
  });
}
