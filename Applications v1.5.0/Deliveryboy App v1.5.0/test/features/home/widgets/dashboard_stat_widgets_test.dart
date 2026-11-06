import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/features/home/widgets/dashboard_stat_card.dart';
import 'package:deliveryboy/features/home/widgets/dashboard_stat_column.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('DashboardStatColumn', () {
    testWidgets('renders its label and value', (tester) async {
      printTestDivider('DashboardStatColumn renders its label and value');
      await tester.pumpWidget(
        pumpTestWidget(
          const DashboardStatColumn(label: 'Quick Orders', value: '12'),
        ),
      );

      printTestLog('label → expected: "Quick Orders" visible');
      expect(find.text('Quick Orders'), findsOneWidget);
      printTestLog('value → expected: "12" visible');
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('aligns the value to the start by default', (tester) async {
      printTestDivider('DashboardStatColumn aligns the value to the start by default');
      await tester.pumpWidget(
        pumpTestWidget(const DashboardStatColumn(label: 'Orders', value: '3')),
      );

      final valueText = tester.widget<Text>(find.text('3'));
      printTestLog('value textAlign → expected: start, actual: ${valueText.textAlign}');
      expect(valueText.textAlign, TextAlign.start);
    });

    testWidgets('aligns the value to the end when alignEnd is set', (
      tester,
    ) async {
      printTestDivider('DashboardStatColumn aligns the value to the end when alignEnd is set');
      await tester.pumpWidget(
        pumpTestWidget(
          const DashboardStatColumn(label: 'Orders', value: '3', alignEnd: true),
        ),
      );

      final valueText = tester.widget<Text>(find.text('3'));
      printTestLog('value textAlign → expected: end, actual: ${valueText.textAlign}');
      expect(valueText.textAlign, TextAlign.end);
    });

    testWidgets('centres the value when center is set, which wins over alignEnd', (
      tester,
    ) async {
      printTestDivider(
        'DashboardStatColumn centres the value when center is set, which wins over alignEnd',
      );
      await tester.pumpWidget(
        pumpTestWidget(
          const DashboardStatColumn(
            label: 'Orders',
            value: '3',
            center: true,
            alignEnd: true,
          ),
        ),
      );

      final valueText = tester.widget<Text>(find.text('3'));
      printTestLog('value textAlign → expected: center, actual: ${valueText.textAlign}');
      expect(valueText.textAlign, TextAlign.center);
    });
  });

  group('DashboardStatCard', () {
    // The card is an Expanded, so it has to sit inside a Row to lay out.
    Widget wrapInRow(Widget card) => Row(children: [card]);

    testWidgets('renders its label and value', (tester) async {
      printTestDivider('DashboardStatCard renders its label and value');
      await tester.pumpWidget(
        pumpTestWidget(
          wrapInRow(
            const DashboardStatCard(
              icon: AssetsConstants.walletIcon,
              label: 'Wallet',
              value: '₹366.25',
            ),
          ),
        ),
      );

      printTestLog('label → expected: "Wallet" visible');
      expect(find.text('Wallet'), findsOneWidget);
      printTestLog('value → expected: "₹366.25" visible');
      expect(find.text('₹366.25'), findsOneWidget);
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      printTestDivider('DashboardStatCard invokes onTap when tapped');
      var tapped = false;
      await tester.pumpWidget(
        pumpTestWidget(
          wrapInRow(
            DashboardStatCard(
              icon: AssetsConstants.walletIcon,
              label: 'Wallet',
              value: '₹366.25',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      printTestLog('onTap called → expected: true, actual: $tapped');
      expect(tapped, isTrue);
    });

    testWidgets('is inert when no onTap is given', (tester) async {
      printTestDivider('DashboardStatCard is inert when no onTap is given');
      await tester.pumpWidget(
        pumpTestWidget(
          wrapInRow(
            const DashboardStatCard(
              icon: AssetsConstants.walletIcon,
              label: 'Wallet',
              value: '₹366.25',
            ),
          ),
        ),
      );

      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      printTestLog('InkWell.onTap → expected: null, actual: ${inkWell.onTap}');
      expect(inkWell.onTap, isNull);

      // Tapping a card with no handler must not throw.
      await tester.tap(find.byType(InkWell));
      await tester.pump();
    });
  });
}
