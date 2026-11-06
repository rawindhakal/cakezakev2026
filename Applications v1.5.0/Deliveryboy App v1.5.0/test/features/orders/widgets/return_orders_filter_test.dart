import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/return_order_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/return_order_status_list_filter_cubit.dart';
import 'package:deliveryboy/features/orders/models/order_status_model.dart';
import 'package:deliveryboy/features/orders/models/return_order_model.dart';
import 'package:deliveryboy/features/orders/widgets/status_filter_chips.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

class MockReturnOrderCubit extends MockCubit<PaginationState<ReturnRequestData>>
    implements ReturnOrderCubit {}

class MockReturnOrderStatusListFilterCubit
    extends MockCubit<ReturnOrderStatusListFilterState>
    implements ReturnOrderStatusListFilterCubit {}

void main() {
  late MockReturnOrderCubit returnCubit;
  late MockReturnOrderStatusListFilterCubit filterCubit;

  setUp(() {
    returnCubit = MockReturnOrderCubit();
    filterCubit = MockReturnOrderStatusListFilterCubit();

    whenListen(
      returnCubit,
      const Stream<PaginationState<ReturnRequestData>>.empty(),
      initialState: const PaginationLoaded<ReturnRequestData>(data: [], total: 0),
    );
    when(() => returnCubit.selectedStatus).thenReturn('5');
    when(() => returnCubit.startDate).thenReturn(null);
    when(() => returnCubit.endDate).thenReturn(null);
    when(() => returnCubit.hasActiveFilters).thenReturn(false);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('ReturnStatusChips', () {
    testWidgets('renders a chip per status and reports taps', (tester) async {
      printTestDivider('ReturnStatusChips renders a chip per status and reports taps');
      whenListen(
        filterCubit,
        const Stream<ReturnOrderStatusListFilterState>.empty(),
        initialState: ReturnOrderStatusListFilterLoaded([
          OrderStatusData(id: '5', status: 'Out for Pickup', statusName: 'Out for Pickup'),
          OrderStatusData(id: '6', status: 'Received', statusName: 'Received'),
        ]),
      );

      String? tapped;
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<ReturnOrderCubit>.value(value: returnCubit),
            BlocProvider<ReturnOrderStatusListFilterCubit>.value(value: filterCubit),
          ],
          child: pumpTestWidget(ReturnStatusChips(onStatusChanged: (id) => tapped = id)),
        ),
      );

      expect(find.text('Received'), findsOneWidget);
      printTestLog('expected: chip labels visible, actual: found');

      await tester.tap(find.text('Received'));
      printTestLog('expected: tapped id "6", actual: $tapped');
      expect(tapped, '6');
    });

    testWidgets('renders a placeholder strip while the status list is loading', (tester) async {
      printTestDivider('ReturnStatusChips renders a placeholder strip while the status list is loading');
      whenListen(
        filterCubit,
        const Stream<ReturnOrderStatusListFilterState>.empty(),
        initialState: ReturnOrderStatusListFilterInitial(),
      );

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<ReturnOrderCubit>.value(value: returnCubit),
            BlocProvider<ReturnOrderStatusListFilterCubit>.value(value: filterCubit),
          ],
          child: pumpTestWidget(ReturnStatusChips(onStatusChanged: (_) {})),
        ),
      );

      printTestLog('expected: no ChoiceChip until loaded, actual: ${find.byType(ChoiceChip).evaluate().length}');
      expect(find.byType(ChoiceChip), findsNothing);
    });
  });

  group('ReturnDateFilterActions', () {
    testWidgets('shows no clear affordance with no active filters', (tester) async {
      printTestDivider('ReturnDateFilterActions shows no clear affordance with no active filters');
      await tester.pumpWidget(
        BlocProvider<ReturnOrderCubit>.value(
          value: returnCubit,
          child: pumpTestWidget(
            ReturnDateFilterActions(cubit: returnCubit, onPickDate: () {}, onClear: () {}),
          ),
        ),
      );

      // Only the date IconButton's own InkWell — no separate clear InkWell.
      printTestLog('expected: 1 InkWell (date icon only), actual: ${find.byType(InkWell).evaluate().length}');
      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('fires onPickDate and onClear once filters are active', (tester) async {
      printTestDivider('ReturnDateFilterActions fires onPickDate and onClear once filters are active');
      when(() => returnCubit.hasActiveFilters).thenReturn(true);
      when(() => returnCubit.startDate).thenReturn('2026-01-01');
      when(() => returnCubit.endDate).thenReturn('2026-01-05');

      var picked = false;
      var cleared = false;
      await tester.pumpWidget(
        BlocProvider<ReturnOrderCubit>.value(
          value: returnCubit,
          child: pumpTestWidget(
            ReturnDateFilterActions(
              cubit: returnCubit,
              onPickDate: () => picked = true,
              onClear: () => cleared = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      printTestLog('expected: picked true, actual: $picked');
      expect(picked, isTrue);

      await tester.tap(find.byType(InkWell).last);
      printTestLog('expected: cleared true, actual: $cleared');
      expect(cleared, isTrue);
    });
  });
}
