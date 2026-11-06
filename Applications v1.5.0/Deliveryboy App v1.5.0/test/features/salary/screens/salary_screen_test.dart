import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/commons/widgets/list_skeleton_loader.dart';
import 'package:deliveryboy/features/salary/cubit/salary_cubit.dart';
import 'package:deliveryboy/features/salary/models/salary_model.dart';
import 'package:deliveryboy/features/salary/screens/salary_screen.dart';
import 'package:deliveryboy/features/salary/widgets/salary_card.dart';

import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockSalaryCubit cubit;
  late MockConnectivityCubit connectivityCubit;
  late List<SalaryModel> entries;

  setUp(() {
    entries = List.generate(
      3,
      (i) => SalaryModel.fromJson({
        'id': i + 1,
        'amount': (i + 1) * 1000.0,
        'currency': '₹',
      }),
    );

    cubit = MockSalaryCubit();
    connectivityCubit = MockConnectivityCubit();

    when(() => cubit.loadSalaries()).thenAnswer((_) async {});
    when(() => cubit.loadMore()).thenAnswer((_) async {});
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpScreen(
    WidgetTester tester, {
    PaginationState<SalaryModel>? state,
    ConnectivityState? connectivity,
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;

    whenListen(
      cubit,
      const Stream<PaginationState<SalaryModel>>.empty(),
      initialState:
          state ?? PaginationLoaded<SalaryModel>(data: entries, total: 3),
    );
    whenListen(
      connectivityCubit,
      const Stream<ConnectivityState>.empty(),
      initialState: connectivity ?? ConnectivityConnected(),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SalaryCubit>.value(value: cubit),
          BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
        ],
        // SalaryScreen builds its own AppScaffold.
        child: pumpTestWidget(const SalaryScreen(), wrapInScaffold: false),
      ),
    );
    await tester.pump();
  }

  testWidgets('loads salaries on first build', (tester) async {
    printTestDivider('loads salaries on first build');
    await pumpScreen(tester);

    verify(() => cubit.loadSalaries()).called(1);
    printTestLog('initial load → verified');
  });

  testWidgets('shows the skeleton while loading', (tester) async {
    printTestDivider('shows the skeleton while loading');
    await pumpScreen(
      tester,
      state: const PaginationLoading<SalaryModel>(),
    );

    printTestLog(
      'skeleton → expected: 1, actual: ${find.byType(ListSkeletonLoader).evaluate().length}',
    );
    expect(find.byType(ListSkeletonLoader), findsOneWidget);
    printTestLog(
      'cards → expected: 0, actual: ${find.byType(SalaryCard).evaluate().length}',
    );
    expect(find.byType(SalaryCard), findsNothing);
  });

  testWidgets('shows the loaded list', (tester) async {
    printTestDivider('shows the loaded list');
    await pumpScreen(tester);

    printTestLog(
      'cards → expected: ${entries.length}, actual: ${find.byType(SalaryCard).evaluate().length}',
    );
    expect(find.byType(SalaryCard), findsNWidgets(entries.length));
  });

  testWidgets('shows the error state with a retry when the list fails', (
    tester,
  ) async {
    printTestDivider('shows the error state with a retry when the list fails');
    await pumpScreen(
      tester,
      state: const PaginationError<SalaryModel>('Salary payments unavailable'),
    );

    printTestLog(
      'empty state → expected: 1, actual: ${find.byType(EmptyStateWidget).evaluate().length}',
    );
    expect(find.byType(EmptyStateWidget), findsOneWidget);
    printTestLog('message → expected: "Salary payments unavailable" visible');
    expect(find.text('Salary payments unavailable'), findsOneWidget);
  });

  testWidgets('retry on the error state refetches the list', (tester) async {
    printTestDivider('retry on the error state refetches the list');
    await pumpScreen(
      tester,
      state: const PaginationError<SalaryModel>('Salary payments unavailable'),
    );

    final emptyState = tester.widget<EmptyStateWidget>(
      find.byType(EmptyStateWidget),
    );
    emptyState.onRetry!();
    await tester.pump();

    // Once from initState, once from the retry.
    verify(() => cubit.loadSalaries()).called(2);
    printTestLog('refetch → verified');
  });

  testWidgets('replaces the body with the offline screen when disconnected', (
    tester,
  ) async {
    printTestDivider('replaces the body with the offline screen when disconnected');
    await pumpScreen(tester, connectivity: ConnectivityDisconnected());

    printTestLog(
      'offline screen → expected: 1, actual: ${find.byType(AppNoInternetFullScreen).evaluate().length}',
    );
    expect(find.byType(AppNoInternetFullScreen), findsOneWidget);
    printTestLog(
      'cards → expected: 0, actual: ${find.byType(SalaryCard).evaluate().length}',
    );
    expect(find.byType(SalaryCard), findsNothing);
  });

  testWidgets('offline retry calls loadSalaries', (tester) async {
    printTestDivider('offline retry calls loadSalaries');
    await pumpScreen(tester, connectivity: ConnectivityDisconnected());

    final offlineScreen = tester.widget<AppNoInternetFullScreen>(
      find.byType(AppNoInternetFullScreen),
    );
    offlineScreen.onRetry!();
    await tester.pump();

    // Once from initState, once from the offline retry.
    verify(() => cubit.loadSalaries()).called(2);
    printTestLog('offline retry → verified');
  });

  testWidgets('reconnecting triggers a reload', (tester) async {
    printTestDivider('reconnecting triggers a reload');
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;

    whenListen(
      cubit,
      const Stream<PaginationState<SalaryModel>>.empty(),
      initialState: PaginationLoaded<SalaryModel>(data: entries, total: 3),
    );
    final connectivityController = StreamController<ConnectivityState>();
    addTearDown(connectivityController.close);
    whenListen(
      connectivityCubit,
      connectivityController.stream,
      initialState: ConnectivityDisconnected(),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SalaryCubit>.value(value: cubit),
          BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
        ],
        child: pumpTestWidget(const SalaryScreen(), wrapInScaffold: false),
      ),
    );
    await tester.pump();

    connectivityController.add(ConnectivityConnected());
    await tester.pump();

    // Once from initState, once from the listener firing on reconnect.
    verify(() => cubit.loadSalaries()).called(2);
    printTestLog('reload on reconnect → verified');
  });
}
