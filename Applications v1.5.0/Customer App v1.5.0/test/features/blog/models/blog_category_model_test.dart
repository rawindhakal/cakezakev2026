import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/blog/models/blog_category_model.dart';

import '../../../helpers/test_logging.dart';

void main() {
  Map<String, dynamic> fixture() =>
      jsonDecode(
            File(
              'test/fixtures/blog/blog_category_list.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('BlogCategoryResponse.fromJson', () {
    test('parses the envelope and every entry from a full real payload', () {
      printTestDivider(
        'BlogCategoryResponse.fromJson parses the envelope and every entry from a full real payload',
      );
      final response = BlogCategoryResponse.fromJson(fixture());

      printTestLog('status → expected: "1", actual: "${response.status}"');
      expect(response.status, '1');
      printTestLog(
        'message → expected: "Blog categories found", actual: "${response.message}"',
      );
      expect(response.message, 'Blog categories found');
      printTestLog(
        'data length → expected: 2, actual: ${response.data?.length}',
      );
      expect(response.data, hasLength(2));
      printTestLog(
        'first name → expected: "Delivery", actual: "${response.data?.first.name}"',
      );
      expect(response.data?.first.name, 'Delivery');
    });

    test('a missing data key defaults to an empty list, not null', () {
      printTestDivider(
        'BlogCategoryResponse.fromJson a missing data key defaults to an empty list, not null',
      );
      final response = BlogCategoryResponse.fromJson(const {'status': '1'});

      printTestLog('data → expected: [], actual: ${response.data}');
      expect(response.data, isEmpty);
    });

    test('a null data key defaults to an empty list, not null', () {
      printTestDivider(
        'BlogCategoryResponse.fromJson a null data key defaults to an empty list, not null',
      );
      final response = BlogCategoryResponse.fromJson(const {
        'status': '1',
        'data': null,
      });

      printTestLog('data → expected: [], actual: ${response.data}');
      expect(response.data, isEmpty);
    });
  });

  group('BlogCategory.fromJson', () {
    test('parses every field of a full real entry', () {
      printTestDivider(
        'BlogCategory.fromJson parses every field of a full real entry',
      );
      final row = (fixture()['data'] as List).first as Map<String, dynamic>;
      final category = BlogCategory.fromJson(row);

      printTestLog('id → expected: "2", actual: "${category.id}"');
      expect(category.id, '2');
      printTestLog('name → expected: "Delivery", actual: "${category.name}"');
      expect(category.name, 'Delivery');
      printTestLog('slug → expected: non-empty, actual: "${category.slug}"');
      expect(category.slug, isNotEmpty);
      printTestLog(
        'activeBlogsCount → expected: "4", actual: "${category.activeBlogsCount}"',
      );
      expect(category.activeBlogsCount, '4');
      printTestLog('lang → expected: "en", actual: "${category.lang}"');
      expect(category.lang, 'en');
    });

    test('missing/null string fields default to empty string, not crash', () {
      printTestDivider(
        'BlogCategory.fromJson missing/null string fields default to empty string, not crash',
      );
      final category = BlogCategory.fromJson(const {});

      printTestLog('name → expected: "", actual: "${category.name}"');
      expect(category.name, '');
      printTestLog('slug → expected: "", actual: "${category.slug}"');
      expect(category.slug, '');
      printTestLog(
        'metaTitle → expected: "", actual: "${category.metaTitle}"',
      );
      expect(category.metaTitle, '');
      printTestLog(
        'metaKeywords → expected: "", actual: "${category.metaKeywords}"',
      );
      expect(category.metaKeywords, '');
      printTestLog(
        'metaDescription → expected: "", actual: "${category.metaDescription}"',
      );
      expect(category.metaDescription, '');
    });

    test(
      'id/status/activeBlogsCount default to "0" (not "") when missing',
      () {
        printTestDivider(
          'BlogCategory.fromJson id/status/activeBlogsCount default to "0" (not "") when missing',
        );
        final category = BlogCategory.fromJson(const {});

        printTestLog('id → expected: "0", actual: "${category.id}"');
        expect(category.id, '0');
        printTestLog('status → expected: "0", actual: "${category.status}"');
        expect(category.status, '0');
        printTestLog(
          'activeBlogsCount → expected: "0", actual: "${category.activeBlogsCount}"',
        );
        expect(category.activeBlogsCount, '0');
      },
    );

    test(
      'lang defaults to empty string when absent, unlike Blog.lang which stays null',
      () {
        printTestDivider(
          'BlogCategory.fromJson lang defaults to empty string when absent, unlike Blog.lang which stays null',
        );
        final category = BlogCategory.fromJson(const {});

        printTestLog('lang → expected: "", actual: "${category.lang}"');
        expect(category.lang, '');
      },
    );

    test('id lenient-parses a numeric value via toString', () {
      printTestDivider(
        'BlogCategory.fromJson id lenient-parses a numeric value via toString',
      );
      final category = BlogCategory.fromJson(const {'id': 7});

      printTestLog('id → expected: "7", actual: "${category.id}"');
      expect(category.id, '7');
    });
  });

  group('BlogCategory.toJson', () {
    test('round-trips a full entry', () {
      printTestDivider('BlogCategory.toJson round-trips a full entry');
      final row = (fixture()['data'] as List).first as Map<String, dynamic>;
      final category = BlogCategory.fromJson(row);

      final json = category.toJson();
      final roundTripped = BlogCategory.fromJson(json);

      printTestLog(
        'id → expected: ${category.id}, actual: ${roundTripped.id}',
      );
      expect(roundTripped.id, category.id);
      printTestLog(
        'name → expected: "${category.name}", actual: "${roundTripped.name}"',
      );
      expect(roundTripped.name, category.name);
    });

    test('omits lang from the output even though it is parsed on the way in', () {
      printTestDivider(
        'BlogCategory.toJson omits lang from the output even though it is parsed on the way in',
      );
      final category = BlogCategory.fromJson(const {'id': '1', 'lang': 'en'});

      final json = category.toJson();

      printTestLog(
        'lang key present → expected: false, actual: ${json.containsKey('lang')}',
      );
      expect(json.containsKey('lang'), isFalse);
    });
  });
}
