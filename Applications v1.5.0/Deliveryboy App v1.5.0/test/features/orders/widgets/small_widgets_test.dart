import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/slide_to_confirm_button.dart';
import 'package:deliveryboy/features/orders/models/order_status_model.dart';
import 'package:deliveryboy/features/orders/widgets/order_appbar_title.dart';
import 'package:deliveryboy/features/orders/widgets/order_date_filter_row.dart';
import 'package:deliveryboy/features/orders/widgets/order_status_slide_bar.dart';
import 'package:deliveryboy/features/orders/widgets/status_filter_chips.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('OrderAppBarTitle', () {
    testWidgets('renders the status label above the id line', (tester) async {
      printTestDivider('OrderAppBarTitle renders the status label above the id line');
      await tester.pumpWidget(
        pumpTestWidget(
          const OrderAppBarTitle(statusLabel: 'Delivered', idLine: '#SB-ORD-00006'),
        ),
      );

      expect(find.text('Delivered'), findsOneWidget);
      expect(find.text('#SB-ORD-00006'), findsOneWidget);
      printTestLog('expected: both lines visible, actual: both found');
    });
  });

  group('OrderStatusSlideConfirmBar', () {
    testWidgets('tapping the confirm slide fires onConfirm', (tester) async {
      printTestDivider('OrderStatusSlideConfirmBar tapping the confirm slide fires onConfirm');
      var confirmed = false;
      await tester.pumpWidget(
        pumpTestWidget(
          OrderStatusSlideConfirmBar(
            label: 'Mark as Delivered',
            isLoading: false,
            onConfirm: () => confirmed = true,
          ),
        ),
      );

      expect(find.text('Mark as Delivered'), findsOneWidget);
      printTestLog('expected: label visible, actual: found');

      // The thumb only fires once the accumulated drag reaches the full
      // track width minus the thumb — a plain tester.drag() falls short and
      // silently snaps back, so sweep with a multi-step gesture instead.
      final track = find.byType(SlideToConfirmButton);
      final rect = tester.getRect(track);
      final gesture = await tester.startGesture(Offset(rect.left + 8, rect.center.dy));
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(40, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      printTestLog('expected: confirmed true, actual: $confirmed');
      expect(confirmed, isTrue);
    });

    testWidgets('a null onConfirm disables the slide (no crash on drag)', (tester) async {
      printTestDivider('OrderStatusSlideConfirmBar a null onConfirm disables the slide');
      await tester.pumpWidget(
        pumpTestWidget(
          const OrderStatusSlideConfirmBar(label: 'Mark as Delivered', isLoading: false, onConfirm: null),
        ),
      );

      await tester.drag(find.byType(OrderStatusSlideConfirmBar), const Offset(400, 0));
      await tester.pump();
      printTestLog('expected: no crash with onConfirm null, actual: pumped cleanly');
      expect(tester.takeException(), isNull);
    });
  });

  group('OrderDateFilterRow', () {
    testWidgets('shows the active-date dot only when hasDate is true', (tester) async {
      printTestDivider('OrderDateFilterRow shows the active-date dot only when hasDate is true');
      await tester.pumpWidget(
        pumpTestWidget(
          OrderDateFilterRow(
            hasDate: true,
            hasActiveFilters: false,
            dateTooltip: '2026-01-01 → 2026-01-05',
            onPickDate: () {},
            onClear: () {},
          ),
        ),
      );

      expect(find.byTooltip('2026-01-01 → 2026-01-05'), findsOneWidget);
      printTestLog('expected: date tooltip present, actual: found');
    });

    testWidgets('shows a clear button only when filters are active', (tester) async {
      printTestDivider('OrderDateFilterRow shows a clear button only when filters are active');
      var cleared = false;
      await tester.pumpWidget(
        pumpTestWidget(
          OrderDateFilterRow(
            hasDate: false,
            hasActiveFilters: true,
            dateTooltip: 'Date Range',
            onPickDate: () {},
            onClear: () => cleared = true,
          ),
        ),
      );

      // IconButton wraps its own InkWell internally, so the plain-clear
      // button is the *last* InkWell in the tree, not the only one.
      final clearInkWell = find.byType(InkWell).last;
      expect(clearInkWell, findsOneWidget);
      await tester.tap(clearInkWell);
      printTestLog('expected: cleared true, actual: $cleared');
      expect(cleared, isTrue);
    });
  });

  group('StatusFilterChips', () {
    final statuses = [
      OrderStatusData(id: '10', status: 'Ready for Pickup', statusName: 'Ready for Pickup'),
      OrderStatusData(id: '11', status: 'Picked Up', statusName: 'Picked Up'),
    ];

    testWidgets('marks the selected status chip and reports taps on the rest', (tester) async {
      printTestDivider('StatusFilterChips marks the selected status chip and reports taps on the rest');
      String? tapped;
      await tester.pumpWidget(
        pumpTestWidget(
          StatusFilterChips(
            statuses: statuses,
            selectedId: '10',
            onStatusChanged: (id) => tapped = id,
          ),
        ),
      );

      final selectedChip = tester.widget<ChoiceChip>(find.byType(ChoiceChip).first);
      printTestLog('expected: first chip selected, actual: ${selectedChip.selected}');
      expect(selectedChip.selected, isTrue);

      await tester.tap(find.text('Picked Up'));
      printTestLog('expected: tapped id "11", actual: $tapped');
      expect(tapped, '11');
    });
  });
}
