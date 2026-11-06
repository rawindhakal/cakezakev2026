import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/faq/models/faq_model.dart';

import '../../../helpers/test_logging.dart';

void main() {
  Map<String, dynamic> fixture() =>
      jsonDecode(
            File('test/fixtures/faq/faq_list.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('FaqResponse.fromJson', () {
    test('parses the envelope and every entry from a full real payload', () {
      printTestDivider(
        'FaqResponse.fromJson parses the envelope and every entry from a full real payload',
      );
      final response = FaqResponse.fromJson(fixture());

      printTestLog('status → expected: "1", actual: "${response.status}"');
      expect(response.status, '1');
      printTestLog(
        'message → expected: "Faqs found", actual: "${response.message}"',
      );
      expect(response.message, 'Faqs found');
      printTestLog('total → expected: "3", actual: "${response.total}"');
      expect(response.total, '3');
      printTestLog(
        'data length → expected: 3, actual: ${response.data?.length}',
      );
      expect(response.data, hasLength(3));
      printTestLog(
        'first question → expected: "How do I track my order?", actual: "${response.data?.first.question}"',
      );
      expect(response.data?.first.question, 'How do I track my order?');
    });

    test('a missing data key defaults to an empty list, not null', () {
      printTestDivider(
        'FaqResponse.fromJson a missing data key defaults to an empty list, not null',
      );
      final response = FaqResponse.fromJson(const {'status': '1'});

      printTestLog('data → expected: [], actual: ${response.data}');
      expect(response.data, isEmpty);
    });

    test('a null data key defaults to an empty list, not null', () {
      printTestDivider(
        'FaqResponse.fromJson a null data key defaults to an empty list, not null',
      );
      final response = FaqResponse.fromJson(const {'status': '1', 'data': null});

      printTestLog('data → expected: [], actual: ${response.data}');
      expect(response.data, isEmpty);
    });

    test('status/message/total lenient-parse numeric-looking values via toString', () {
      printTestDivider(
        'FaqResponse.fromJson status/message/total lenient-parse numeric-looking values via toString',
      );
      final response = FaqResponse.fromJson(const {
        'status': 1,
        'total': 3,
        'data': [],
      });

      printTestLog('status → expected: "1", actual: "${response.status}"');
      expect(response.status, '1');
      printTestLog('total → expected: "3", actual: "${response.total}"');
      expect(response.total, '3');
    });
  });

  group('FaqData.fromJson', () {
    test('parses every field of a full real entry', () {
      printTestDivider('FaqData.fromJson parses every field of a full real entry');
      final row = (fixture()['data'] as List).first as Map<String, dynamic>;
      final data = FaqData.fromJson(row);

      printTestLog('id → expected: "1", actual: "${data.id}"');
      expect(data.id, '1');
      printTestLog(
        'question → expected: "How do I track my order?", actual: "${data.question}"',
      );
      expect(data.question, 'How do I track my order?');
      printTestLog(
        'answer → expected: non-empty, actual: "${data.answer}"',
      );
      expect(data.answer, isNotEmpty);
      printTestLog('lang → expected: "en", actual: "${data.lang}"');
      expect(data.lang, 'en');
      printTestLog(
        'isExpanded → expected: false, actual: ${data.isExpanded}',
      );
      expect(data.isExpanded, isFalse);
    });

    test('missing/null fields default to empty strings and false, not crash', () {
      printTestDivider(
        'FaqData.fromJson missing/null fields default to empty strings and false, not crash',
      );
      final data = FaqData.fromJson(const {});

      printTestLog('id → expected: "", actual: "${data.id}"');
      expect(data.id, '');
      printTestLog('question → expected: "", actual: "${data.question}"');
      expect(data.question, '');
      printTestLog('answer → expected: "", actual: "${data.answer}"');
      expect(data.answer, '');
      printTestLog('lang → expected: "", actual: "${data.lang}"');
      expect(data.lang, '');
      printTestLog('isExpanded → expected: false, actual: ${data.isExpanded}');
      expect(data.isExpanded, isFalse);
    });

    test('id/question/answer/lang lenient-parse a numeric value via toString', () {
      printTestDivider(
        'FaqData.fromJson id/question/answer/lang lenient-parse a numeric value via toString',
      );
      final data = FaqData.fromJson(const {'id': 7});

      printTestLog('id → expected: "7", actual: "${data.id}"');
      expect(data.id, '7');
    });

    test('isExpanded reads is_expanded true when present', () {
      printTestDivider('FaqData.fromJson isExpanded reads is_expanded true when present');
      final data = FaqData.fromJson(const {'id': '1', 'is_expanded': true});

      printTestLog('isExpanded → expected: true, actual: ${data.isExpanded}');
      expect(data.isExpanded, isTrue);
    });
  });

  group('FaqData.toJson', () {
    test('round-trips a full entry', () {
      printTestDivider('FaqData.toJson round-trips a full entry');
      final row = (fixture()['data'] as List).first as Map<String, dynamic>;
      final data = FaqData.fromJson(row);

      final json = data.toJson();
      final roundTripped = FaqData.fromJson(json);

      printTestLog('id → expected: ${data.id}, actual: ${roundTripped.id}');
      expect(roundTripped.id, data.id);
      printTestLog(
        'question → expected: "${data.question}", actual: "${roundTripped.question}"',
      );
      expect(roundTripped.question, data.question);
      printTestLog(
        'answer → expected: "${data.answer}", actual: "${roundTripped.answer}"',
      );
      expect(roundTripped.answer, data.answer);
      printTestLog('lang → expected: "${data.lang}", actual: "${roundTripped.lang}"');
      expect(roundTripped.lang, data.lang);
      printTestLog(
        'isExpanded → expected: ${data.isExpanded}, actual: ${roundTripped.isExpanded}',
      );
      expect(roundTripped.isExpanded, data.isExpanded);
    });
  });
}
