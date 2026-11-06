import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/features/blog/repositories/blog_repository.dart';

import '../../../helpers/mock_api_client.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockApiClient mockApiClient;
  late BlogRepository repository;

  Map<String, dynamic> blogsFixture() =>
      jsonDecode(
            File('test/fixtures/blog/blog_list.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  Map<String, dynamic> categoriesFixture() =>
      jsonDecode(
            File(
              'test/fixtures/blog/blog_category_list.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = BlogRepository(apiClient: mockApiClient);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  void stubGet(String endpoint, Map<String, dynamic> response) {
    when(
      () => mockApiClient.get(
        endpoint,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => response);
  }

  Map<String, dynamic> capturedQuery(String endpoint) =>
      verify(
            () => mockApiClient.get(
              endpoint,
              queryParameters: captureAny(named: 'queryParameters'),
            ),
          ).captured.single
          as Map<String, dynamic>;

  group('getBlogCategories', () {
    test('hits the blog categories endpoint with no query params', () async {
      printTestDivider(
        'getBlogCategories hits the blog categories endpoint with no query params',
      );
      when(
        () => mockApiClient.get(ApiEndpoints.blogCategories),
      ).thenAnswer((_) async => categoriesFixture());

      final response = await repository.getBlogCategories();

      verify(() => mockApiClient.get(ApiEndpoints.blogCategories)).called(1);
      printTestLog(
        'data length → expected: 2, actual: ${response.data?.length}',
      );
      expect(response.data, hasLength(2));
    });

    test('a null data block returns an empty list without crashing', () async {
      printTestDivider(
        'getBlogCategories a null data block returns an empty list without crashing',
      );
      when(() => mockApiClient.get(ApiEndpoints.blogCategories)).thenAnswer(
        (_) async => {'status': '1', 'data': null},
      );

      final response = await repository.getBlogCategories();

      printTestLog('data → expected: [], actual: ${response.data}');
      expect(response.data, isEmpty);
    });

    test('rethrows an ApiException as-is', () async {
      printTestDivider('getBlogCategories rethrows an ApiException as-is');
      when(
        () => mockApiClient.get(ApiEndpoints.blogCategories),
      ).thenThrow(const ApiException(message: 'Categories unavailable'));

      printTestLog(
        'call → expected: throws ApiException("Categories unavailable")',
      );
      await expectLater(
        () => repository.getBlogCategories(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Categories unavailable',
          ),
        ),
      );
    });

    test('wraps a non-ApiException error via ApiException.fromDioError', () async {
      printTestDivider(
        'getBlogCategories wraps a non-ApiException error via ApiException.fromDioError',
      );
      when(
        () => mockApiClient.get(ApiEndpoints.blogCategories),
      ).thenThrow(Exception('boom'));

      printTestLog('call → expected: throws ApiException (wrapped)');
      await expectLater(
        () => repository.getBlogCategories(),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('getBlogs', () {
    test('hits the blogs endpoint and sends offset/limit by default', () async {
      printTestDivider(
        'getBlogs hits the blogs endpoint and sends offset/limit by default',
      );
      stubGet(ApiEndpoints.blogs, blogsFixture());

      final response = await repository.getBlogs();

      final query = capturedQuery(ApiEndpoints.blogs);
      printTestLog(
        'offset → expected: 0, actual: ${query[ApiParameters.offset]}',
      );
      expect(query[ApiParameters.offset], 0);
      printTestLog(
        'limit → expected: ${AppConfig.pageLimit}, actual: ${query[ApiParameters.limit]}',
      );
      expect(query[ApiParameters.limit], AppConfig.pageLimit);
      printTestLog(
        'data length → expected: 2, actual: ${response.data?.length}',
      );
      expect(response.data, hasLength(2));
    });

    test('forwards a custom offset/limit', () async {
      printTestDivider('getBlogs forwards a custom offset/limit');
      stubGet(ApiEndpoints.blogs, blogsFixture());

      await repository.getBlogs(offset: 20, limit: 5);

      final query = capturedQuery(ApiEndpoints.blogs);
      printTestLog(
        'offset → expected: 20, actual: ${query[ApiParameters.offset]}',
      );
      expect(query[ApiParameters.offset], 20);
      printTestLog(
        'limit → expected: 5, actual: ${query[ApiParameters.limit]}',
      );
      expect(query[ApiParameters.limit], 5);
    });

    test('a null categoryId is dropped from the query params, not sent as null', () async {
      printTestDivider(
        'getBlogs a null categoryId is dropped from the query params, not sent as null',
      );
      stubGet(ApiEndpoints.blogs, blogsFixture());

      await repository.getBlogs();

      final query = capturedQuery(ApiEndpoints.blogs);
      printTestLog(
        'categoryId key present → expected: false, actual: ${query.containsKey(ApiParameters.categoryId)}',
      );
      expect(query.containsKey(ApiParameters.categoryId), isFalse);
    });

    test('a non-null categoryId is forwarded', () async {
      printTestDivider('getBlogs a non-null categoryId is forwarded');
      stubGet(ApiEndpoints.blogs, blogsFixture());

      await repository.getBlogs(categoryId: '2');

      final query = capturedQuery(ApiEndpoints.blogs);
      printTestLog(
        'categoryId → expected: "2", actual: "${query[ApiParameters.categoryId]}"',
      );
      expect(query[ApiParameters.categoryId], '2');
    });

    test('parses every entry via Blog.fromJson', () async {
      printTestDivider('getBlogs parses every entry via Blog.fromJson');
      stubGet(ApiEndpoints.blogs, blogsFixture());

      final response = await repository.getBlogs();

      final entry = response.data!.first;
      printTestLog(
        'title → expected: "5 Tips for Faster Delivery", actual: "${entry.title}"',
      );
      expect(entry.title, '5 Tips for Faster Delivery');
      printTestLog('category name → expected: "Delivery", actual: "${entry.category?.name}"');
      expect(entry.category?.name, 'Delivery');
    });

    test('a null data block returns an empty list without crashing', () async {
      printTestDivider(
        'getBlogs a null data block returns an empty list without crashing',
      );
      stubGet(ApiEndpoints.blogs, {'status': '1', 'total': '0', 'data': null});

      final response = await repository.getBlogs();

      printTestLog('data → expected: [], actual: ${response.data}');
      expect(response.data, isEmpty);
      printTestLog('total → expected: "0", actual: "${response.total}"');
      expect(response.total, '0');
    });

    test('rethrows an ApiException as-is', () async {
      printTestDivider('getBlogs rethrows an ApiException as-is');
      when(
        () => mockApiClient.get(
          ApiEndpoints.blogs,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(const ApiException(message: 'Blogs unavailable'));

      printTestLog('call → expected: throws ApiException("Blogs unavailable")');
      await expectLater(
        () => repository.getBlogs(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Blogs unavailable',
          ),
        ),
      );
    });

    test('wraps a non-ApiException error via ApiException.fromDioError', () async {
      printTestDivider(
        'getBlogs wraps a non-ApiException error via ApiException.fromDioError',
      );
      when(
        () => mockApiClient.get(
          ApiEndpoints.blogs,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(Exception('boom'));

      printTestLog('call → expected: throws ApiException (wrapped)');
      await expectLater(
        () => repository.getBlogs(),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
