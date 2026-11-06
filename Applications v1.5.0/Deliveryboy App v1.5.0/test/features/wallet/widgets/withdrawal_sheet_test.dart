import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/wallet/cubit/wallet_cubit.dart';
import 'package:deliveryboy/features/wallet/models/withdrawal_request_model.dart';
import 'package:deliveryboy/features/wallet/widgets/withdrawal_sheet.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/fake_api_adapter.dart';
import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

/// showWithdrawalSheet builds its own WithdrawalCubit internally, so a mock
/// cubit can't be injected — the real cubit/repository run through the
/// ApiClient adapter seam instead, same approach as order_status_sheet_test.
void main() {
  late MockWalletCubit walletCubit;
  late MockCountrySettingsCubit countrySettingsCubit;
  late FakeApiAdapter adapter;

  setUp(() async {
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);

    walletCubit = MockWalletCubit();
    whenListen(
      walletCubit,
      const Stream<PaginationState<WithdrawRequests>>.empty(),
      initialState: const PaginationInitial<WithdrawRequests>(),
    );
    when(() => walletCubit.loadWallet()).thenAnswer((_) {});

    countrySettingsCubit = MockCountrySettingsCubit();
    when(() => countrySettingsCubit.getCurrencySymbol()).thenReturn('₹');

    adapter = FakeApiAdapter({
      ApiEndpoints.addWithdrawalRequest: (_) => {
        'status': 1,
        'message': 'Withdrawal request submitted',
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

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<WalletCubit>.value(value: walletCubit),
          BlocProvider<CountrySettingsCubit>.value(value: countrySettingsCubit),
        ],
        child: pumpTestWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showWithdrawalSheet(context),
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

  testWidgets('does not submit when the amount field is empty', (
    tester,
  ) async {
    printTestDivider('does not submit when the amount field is empty');
    await pumpSheet(tester);

    await tester.tap(find.text(LanguageLabelKeys.submit));
    await tester.pump();

    printTestLog(
      'submitted → expected: false, actual: ${adapter.requestedPaths.contains(ApiEndpoints.addWithdrawalRequest)}',
    );
    expect(
      adapter.requestedPaths,
      isNot(contains(ApiEndpoints.addWithdrawalRequest)),
    );
  });

  testWidgets('submitting a valid amount sends amount and message', (
    tester,
  ) async {
    printTestDivider('submitting a valid amount sends amount and message');
    await pumpSheet(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '500');
    await tester.enterText(find.byType(TextFormField).at(1), 'Need cash');
    await tester.tap(find.text(LanguageLabelKeys.submit));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final request = adapter.requests.firstWhere(
      (r) => r.path == ApiEndpoints.addWithdrawalRequest,
    );
    final body = request.data as Map;
    printTestLog('amount sent → expected: "500", actual: "${body['amount']}"');
    expect(body['amount'], '500');
    printTestLog(
      'message sent → expected: "Need cash", actual: "${body['message']}"',
    );
    expect(body['message'], 'Need cash');
  });

  testWidgets('a successful submit reloads the wallet and shows a success snackbar', (
    tester,
  ) async {
    printTestDivider(
      'a successful submit reloads the wallet and shows a success snackbar',
    );
    await pumpSheet(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '500');
    await tester.tap(find.text(LanguageLabelKeys.submit));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(() => walletCubit.loadWallet()).called(1);
    printTestLog('loadWallet → verified');
    printTestLog(
      'success message → expected: "${LanguageLabelKeys.withdrawalSuccess}" visible',
    );
    expect(find.text(LanguageLabelKeys.withdrawalSuccess), findsOneWidget);
  });

  testWidgets('a rejected submit shows the server error message and stays open', (
    tester,
  ) async {
    printTestDivider(
      'a rejected submit shows the server error message and stays open',
    );
    adapter = FakeApiAdapter({
      ApiEndpoints.addWithdrawalRequest: (_) => {
        'status': 0,
        'message': 'Withdrawal amount exceeds balance',
      },
    });
    ApiClient().httpClientAdapter = adapter;
    await pumpSheet(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '999999');
    await tester.tap(find.text(LanguageLabelKeys.submit));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    printTestLog(
      'error message → expected: "Withdrawal amount exceeds balance" visible',
    );
    expect(find.text('Withdrawal amount exceeds balance'), findsOneWidget);
    printTestLog(
      'sheet stays open → expected: submit button still present, actual: ${find.text(LanguageLabelKeys.submit).evaluate().length}',
    );
    expect(find.text(LanguageLabelKeys.submit), findsOneWidget);
    verifyNever(() => walletCubit.loadWallet());
  });

  testWidgets('tapping cancel closes the sheet without submitting', (
    tester,
  ) async {
    printTestDivider('tapping cancel closes the sheet without submitting');
    await pumpSheet(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '500');
    await tester.tap(find.text(LanguageLabelKeys.cancel));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    printTestLog(
      'submitted → expected: false, actual: ${adapter.requestedPaths.contains(ApiEndpoints.addWithdrawalRequest)}',
    );
    expect(
      adapter.requestedPaths,
      isNot(contains(ApiEndpoints.addWithdrawalRequest)),
    );
    printTestLog(
      'sheet closed → expected: no submit button, actual: ${find.text(LanguageLabelKeys.submit).evaluate().length}',
    );
    expect(find.text(LanguageLabelKeys.submit), findsNothing);
  });
}
