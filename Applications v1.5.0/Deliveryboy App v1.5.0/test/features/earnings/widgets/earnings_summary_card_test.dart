import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/features/earnings/widgets/earnings_summary_card.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  testWidgets('renders total and today earnings formatted to 2 decimals with the currency symbol', (
    tester,
  ) async {
    printTestDivider(
      'renders total and today earnings formatted to 2 decimals with the currency symbol',
    );
    await tester.pumpWidget(
      pumpTestWidget(
        const EarningsSummaryCard(
          totalEarning: 20862.95,
          todayEarning: 96.7,
          currencySymbol: '₹',
        ),
      ),
    );

    printTestLog('total → expected: "₹20862.95" visible');
    expect(find.text('₹20862.95'), findsOneWidget);
    printTestLog('today → expected: "₹96.70" visible');
    expect(find.text('₹96.70'), findsOneWidget);
    printTestLog('total label → expected visible');
    expect(
      find.byWidgetPredicate(
        (w) => w is AppText && w.text == LanguageLabelKeys.totalEarning,
      ),
      findsOneWidget,
    );
    printTestLog('today label → expected visible');
    expect(
      find.byWidgetPredicate(
        (w) => w is AppText && w.text == LanguageLabelKeys.todayEarning,
      ),
      findsOneWidget,
    );
  });

  testWidgets('zero earnings still render "0.00" rather than being blank', (
    tester,
  ) async {
    printTestDivider('zero earnings still render "0.00" rather than being blank');
    await tester.pumpWidget(
      pumpTestWidget(
        const EarningsSummaryCard(
          totalEarning: 0,
          todayEarning: 0,
          currencySymbol: '\$',
        ),
      ),
    );

    printTestLog('total → expected: "\$0.00" visible');
    expect(find.text('\$0.00'), findsNWidgets(2));
  });
}
