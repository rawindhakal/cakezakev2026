import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/cubit/connectivity_cubit.dart';
import 'package:customer/commons/widgets/app_no_internet_widget.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/features/faq/cubit/faq_cubit.dart';
import 'package:customer/features/faq/models/faq_model.dart';
import 'package:customer/features/faq/screens/faq_screen.dart';
import 'package:customer/features/faq/widgets/faq_list_skeleton_loader.dart';
import 'package:customer/features/faq/widgets/faq_tile.dart';

import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockFaqCubit cubit;
  late MockConnectivityCubit connectivityCubit;
  late List<FaqData> entries;

  setUp(() {
    entries = List.generate(
      3,
      (i) => FaqData.fromJson({
        'id': '${i + 1}',
        'question': 'Question ${i + 1}',
        'answer': 'Answer ${i + 1}',
      }),
    );

    cubit = MockFaqCubit();
    connectivityCubit = MockConnectivityCubit();

    when(() => cubit.fetchInitial()).thenAnswer((_) async {});
    when(() => cubit.fetchMore()).thenAnswer((_) async {});
    when(() => cubit.refresh()).thenAnswer((_) async {});
    when(() => connectivityCubit.recheck()).thenAnswer((_) async {});
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpScreen(
    WidgetTester tester, {
    PaginationState<FaqData>? state,
    ConnectivityState? connectivity,
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;

    whenListen(
      cubit,
      const Stream<PaginationState<FaqData>>.empty(),
      initialState: state ?? PaginationLoaded<FaqData>(data: entries, total: 3),
    );
    whenListen(
      connectivityCubit,
      const Stream<ConnectivityState>.empty(),
      initialState: connectivity ?? ConnectivityConnected(),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<FaqCubit>.value(value: cubit),
          BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
        ],
        // FaqScreen builds its own AppScaffold.
        child: pumpTestWidget(const FaqScreen(), wrapInScaffold: false),
      ),
    );
    await tester.pump();
  }

  testWidgets('fetches the first page on first build', (tester) async {
    printTestDivider('fetches the first page on first build');
    await pumpScreen(tester);

    verify(() => cubit.fetchInitial()).called(1);
    printTestLog('initial fetch → verified');
  });

  testWidgets('shows the skeleton while loading', (tester) async {
    printTestDivider('shows the skeleton while loading');
    await pumpScreen(tester, state: const PaginationLoading<FaqData>());

    printTestLog(
      'skeleton → expected: 1, actual: ${find.byType(FaqListSkeletonLoader).evaluate().length}',
    );
    expect(find.byType(FaqListSkeletonLoader), findsOneWidget);
    printTestLog(
      'tiles → expected: 0, actual: ${find.byType(FaqTile).evaluate().length}',
    );
    expect(find.byType(FaqTile), findsNothing);
  });

  testWidgets('shows the loaded list', (tester) async {
    printTestDivider('shows the loaded list');
    await pumpScreen(tester);

    printTestLog(
      'tiles → expected: ${entries.length}, actual: ${find.byType(FaqTile).evaluate().length}',
    );
    expect(find.byType(FaqTile), findsNWidgets(entries.length));
  });

  testWidgets('shows the empty state when the loaded list is empty', (
    tester,
  ) async {
    printTestDivider('shows the empty state when the loaded list is empty');
    await pumpScreen(
      tester,
      state: const PaginationLoaded<FaqData>(data: [], total: 0),
    );

    printTestLog(
      'empty state → expected: 1, actual: ${find.byType(EmptyStateWidget).evaluate().length}',
    );
    expect(find.byType(EmptyStateWidget), findsOneWidget);
    printTestLog(
      'tiles → expected: 0, actual: ${find.byType(FaqTile).evaluate().length}',
    );
    expect(find.byType(FaqTile), findsNothing);
  });

  testWidgets('shows the error state with a retry when the list fails', (
    tester,
  ) async {
    printTestDivider('shows the error state with a retry when the list fails');
    await pumpScreen(
      tester,
      state: const PaginationError<FaqData>('Faqs unavailable'),
    );

    printTestLog(
      'empty state → expected: 1, actual: ${find.byType(EmptyStateWidget).evaluate().length}',
    );
    expect(find.byType(EmptyStateWidget), findsOneWidget);
    printTestLog('message → expected: "Faqs unavailable" visible');
    expect(find.text('Faqs unavailable'), findsOneWidget);
  });

  testWidgets('retry on the error state refetches the list', (tester) async {
    printTestDivider('retry on the error state refetches the list');
    await pumpScreen(
      tester,
      state: const PaginationError<FaqData>('Faqs unavailable'),
    );

    final emptyState = tester.widget<EmptyStateWidget>(
      find.byType(EmptyStateWidget),
    );
    emptyState.onRetry!();
    await tester.pump();

    // The error retry calls refresh(), not fetchInitial() again.
    verify(() => cubit.refresh()).called(1);
    printTestLog('refetch → verified');
  });

  testWidgets('replaces the body with the offline view when disconnected', (
    tester,
  ) async {
    printTestDivider('replaces the body with the offline view when disconnected');
    await pumpScreen(tester, connectivity: ConnectivityDisconnected());

    printTestLog(
      'offline view → expected: 1, actual: ${find.byType(AppNoInternetView).evaluate().length}',
    );
    expect(find.byType(AppNoInternetView), findsOneWidget);
    printTestLog(
      'tiles → expected: 0, actual: ${find.byType(FaqTile).evaluate().length}',
    );
    expect(find.byType(FaqTile), findsNothing);
  });

  testWidgets('reconnecting triggers a reload', (tester) async {
    printTestDivider('reconnecting triggers a reload');
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;

    whenListen(
      cubit,
      const Stream<PaginationState<FaqData>>.empty(),
      initialState: PaginationLoaded<FaqData>(data: entries, total: 3),
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
          BlocProvider<FaqCubit>.value(value: cubit),
          BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
        ],
        child: pumpTestWidget(const FaqScreen(), wrapInScaffold: false),
      ),
    );
    await tester.pump();

    connectivityController.add(ConnectivityConnected());
    await tester.pump();

    // Once from initState, once from the listener firing on reconnect.
    verify(() => cubit.fetchInitial()).called(2);
    printTestLog('reload on reconnect → verified');
  });
}
