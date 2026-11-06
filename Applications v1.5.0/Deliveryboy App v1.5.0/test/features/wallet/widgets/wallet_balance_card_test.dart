import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/features/wallet/widgets/wallet_balance_card.dart';

import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockCountrySettingsCubit countrySettingsCubit;

  setUp(() {
    countrySettingsCubit = MockCountrySettingsCubit();
    when(() => countrySettingsCubit.getCurrencySymbol()).thenReturn('₹');
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpCard(
    WidgetTester tester, {
    required double balance,
    VoidCallback? onWithdraw,
  }) async {
    await tester.pumpWidget(
      BlocProvider<CountrySettingsCubit>.value(
        value: countrySettingsCubit,
        child: pumpTestWidget(
          WalletBalanceCard(
            balance: balance,
            onWithdraw: onWithdraw ?? () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the balance prefixed with the currency symbol, rounded to whole', (
    tester,
  ) async {
    printTestDivider(
      'shows the balance prefixed with the currency symbol, rounded to whole',
    );
    await pumpCard(tester, balance: 4520.75);

    printTestLog('balance text → expected: "₹4521" visible');
    expect(find.text('₹4521'), findsOneWidget);
  });

  testWidgets('shows a zero balance the same way', (tester) async {
    printTestDivider('shows a zero balance the same way');
    await pumpCard(tester, balance: 0);

    printTestLog('balance text → expected: "₹0" visible');
    expect(find.text('₹0'), findsOneWidget);
  });

  testWidgets('fires onWithdraw when the withdraw pill is tapped', (
    tester,
  ) async {
    printTestDivider('fires onWithdraw when the withdraw pill is tapped');
    var tapped = false;
    await pumpCard(
      tester,
      balance: 100,
      onWithdraw: () => tapped = true,
    );

    await tester.tap(find.byType(GestureDetector));
    await tester.pump();

    printTestLog('onWithdraw called → expected: true, actual: $tapped');
    expect(tapped, isTrue);
  });
}
