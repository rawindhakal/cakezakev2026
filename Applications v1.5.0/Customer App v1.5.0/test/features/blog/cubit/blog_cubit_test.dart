import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/features/blog/cubit/blog_cubit.dart';
import 'package:customer/features/blog/models/blog_model.dart';

import '../../../helpers/mock_blog_repository.dart';
import '../../../helpers/test_logging.dart';

/// BlogCubit is a `FilteredPaginationCubit<Blog, String?>` — the base's
/// fetchInitial/fetchMore/loading/error mechanics are covered once in
/// test/commons/cubit/base_pagination_cubit_test.dart, so these tests focus
/// only on what BlogCubit adds: wiring its fetcher to
/// BlogRepository.getBlogs with the active category filter, turning the
/// response's string `total` into an int, and its page-length based
/// computeHasMore override.
void main() {
  late MockBlogRepository repository;

  setUp(() => repository = MockBlogRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Blog entry(String id) => Blog.fromJson({'id': id, 'title': 't$id'});

  void stubGetBlogs(List<Blog> data, {String? total}) {
    when(
      () => repository.getBlogs(
        offset: any(named: 'offset'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer(
      (_) async => BlogResponse(status: '1', total: total, data: data),
    );
  }

  test(
    'loadBlogs fetches offset 0 with no category filter and maps data/total from the response',
    () async {
      printTestDivider(
        'BlogCubit loadBlogs fetches offset 0 with no category filter and maps data/total from the response',
      );
      stubGetBlogs([entry('1'), entry('2')], total: '5');
      final cubit = BlogCubit(repository: repository);

      cubit.loadBlogs();
      await pumpEventQueue();

      verify(() => repository.getBlogs(offset: 0, categoryId: null)).called(1);
      final state = cubit.state as PaginationLoaded<Blog>;
      printTestLog('data length → expected: 2, actual: ${state.data.length}');
      expect(state.data.length, 2);
      printTestLog('total → expected: 5, actual: ${state.total}');
      expect(state.total, 5);
      await cubit.close();
    },
  );

  test('a non-numeric response total falls back to 0 rather than crashing', () async {
    printTestDivider(
      'BlogCubit a non-numeric response total falls back to 0 rather than crashing',
    );
    stubGetBlogs([], total: 'not-a-number');
    final cubit = BlogCubit(repository: repository);

    cubit.loadBlogs();
    await pumpEventQueue();

    final state = cubit.state as PaginationLoaded<Blog>;
    printTestLog('total → expected: 0, actual: ${state.total}');
    expect(state.total, 0);
    await cubit.close();
  });

  test('a null response total falls back to 0 rather than crashing', () async {
    printTestDivider(
      'BlogCubit a null response total falls back to 0 rather than crashing',
    );
    stubGetBlogs([], total: null);
    final cubit = BlogCubit(repository: repository);

    cubit.loadBlogs();
    await pumpEventQueue();

    final state = cubit.state as PaginationLoaded<Blog>;
    printTestLog('total → expected: 0, actual: ${state.total}');
    expect(state.total, 0);
    await cubit.close();
  });

  test('a null response data falls back to an empty list', () async {
    printTestDivider('BlogCubit a null response data falls back to an empty list');
    when(
      () => repository.getBlogs(
        offset: any(named: 'offset'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => BlogResponse(status: '1', total: '0', data: null));
    final cubit = BlogCubit(repository: repository);

    cubit.loadBlogs();
    await pumpEventQueue();

    final state = cubit.state as PaginationLoaded<Blog>;
    printTestLog('data → expected: [], actual: ${state.data}');
    expect(state.data, isEmpty);
    await cubit.close();
  });

  test(
    'computeHasMore is page-length based: a full page reports hasMore true even if total says otherwise',
    () async {
      printTestDivider(
        'BlogCubit computeHasMore is page-length based: a full page reports hasMore true even if total says otherwise',
      );
      final fullPage = List.generate(
        AppConfig.pageLimit,
        (i) => entry('$i'),
      );
      stubGetBlogs(fullPage, total: '1');
      final cubit = BlogCubit(repository: repository);

      cubit.loadBlogs();
      await pumpEventQueue();

      final state = cubit.state as PaginationLoaded<Blog>;
      printTestLog('hasMore → expected: true, actual: ${state.hasMore}');
      expect(state.hasMore, isTrue);
      await cubit.close();
    },
  );

  test(
    'computeHasMore reports hasMore false when a page returns fewer than pageLimit items',
    () async {
      printTestDivider(
        'BlogCubit computeHasMore reports hasMore false when a page returns fewer than pageLimit items',
      );
      stubGetBlogs([entry('1')], total: '999');
      final cubit = BlogCubit(repository: repository);

      cubit.loadBlogs();
      await pumpEventQueue();

      final state = cubit.state as PaginationLoaded<Blog>;
      printTestLog('hasMore → expected: false, actual: ${state.hasMore}');
      expect(state.hasMore, isFalse);
      await cubit.close();
    },
  );

  test('filterByCategory re-fetches from offset 0 with the given category id, replacing the list', () async {
    printTestDivider(
      'BlogCubit filterByCategory re-fetches from offset 0 with the given category id, replacing the list',
    );
    stubGetBlogs([entry('1'), entry('2')], total: '2');
    final cubit = BlogCubit(repository: repository);
    cubit.loadBlogs();
    await pumpEventQueue();

    when(
      () => repository.getBlogs(offset: 0, categoryId: 'cat-1'),
    ).thenAnswer(
      (_) async => BlogResponse(status: '1', total: '1', data: [entry('9')]),
    );

    await cubit.filterByCategory('cat-1');

    verify(() => repository.getBlogs(offset: 0, categoryId: 'cat-1')).called(1);
    printTestLog('currentFilters → expected: "cat-1", actual: ${cubit.currentFilters}');
    expect(cubit.currentFilters, 'cat-1');
    final state = cubit.state as PaginationLoaded<Blog>;
    printTestLog('data → expected: [Blog(id: 9)], actual length: ${state.data.length}');
    expect(state.data, hasLength(1));
    expect(state.data.first.id, '9');
    await cubit.close();
  });

  test('filterByCategory(null) clears back to the unfiltered fetch', () async {
    printTestDivider(
      'BlogCubit filterByCategory(null) clears back to the unfiltered fetch',
    );
    stubGetBlogs([entry('1')], total: '1');
    final cubit = BlogCubit(repository: repository);
    await cubit.filterByCategory('cat-1');

    await cubit.filterByCategory(null);

    verify(() => repository.getBlogs(offset: 0, categoryId: null)).called(1);
    printTestLog('currentFilters → expected: null, actual: ${cubit.currentFilters}');
    expect(cubit.currentFilters, isNull);
    await cubit.close();
  });

  test('surfaces the API message when the list fails', () async {
    printTestDivider('BlogCubit surfaces the API message when the list fails');
    when(
      () => repository.getBlogs(
        offset: any(named: 'offset'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenThrow(const ApiException(message: 'Blogs unavailable'));
    final cubit = BlogCubit(repository: repository);

    cubit.loadBlogs();
    await pumpEventQueue();

    final state = cubit.state as PaginationError<Blog>;
    printTestLog(
      'message → expected: "Blogs unavailable", actual: "${state.message}"',
    );
    expect(state.message, 'Blogs unavailable');
    await cubit.close();
  });
}
