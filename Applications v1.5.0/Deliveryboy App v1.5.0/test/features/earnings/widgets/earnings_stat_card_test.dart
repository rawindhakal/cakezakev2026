import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/features/earnings/widgets/earnings_stat_card.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  testWidgets('renders the value and label passed in', (tester) async {
    printTestDivider('renders the value and label passed in');
    // EarningsStatCard's root is Expanded, which needs a Flex ancestor.
    await tester.pumpWidget(
      pumpTestWidget(
        Row(
          children: [
            EarningsStatCard(
              icon: AssetsConstants.walletIcon,
              accentColor: Colors.blue,
              value: '₹152.95',
              label: 'Wallet',
            ),
          ],
        ),
      ),
    );

    printTestLog('value → expected: "₹152.95" visible');
    expect(find.text('₹152.95'), findsOneWidget);
    printTestLog('label → expected: "Wallet" visible');
    expect(find.text('Wallet'), findsOneWidget);
  });

  testWidgets('fires onTap when tapped', (tester) async {
    printTestDivider('fires onTap when tapped');
    var tapped = false;
    await tester.pumpWidget(
      pumpTestWidget(
        Row(
          children: [
            EarningsStatCard(
              icon: AssetsConstants.walletIcon,
              accentColor: Colors.blue,
              value: '₹0.00',
              label: 'Wallet',
              onTap: () => tapped = true,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    printTestLog('tapped → expected: true, actual: $tapped');
    expect(tapped, isTrue);
  });

  testWidgets('does not crash when onTap is null', (tester) async {
    printTestDivider('does not crash when onTap is null');
    await tester.pumpWidget(
      pumpTestWidget(
        Row(
          children: [
            EarningsStatCard(
              icon: AssetsConstants.walletIcon,
              accentColor: Colors.blue,
              value: '₹0.00',
              label: 'Wallet',
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    final error = tester.takeException();
    printTestLog('exception → expected: none, actual: $error');
    expect(error, isNull);
  });
}
