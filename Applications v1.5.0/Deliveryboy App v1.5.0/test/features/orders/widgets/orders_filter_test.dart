import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/ecommerce_order_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/order_cubit.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/orders/cubit/order_status_list_filter_cubit.dart';
import 'package:deliveryboy/features/orders/models/ecommerce_order_model.dart';
import 'package:deliveryboy/features/orders/models/order_model.dart';
import 'package:deliveryboy/features/orders/models/order_status_model.dart';
import 'package:deliveryboy/features/orders/widgets/status_filter_chips.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

class MockOrderStatusListFilterCubit
    extends MockCubit<OrderStatusListFilterState>
    implements OrderStatusListFilterCubit {}

class MockOrderCubit extends MockCubit<PaginationState<OrderData>>
    implements OrderCubit {}

class MockEcommerceOrderCubit
    extends MockCubit<PaginationState<EcommerceOrderDataModel>>
    implements EcommerceOrderCubit {}

void main() {
  late MockOrderStatusListFilterCubit filterCubit;
  late MockOrderCubit orderCubit;
  late MockEcommerceOrderCubit ecommerceCubit;

  final statuses = [
    OrderStatusData(id: '', status: 'All', statusName: 'All'),
    OrderStatusData(id: '5', status: 'Out For Delivery', statusName: 'Out For Delivery'),
    OrderStatusData(id: '6', status: 'Delivered', statusName: 'Delivered'),
  ];

  setUp(() {
    filterCubit = MockOrderStatusListFilterCubit();
    orderCubit = MockOrderCubit();
    ecommerceCubit = MockEcommerceOrderCubit();

    whenListen(
      orderCubit,
      const Stream<PaginationState<OrderData>>.empty(),
      initialState: const PaginationInitial<OrderData>(),
    );
    whenListen(
      ecommerceCubit,
      const Stream<PaginationState<EcommerceOrderDataModel>>.empty(),
      initialState: const PaginationInitial<EcommerceOrderDataModel>(),
    );
    when(() => orderCubit.selectedStatus).thenReturn('');
    when(() => orderCubit.startDate).thenReturn(null);
    when(() => orderCubit.endDate).thenReturn(null);
    when(() => orderCubit.hasActiveFilters).thenReturn(false);
    when(() => ecommerceCubit.selectedStatus).thenReturn('');
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpChips(
    WidgetTester tester, {
    required OrderStatusListFilterState filterState,
    bool isEcommerce = false,
    ValueChanged<String>? onStatusChanged,
  }) async {
    whenListen(
      filterCubit,
      const Stream<OrderStatusListFilterState>.empty(),
      initialState: filterState,
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<OrderStatusListFilterCubit>.value(value: filterCubit),
          BlocProvider<OrderCubit>.value(value: orderCubit),
          BlocProvider<EcommerceOrderCubit>.value(value: ecommerceCubit),
        ],
        child: pumpTestWidget(
          OrderStatusChips(
            isEcommerce: isEcommerce,
            onStatusChanged: onStatusChanged ?? (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('OrderStatusChips', () {
    testWidgets('renders a chip per status once they have loaded', (
      tester,
    ) async {
      printTestDivider('renders a chip per status once they have loaded');
      await pumpChips(tester, filterState: OrderStatusListFilterLoaded(statuses));

      printTestLog('chips → expected: 3, actual: ${find.byType(ChoiceChip).evaluate().length}');
      expect(find.byType(ChoiceChip), findsNWidgets(3));
      printTestLog('labels → expected: All / Out For Delivery / Delivered visible');
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
    });

    testWidgets('reserves the row height while the statuses load', (
      tester,
    ) async {
      printTestDivider('reserves the row height while the statuses load');
      // A placeholder of the same height keeps the list below from jumping
      // once the chips appear.
      await pumpChips(tester, filterState: const OrderStatusListFilterLoading());

      printTestLog('chips → expected: none, actual: ${find.byType(ChoiceChip).evaluate().length}');
      expect(find.byType(ChoiceChip), findsNothing);
      final box = tester.getSize(find.byType(SizedBox).first);
      printTestLog('placeholder height → expected: 44.0, actual: ${box.height}');
      expect(box.height, 44.0);
    });

    testWidgets('marks the chip matching the quick-order cubit as selected', (
      tester,
    ) async {
      printTestDivider('marks the chip matching the quick-order cubit as selected');
      when(() => orderCubit.selectedStatus).thenReturn('6');
      await pumpChips(tester, filterState: OrderStatusListFilterLoaded(statuses));

      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      printTestLog('selected states → expected: [false, false, true], actual: ${chips.map((c) => c.selected).toList()}');
      expect(chips.map((c) => c.selected).toList(), [false, false, true]);
    });

    testWidgets('reads the selection from the ecommerce cubit in that mode', (
      tester,
    ) async {
      printTestDivider('reads the selection from the ecommerce cubit in that mode');
      // The two lists keep independent filters, so the ecommerce tab must not
      // read the quick-order cubit's selection.
      when(() => orderCubit.selectedStatus).thenReturn('6');
      when(() => ecommerceCubit.selectedStatus).thenReturn('5');
      await pumpChips(
        tester,
        filterState: OrderStatusListFilterLoaded(statuses),
        isEcommerce: true,
      );

      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      printTestLog('selected states → expected: [false, true, false], actual: ${chips.map((c) => c.selected).toList()}');
      expect(chips.map((c) => c.selected).toList(), [false, true, false]);
    });

    testWidgets('reports the tapped status id', (tester) async {
      printTestDivider('reports the tapped status id');
      String? picked;
      await pumpChips(
        tester,
        filterState: OrderStatusListFilterLoaded(statuses),
        onStatusChanged: (id) => picked = id,
      );

      await tester.tap(find.text('Delivered'));
      await tester.pump();

      printTestLog('picked → expected: "6", actual: "$picked"');
      expect(picked, '6');
    });

    testWidgets('reports an empty id for the All chip', (tester) async {
      printTestDivider('reports an empty id for the All chip');
      // An empty id is what the list cubits treat as "no status filter".
      String? picked;
      await pumpChips(
        tester,
        filterState: OrderStatusListFilterLoaded(statuses),
        onStatusChanged: (id) => picked = id,
      );

      await tester.tap(find.text('All'));
      await tester.pump();

      printTestLog('picked → expected: "", actual: "$picked"');
      expect(picked, '');
    });
  });

  group('DateFilterActions', () {
    Future<void> pumpActions(
      WidgetTester tester, {
      VoidCallback? onPickDate,
      VoidCallback? onClear,
    }) async {
      await tester.pumpWidget(
        BlocProvider<OrderCubit>.value(
          value: orderCubit,
          child: pumpTestWidget(
            DateFilterActions(
              onPickDate: onPickDate ?? () {},
              onClear: onClear ?? () {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('offers only the date picker when no filter is active', (
      tester,
    ) async {
      printTestDivider('offers only the date picker when no filter is active');
      await pumpActions(tester);

      printTestLog('date button → expected: 1, actual: ${find.byType(IconButton).evaluate().length}');
      expect(find.byType(IconButton), findsOneWidget);
      // Targeted by tooltip, not by InkWell: IconButton builds an InkWell of
      // its own, so find.byType(InkWell) matches the date button too.
      printTestLog('clear button → expected: absent, actual: ${find.byTooltip(LanguageLabelKeys.clear).evaluate().length}');
      expect(find.byTooltip(LanguageLabelKeys.clear), findsNothing);
    });

    testWidgets('adds a clear action once any filter is active', (tester) async {
      printTestDivider('adds a clear action once any filter is active');
      when(() => orderCubit.hasActiveFilters).thenReturn(true);
      await pumpActions(tester);

      printTestLog('clear button → expected: present, actual: ${find.byTooltip(LanguageLabelKeys.clear).evaluate().length}');
      expect(find.byTooltip(LanguageLabelKeys.clear), findsOneWidget);
    });

    testWidgets('invokes onPickDate when the date button is tapped', (
      tester,
    ) async {
      printTestDivider('invokes onPickDate when the date button is tapped');
      var picked = false;
      await pumpActions(tester, onPickDate: () => picked = true);

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      printTestLog('onPickDate called → expected: true, actual: $picked');
      expect(picked, isTrue);
    });

    testWidgets('invokes onClear when the clear action is tapped', (
      tester,
    ) async {
      printTestDivider('invokes onClear when the clear action is tapped');
      when(() => orderCubit.hasActiveFilters).thenReturn(true);
      var cleared = false;
      await pumpActions(tester, onClear: () => cleared = true);

      await tester.tap(find.byTooltip(LanguageLabelKeys.clear));
      await tester.pump();

      printTestLog('onClear called → expected: true, actual: $cleared');
      expect(cleared, isTrue);
    });

    testWidgets('shows the active date range in the button tooltip', (
      tester,
    ) async {
      printTestDivider('shows the active date range in the button tooltip');
      when(() => orderCubit.startDate).thenReturn('2026-08-01');
      when(() => orderCubit.endDate).thenReturn('2026-08-17');
      await pumpActions(tester);

      final button = tester.widget<IconButton>(find.byType(IconButton));
      printTestLog('tooltip → expected: "2026-08-01 → 2026-08-17", actual: "${button.tooltip}"');
      expect(button.tooltip, '2026-08-01 → 2026-08-17');
    });
  });
}
