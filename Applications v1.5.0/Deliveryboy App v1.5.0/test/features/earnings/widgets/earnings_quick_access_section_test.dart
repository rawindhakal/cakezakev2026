import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/earnings/widgets/earnings_quick_access_section.dart';
import 'package:deliveryboy/features/home/models/dashboard_model.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  testWidgets('renders formatted values for wallet/cash/salary and the raw settlement total', (
    tester,
  ) async {
    printTestDivider(
      'renders formatted values for wallet/cash/salary and the raw settlement total',
    );
    await tester.pumpWidget(
      pumpTestWidget(
        EarningsQuickAccessSection(
          wallet: Wallet(available: 152.95),
          salary: Salary(totalPaid: 20000),
          cash: Cash(inHand: 16703.34),
          settlementHistory: 298657.15,
          currencySymbol: '₹',
          onWalletTap: () {},
          onSalaryTap: () {},
          onCashCollectionTap: () {},
          onFundTransferTap: () {},
        ),
      ),
    );

    printTestLog('wallet available → expected: "₹152.95" visible');
    expect(find.text('₹152.95'), findsOneWidget);
    printTestLog('cash in hand → expected: "₹16703.34" visible');
    expect(find.text('₹16703.34'), findsOneWidget);
    printTestLog('salary total paid → expected: "₹20000.00" visible');
    expect(find.text('₹20000.00'), findsOneWidget);
    // settlementHistory is interpolated directly (no toStringAsFixed), unlike
    // the other three tiles — documents the current (inconsistent) behavior.
    printTestLog('settlement total (raw double) → expected: "₹298657.15" visible');
    expect(find.text('₹298657.15'), findsOneWidget);

    printTestLog('wallet label → expected visible');
    expect(find.text(LanguageLabelKeys.wallet), findsOneWidget);
    printTestLog('cash collection label → expected visible');
    expect(find.text(LanguageLabelKeys.cashCollection), findsOneWidget);
    printTestLog('salary label → expected visible');
    expect(find.text(LanguageLabelKeys.salary), findsOneWidget);
    printTestLog('settlement history label → expected visible');
    expect(find.text(LanguageLabelKeys.settlementHistory), findsOneWidget);
  });

  testWidgets('falls back to 0.00 when wallet/cash/salary are null', (
    tester,
  ) async {
    printTestDivider('falls back to 0.00 when wallet/cash/salary are null');
    await tester.pumpWidget(
      pumpTestWidget(
        EarningsQuickAccessSection(
          wallet: null,
          salary: null,
          cash: null,
          settlementHistory: 0,
          currencySymbol: '₹',
          onWalletTap: () {},
          onSalaryTap: () {},
          onCashCollectionTap: () {},
          onFundTransferTap: () {},
        ),
      ),
    );

    printTestLog('wallet/cash/salary fallback → expected: "₹0.00" x3 visible');
    expect(find.text('₹0.00'), findsNWidgets(3));
    printTestLog('settlement fallback (raw 0) → expected: "₹0.0" visible');
    expect(find.text('₹0.0'), findsOneWidget);
  });

  testWidgets('each tile fires its own tap callback', (tester) async {
    printTestDivider('each tile fires its own tap callback');
    var wallet = false, salary = false, cash = false, fundTransfer = false;
    await tester.pumpWidget(
      pumpTestWidget(
        EarningsQuickAccessSection(
          wallet: null,
          salary: null,
          cash: null,
          settlementHistory: 0,
          currencySymbol: '₹',
          onWalletTap: () => wallet = true,
          onSalaryTap: () => salary = true,
          onCashCollectionTap: () => cash = true,
          onFundTransferTap: () => fundTransfer = true,
        ),
      ),
    );

    await tester.tap(find.text(LanguageLabelKeys.wallet));
    await tester.tap(find.text(LanguageLabelKeys.cashCollection));
    await tester.tap(find.text(LanguageLabelKeys.salary));
    await tester.tap(find.text(LanguageLabelKeys.settlementHistory));
    await tester.pump();

    printTestLog(
      'wallet=$wallet cash=$cash salary=$salary fundTransfer=$fundTransfer → expected: all true',
    );
    expect(wallet, isTrue);
    expect(cash, isTrue);
    expect(salary, isTrue);
    expect(fundTransfer, isTrue);
  });
}
