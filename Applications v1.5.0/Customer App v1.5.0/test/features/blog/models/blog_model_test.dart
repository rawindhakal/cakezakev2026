import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/blog/models/blog_model.dart';

import '../../../helpers/test_logging.dart';

void main() {
  Map<String, dynamic> fixture() =>
      jsonDecode(
            File('test/fixtures/blog/blog_list.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('BlogResponse.fromJson', () {
    test('parses the envelope and every entry from a full real payload', () {
      printTestDivider(
        'BlogResponse.fromJson parses the envelope and every entry from a full real payload',
      );
      final response = BlogResponse.fromJson(fixture());

      printTestLog('status → expected: "1", actual: "${response.status}"');
      expect(response.status, '1');
      printTestLog(
        'message → expected: "Blogs found", actual: "${response.message}"',
      );
      expect(response.message, 'Blogs found');
      printTestLog('total → expected: "2", actual: "${response.total}"');
      expect(response.total, '2');
      printTestLog(
        'data length → expected: 2, actual: ${response.data?.length}',
      );
      expect(response.data, hasLength(2));
      printTestLog(
        'first title → expected: "5 Tips for Faster Delivery", actual: "${response.data?.first.title}"',
      );
      expect(response.data?.first.title, '5 Tips for Faster Delivery');
    });

    test('a missing data key defaults to an empty list, not null', () {
      printTestDivider(
        'BlogResponse.fromJson a missing data key defaults to an empty list, not null',
      );
      final response = BlogResponse.fromJson(const {'status': '1'});

      printTestLog('data → expected: [], actual: ${response.data}');
      expect(response.data, isEmpty);
    });

    test('a null data key defaults to an empty list, not null', () {
      printTestDivider(
        'BlogResponse.fromJson a null data key defaults to an empty list, not null',
      );
      final response = BlogResponse.fromJson(const {
        'status': '1',
        'data': null,
      });

      printTestLog('data → expected: [], actual: ${response.data}');
      expect(response.data, isEmpty);
    });

    test('a non-list data value defaults to an empty list, not crash', () {
      printTestDivider(
        'BlogResponse.fromJson a non-list data value defaults to an empty list, not crash',
      );
      final response = BlogResponse.fromJson(const {
        'status': '1',
        'data': {'unexpected': 'map'},
      });

      printTestLog('data → expected: [], actual: ${response.data}');
      expect(response.data, isEmpty);
    });

    test('status/message/total lenient-parse numeric-looking values via toString', () {
      printTestDivider(
        'BlogResponse.fromJson status/message/total lenient-parse numeric-looking values via toString',
      );
      final response = BlogResponse.fromJson(const {
        'status': 1,
        'total': 2,
        'data': [],
      });

      printTestLog('status → expected: "1", actual: "${response.status}"');
      expect(response.status, '1');
      printTestLog('total → expected: "2", actual: "${response.total}"');
      expect(response.total, '2');
    });
  });

  group('Blog.fromJson', () {
    test('parses every field of a full real entry', () {
      printTestDivider('Blog.fromJson parses every field of a full real entry');
      final row = (fixture()['data'] as List).first as Map<String, dynamic>;
      final blog = Blog.fromJson(row);

      printTestLog('id → expected: "1", actual: "${blog.id}"');
      expect(blog.id, '1');
      printTestLog(
        'title → expected: "5 Tips for Faster Delivery", actual: "${blog.title}"',
      );
      expect(blog.title, '5 Tips for Faster Delivery');
      printTestLog('slug → expected: non-empty, actual: "${blog.slug}"');
      expect(blog.slug, isNotEmpty);
      printTestLog('categoryId → expected: "2", actual: "${blog.categoryId}"');
      expect(blog.categoryId, '2');
      printTestLog(
        'tagNames → expected: ["delivery", "tips"], actual: ${blog.tagNames}',
      );
      expect(blog.tagNames, ['delivery', 'tips']);
      printTestLog(
        'category → expected non-null with name "Delivery", actual: ${blog.category?.name}',
      );
      expect(blog.category, isNotNull);
      expect(blog.category?.name, 'Delivery');
      printTestLog('viewsCount → expected: "120", actual: "${blog.viewsCount}"');
      expect(blog.viewsCount, '120');
      printTestLog('readTime → expected: "3", actual: "${blog.readTime}"');
      expect(blog.readTime, '3');
      printTestLog('lang → expected: "en", actual: "${blog.lang}"');
      expect(blog.lang, 'en');
    });

    test('missing/null string fields default to empty string, not crash', () {
      printTestDivider(
        'Blog.fromJson missing/null string fields default to empty string, not crash',
      );
      final blog = Blog.fromJson(const {});

      printTestLog('title → expected: "", actual: "${blog.title}"');
      expect(blog.title, '');
      printTestLog('slug → expected: "", actual: "${blog.slug}"');
      expect(blog.slug, '');
      printTestLog('image → expected: "", actual: "${blog.image}"');
      expect(blog.image, '');
      printTestLog('description → expected: "", actual: "${blog.description}"');
      expect(blog.description, '');
      printTestLog(
        'shortDescription → expected: "", actual: "${blog.shortDescription}"',
      );
      expect(blog.shortDescription, '');
      printTestLog('tags → expected: "", actual: "${blog.tags}"');
      expect(blog.tags, '');
      printTestLog('metaTitle → expected: "", actual: "${blog.metaTitle}"');
      expect(blog.metaTitle, '');
      printTestLog(
        'metaKeywords → expected: "", actual: "${blog.metaKeywords}"',
      );
      expect(blog.metaKeywords, '');
      printTestLog(
        'metaDescription → expected: "", actual: "${blog.metaDescription}"',
      );
      expect(blog.metaDescription, '');
      printTestLog('imageUrl → expected: "", actual: "${blog.imageUrl}"');
      expect(blog.imageUrl, '');
      printTestLog('createdAt → expected: "", actual: "${blog.createdAt}"');
      expect(blog.createdAt, '');
    });

    test(
      'id/categoryId/status/viewsCount/readTime default to "0" (not "") when missing',
      () {
        printTestDivider(
          'Blog.fromJson id/categoryId/status/viewsCount/readTime default to "0" (not "") when missing',
        );
        final blog = Blog.fromJson(const {});

        printTestLog('id → expected: "0", actual: "${blog.id}"');
        expect(blog.id, '0');
        printTestLog('categoryId → expected: "0", actual: "${blog.categoryId}"');
        expect(blog.categoryId, '0');
        printTestLog('status → expected: "0", actual: "${blog.status}"');
        expect(blog.status, '0');
        printTestLog('viewsCount → expected: "0", actual: "${blog.viewsCount}"');
        expect(blog.viewsCount, '0');
        printTestLog('readTime → expected: "0", actual: "${blog.readTime}"');
        expect(blog.readTime, '0');
      },
    );

    test('lang stays null when absent, unlike the other string fields', () {
      printTestDivider(
        'Blog.fromJson lang stays null when absent, unlike the other string fields',
      );
      final blog = Blog.fromJson(const {});

      printTestLog('lang → expected: null, actual: ${blog.lang}');
      expect(blog.lang, isNull);
    });

    test('tagNames defaults to an empty list when missing or not a list', () {
      printTestDivider(
        'Blog.fromJson tagNames defaults to an empty list when missing or not a list',
      );
      final missing = Blog.fromJson(const {});
      final wrongType = Blog.fromJson(const {'tag_names': 'not-a-list'});

      printTestLog('missing tagNames → expected: [], actual: ${missing.tagNames}');
      expect(missing.tagNames, isEmpty);
      printTestLog(
        'wrong-type tagNames → expected: [], actual: ${wrongType.tagNames}',
      );
      expect(wrongType.tagNames, isEmpty);
    });

    test('tagNames stringifies non-string list entries', () {
      printTestDivider(
        'Blog.fromJson tagNames stringifies non-string list entries',
      );
      final blog = Blog.fromJson(const {
        'tag_names': [1, 'two', 3],
      });

      printTestLog('tagNames → expected: ["1", "two", "3"], actual: ${blog.tagNames}');
      expect(blog.tagNames, ['1', 'two', '3']);
    });

    test('category stays null when absent, not a fallback empty object', () {
      printTestDivider(
        'Blog.fromJson category stays null when absent, not a fallback empty object',
      );
      final missing = Blog.fromJson(const {});
      final wrongType = Blog.fromJson(const {'category': 'not-a-map'});

      printTestLog('missing category → expected: null, actual: ${missing.category}');
      expect(missing.category, isNull);
      printTestLog(
        'wrong-type category → expected: null, actual: ${wrongType.category}',
      );
      expect(wrongType.category, isNull);
    });

    test('id/categoryId lenient-parse a numeric value via toString', () {
      printTestDivider(
        'Blog.fromJson id/categoryId lenient-parse a numeric value via toString',
      );
      final blog = Blog.fromJson(const {'id': 7, 'category_id': 9});

      printTestLog('id → expected: "7", actual: "${blog.id}"');
      expect(blog.id, '7');
      printTestLog('categoryId → expected: "9", actual: "${blog.categoryId}"');
      expect(blog.categoryId, '9');
    });
  });

  group('Blog.toJson', () {
    test('round-trips a full entry', () {
      printTestDivider('Blog.toJson round-trips a full entry');
      final row = (fixture()['data'] as List).first as Map<String, dynamic>;
      final blog = Blog.fromJson(row);

      final json = blog.toJson();
      final roundTripped = Blog.fromJson(json);

      printTestLog('id → expected: ${blog.id}, actual: ${roundTripped.id}');
      expect(roundTripped.id, blog.id);
      printTestLog(
        'title → expected: "${blog.title}", actual: "${roundTripped.title}"',
      );
      expect(roundTripped.title, blog.title);
      printTestLog(
        'tagNames → expected: ${blog.tagNames}, actual: ${roundTripped.tagNames}',
      );
      expect(roundTripped.tagNames, blog.tagNames);
      printTestLog(
        'category name → expected: "${blog.category?.name}", actual: "${roundTripped.category?.name}"',
      );
      expect(roundTripped.category?.name, blog.category?.name);
    });

    test('omits the category key entirely when category is null', () {
      printTestDivider(
        'Blog.toJson omits the category key entirely when category is null',
      );
      final blog = Blog.fromJson(const {'id': '1'});

      final json = blog.toJson();

      printTestLog(
        'category key present → expected: false, actual: ${json.containsKey('category')}',
      );
      expect(json.containsKey('category'), isFalse);
    });
  });
}
