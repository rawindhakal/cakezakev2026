import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/wallet/cubit/wallet_cubit.dart';
import 'package:deliveryboy/features/wallet/models/withdrawal_request_model.dart';
import 'package:deliveryboy/features/wallet/models/withdrawal_status.dart';
import 'package:deliveryboy/features/wallet/widgets/wallet_filter_sheet.dart';

import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockWalletCubit walletCubit;

  setUp(() {
    walletCubit = MockWalletCubit();
    whenListen(
      walletCubit,
      const Stream<PaginationState<WithdrawRequests>>.empty(),
      initialState: const PaginationInitial<WithdrawRequests>(),
    );
    when(() => walletCubit.filterByStatus(any())).thenAnswer((_) async {});
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpSheet(WidgetTester tester, {String selectedStatus = ''}) async {
    when(() => walletCubit.selectedStatus).thenReturn(selectedStatus);

    await tester.pumpWidget(
      BlocProvider<WalletCubit>.value(
        value: walletCubit,
        child: pumpTestWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showWalletFilterSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('shows all four status options', (tester) async {
    printTestDivider('shows all four status options');
    await pumpSheet(tester);

    printTestLog(
      'radio options → expected: 4, actual: ${find.byType(RadioListTile<WithdrawalStatus>).evaluate().length}',
    );
    expect(find.byType(RadioListTile<WithdrawalStatus>), findsNWidgets(4));
    expect(find.text(LanguageLabelKeys.all), findsOneWidget);
    expect(find.text(LanguageLabelKeys.pending), findsOneWidget);
    expect(find.text(LanguageLabelKeys.approved), findsOneWidget);
    expect(find.text(LanguageLabelKeys.rejected), findsOneWidget);
  });

  testWidgets('selecting a status calls filterByStatus with its value and closes the sheet', (
    tester,
  ) async {
    printTestDivider(
      'selecting a status calls filterByStatus with its value and closes the sheet',
    );
    await pumpSheet(tester);

    await tester.tap(find.text(LanguageLabelKeys.pending));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(() => walletCubit.filterByStatus('0')).called(1);
    printTestLog('filterByStatus("0") → verified');
    printTestLog(
      'sheet closed → expected: no radio options, actual: ${find.byType(RadioListTile<WithdrawalStatus>).evaluate().length}',
    );
    expect(find.byType(RadioListTile<WithdrawalStatus>), findsNothing);
  });

  testWidgets('selecting rejected sends its value', (tester) async {
    printTestDivider('selecting rejected sends its value');
    await pumpSheet(tester);

    await tester.tap(find.text(LanguageLabelKeys.rejected));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(() => walletCubit.filterByStatus('2')).called(1);
    printTestLog('filterByStatus("2") → verified');
  });
}
