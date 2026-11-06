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
import 'package:customer/core/api/hive_box_keys.dart';
import 'package:customer/features/blog/cubit/blog_category_cubit.dart';
import 'package:customer/features/blog/cubit/blog_cubit.dart';
import 'package:customer/features/blog/models/blog_model.dart';
import 'package:customer/features/blog/screens/blog_screen.dart';
import 'package:customer/features/blog/widgets/blog_card.dart';
import 'package:customer/features/blog/widgets/blog_list_skeleton_loader.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockBlogCubit cubit;
  late MockBlogCategoryCubit categoryCubit;
  late MockConnectivityCubit connectivityCubit;
  late List<Blog> entries;

  setUpAll(() async {
    // BlogCard formats `createdAt` via AppDateFormatter, which needs a real
    // Hive settings box open.
    await HiveTestHelper.setUp(settingsBox);
  });

  tearDownAll(() async {
    await HiveTestHelper.tearDown(settingsBox);
    printTestDivider('=== All tests run! ===');
  });

  setUp(() {
    entries = List.generate(
      3,
      (i) => Blog.fromJson({'id': '${i + 1}', 'title': 'Blog ${i + 1}'}),
    );

    cubit = MockBlogCubit();
    categoryCubit = MockBlogCategoryCubit();
    connectivityCubit = MockConnectivityCubit();

    when(() => cubit.loadBlogs()).thenReturn(null);
    when(() => cubit.fetchMore()).thenAnswer((_) async {});
    when(() => categoryCubit.loadCategories()).thenAnswer((_) async {});
    when(() => connectivityCubit.recheck()).thenAnswer((_) async {});
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    PaginationState<Blog>? state,
    BlogCategoryState? categoryState,
    ConnectivityState? connectivity,
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;

    whenListen(
      cubit,
      const Stream<PaginationState<Blog>>.empty(),
      initialState: state ?? PaginationLoaded<Blog>(data: entries, total: 3),
    );
    whenListen(
      categoryCubit,
      const Stream<BlogCategoryState>.empty(),
      initialState: categoryState ?? BlogCategoryLoaded(const []),
    );
    whenListen(
      connectivityCubit,
      const Stream<ConnectivityState>.empty(),
      initialState: connectivity ?? ConnectivityConnected(),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<BlogCubit>.value(value: cubit),
          BlocProvider<BlogCategoryCubit>.value(value: categoryCubit),
          BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
        ],
        // BlogScreen builds its own AppScaffold.
        child: pumpTestWidget(const BlogScreen(), wrapInScaffold: false),
      ),
    );
    await tester.pump();
  }

  testWidgets('fetches categories and the first page of blogs on first build', (
    tester,
  ) async {
    printTestDivider(
      'fetches categories and the first page of blogs on first build',
    );
    await pumpScreen(tester);

    verify(() => categoryCubit.loadCategories()).called(1);
    verify(() => cubit.loadBlogs()).called(1);
    printTestLog('both initial fetches → verified');
  });

  testWidgets('shows the skeleton while loading', (tester) async {
    printTestDivider('shows the skeleton while loading');
    await pumpScreen(tester, state: const PaginationLoading<Blog>());

    printTestLog(
      'skeleton → expected: 1, actual: ${find.byType(BlogListSkeletonLoader).evaluate().length}',
    );
    expect(find.byType(BlogListSkeletonLoader), findsOneWidget);
    printTestLog(
      'cards → expected: 0, actual: ${find.byType(BlogCard).evaluate().length}',
    );
    expect(find.byType(BlogCard), findsNothing);
  });

  testWidgets(
    'the initial (pre-fetch) state also triggers loadBlogs() from build, then shows the skeleton',
    (tester) async {
      printTestDivider(
        'the initial (pre-fetch) state also triggers loadBlogs() from build, then shows the skeleton',
      );
      await pumpScreen(tester, state: const PaginationInitial<Blog>());

      // Once from initState, once from the PaginationInitial branch in build().
      verify(() => cubit.loadBlogs()).called(2);
      printTestLog(
        'skeleton → expected: 1, actual: ${find.byType(BlogListSkeletonLoader).evaluate().length}',
      );
      expect(find.byType(BlogListSkeletonLoader), findsOneWidget);
    },
  );

  testWidgets('shows the loaded list of blog cards', (tester) async {
    printTestDivider('shows the loaded list of blog cards');
    await pumpScreen(tester);

    printTestLog(
      'cards → expected: ${entries.length}, actual: ${find.byType(BlogCard).evaluate().length}',
    );
    expect(find.byType(BlogCard), findsNWidgets(entries.length));
  });

  testWidgets('shows the empty state when the loaded list is empty', (
    tester,
  ) async {
    printTestDivider('shows the empty state when the loaded list is empty');
    await pumpScreen(
      tester,
      state: const PaginationLoaded<Blog>(data: [], total: 0),
    );

    printTestLog(
      'empty state → expected: 1, actual: ${find.byType(EmptyStateWidget).evaluate().length}',
    );
    expect(find.byType(EmptyStateWidget), findsOneWidget);
    printTestLog(
      'cards → expected: 0, actual: ${find.byType(BlogCard).evaluate().length}',
    );
    expect(find.byType(BlogCard), findsNothing);
  });

  testWidgets('shows the error state with the API message when the list fails', (
    tester,
  ) async {
    printTestDivider(
      'shows the error state with the API message when the list fails',
    );
    await pumpScreen(
      tester,
      state: const PaginationError<Blog>('Blogs unavailable'),
    );

    printTestLog(
      'empty state → expected: 1, actual: ${find.byType(EmptyStateWidget).evaluate().length}',
    );
    expect(find.byType(EmptyStateWidget), findsOneWidget);
    printTestLog('message → expected: "Blogs unavailable" visible');
    expect(find.text('Blogs unavailable'), findsOneWidget);
  });

  testWidgets('retry on the error state calls loadBlogs(), not refresh()', (
    tester,
  ) async {
    printTestDivider(
      'retry on the error state calls loadBlogs(), not refresh()',
    );
    await pumpScreen(
      tester,
      state: const PaginationError<Blog>('Blogs unavailable'),
    );
    // Consume the initial-build call before asserting the retry-triggered one.
    clearInteractions(cubit);

    final emptyState = tester.widget<EmptyStateWidget>(
      find.byType(EmptyStateWidget),
    );
    emptyState.onRetry!();
    await tester.pump();

    verify(() => cubit.loadBlogs()).called(1);
    verifyNever(() => cubit.refresh());
    printTestLog('loadBlogs() retry (not refresh()) → verified');
  });

  testWidgets('replaces the body with the offline view when disconnected', (
    tester,
  ) async {
    printTestDivider(
      'replaces the body with the offline view when disconnected',
    );
    await pumpScreen(tester, connectivity: ConnectivityDisconnected());

    printTestLog(
      'offline view → expected: 1, actual: ${find.byType(AppNoInternetView).evaluate().length}',
    );
    expect(find.byType(AppNoInternetView), findsOneWidget);
    printTestLog(
      'cards → expected: 0, actual: ${find.byType(BlogCard).evaluate().length}',
    );
    expect(find.byType(BlogCard), findsNothing);
  });

  testWidgets('reconnecting re-fires both loadCategories() and loadBlogs()', (
    tester,
  ) async {
    printTestDivider(
      'reconnecting re-fires both loadCategories() and loadBlogs()',
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;

    whenListen(
      cubit,
      const Stream<PaginationState<Blog>>.empty(),
      initialState: PaginationLoaded<Blog>(data: entries, total: 3),
    );
    whenListen(
      categoryCubit,
      const Stream<BlogCategoryState>.empty(),
      initialState: BlogCategoryLoaded(const []),
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
          BlocProvider<BlogCubit>.value(value: cubit),
          BlocProvider<BlogCategoryCubit>.value(value: categoryCubit),
          BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
        ],
        child: pumpTestWidget(const BlogScreen(), wrapInScaffold: false),
      ),
    );
    await tester.pump();
    clearInteractions(cubit);
    clearInteractions(categoryCubit);

    connectivityController.add(ConnectivityConnected());
    await tester.pump();

    verify(() => categoryCubit.loadCategories()).called(1);
    verify(() => cubit.loadBlogs()).called(1);
    printTestLog('reload of both cubits on reconnect → verified');
  });
}
