import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/blog/cubit/blog_category_cubit.dart';
import 'package:customer/features/blog/models/blog_category_model.dart';

import '../../../helpers/mock_blog_repository.dart';
import '../../../helpers/test_logging.dart';

/// BlogCategoryCubit is a plain Cubit + ApiErrorGuard, not a
/// BasePaginationCubit — unlike BlogCubit it gets no free coverage from
/// base_pagination_cubit_test.dart, so this suite owns its full
/// state-transition surface.
void main() {
  late MockBlogRepository repository;

  setUp(() => repository = MockBlogRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  BlogCategory category(String id) =>
      BlogCategory.fromJson({'id': id, 'name': 'cat$id'});

  test('initial state is BlogCategoryInitial before loadCategories is called', () {
    printTestDivider(
      'BlogCategoryCubit initial state is BlogCategoryInitial before loadCategories is called',
    );
    final cubit = BlogCategoryCubit(repository: repository);

    printTestLog(
      'state → expected: BlogCategoryInitial, actual: ${cubit.state.runtimeType}',
    );
    expect(cubit.state, isA<BlogCategoryInitial>());
    cubit.close();
  });

  blocTest<BlogCategoryCubit, BlogCategoryState>(
    'loadCategories emits Loading then Loaded with the response categories',
    setUp: () {
      when(() => repository.getBlogCategories()).thenAnswer(
        (_) async => BlogCategoryResponse(
          status: '1',
          data: [category('1'), category('2')],
        ),
      );
    },
    build: () => BlogCategoryCubit(repository: repository),
    act: (cubit) => cubit.loadCategories(),
    expect: () => [
      isA<BlogCategoryLoading>(),
      isA<BlogCategoryLoaded>().having(
        (s) => s.categories.length,
        'categories.length',
        2,
      ),
    ],
  );

  blocTest<BlogCategoryCubit, BlogCategoryState>(
    'loadCategories a null response data falls back to an empty list, not crash',
    setUp: () {
      when(() => repository.getBlogCategories()).thenAnswer(
        (_) async => BlogCategoryResponse(status: '1', data: null),
      );
    },
    build: () => BlogCategoryCubit(repository: repository),
    act: (cubit) => cubit.loadCategories(),
    expect: () => [
      isA<BlogCategoryLoading>(),
      isA<BlogCategoryLoaded>().having(
        (s) => s.categories,
        'categories',
        isEmpty,
      ),
    ],
  );

  blocTest<BlogCategoryCubit, BlogCategoryState>(
    'loadCategories surfaces the ApiException message on failure',
    setUp: () {
      when(
        () => repository.getBlogCategories(),
      ).thenThrow(const ApiException(message: 'Categories unavailable'));
    },
    build: () => BlogCategoryCubit(repository: repository),
    act: (cubit) => cubit.loadCategories(),
    expect: () => [
      isA<BlogCategoryLoading>(),
      isA<BlogCategoryError>().having(
        (s) => s.message,
        'message',
        'Categories unavailable',
      ),
    ],
  );

  blocTest<BlogCategoryCubit, BlogCategoryState>(
    'loadCategories on a non-ApiException error emits the generic error message',
    setUp: () {
      when(() => repository.getBlogCategories()).thenThrow(Exception('boom'));
    },
    build: () => BlogCategoryCubit(repository: repository),
    act: (cubit) => cubit.loadCategories(),
    expect: () => [
      isA<BlogCategoryLoading>(),
      isA<BlogCategoryError>(),
    ],
  );
}
