import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/auth/models/auth_model.dart';

import '../../../helpers/test_logging.dart';

void main() {
  Map<String, dynamic> fixture() =>
      jsonDecode(
            File('test/fixtures/auth/login_success.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('AuthModel.fromJson', () {
    test('parses the envelope and nested data from a full real payload', () {
      printTestDivider(
        'AuthModel.fromJson parses the envelope and nested data from a full real payload',
      );
      final model = AuthModel.fromJson(fixture());

      // Unlike faq/blog's envelope, this app's AuthModel keeps `status` as
      // an int (`parseInt(...) ?? 0`), not a stringified value — assert the
      // type explicitly since every sibling feature's envelope does the
      // opposite.
      printTestLog('status → expected: 1, actual: ${model.status}');
      expect(model.status, 1);
      printTestLog(
        'message → expected: "Login successful", actual: "${model.message}"',
      );
      expect(model.message, 'Login successful');
      printTestLog(
        'statusCode → expected: "LOGIN_SUCCESS", actual: "${model.statusCode}"',
      );
      expect(model.statusCode, 'LOGIN_SUCCESS');
      printTestLog('data → expected: non-null, actual: ${model.data}');
      expect(model.data, isNotNull);
      printTestLog(
        'data.accessToken → expected: "test-access-token-abc123", actual: "${model.data?.accessToken}"',
      );
      expect(model.data?.accessToken, 'test-access-token-abc123');
    });

    test('a missing data key leaves data null (not a default object)', () {
      printTestDivider(
        'AuthModel.fromJson a missing data key leaves data null (not a default object)',
      );
      final model = AuthModel.fromJson(const {'status': 1});

      printTestLog('data → expected: null, actual: ${model.data}');
      expect(model.data, isNull);
    });

    test('a null data key leaves data null', () {
      printTestDivider('AuthModel.fromJson a null data key leaves data null');
      final model = AuthModel.fromJson(const {'status': 1, 'data': null});

      printTestLog('data → expected: null, actual: ${model.data}');
      expect(model.data, isNull);
    });

    test('a non-Map data value (e.g. a String) also leaves data null', () {
      printTestDivider(
        'AuthModel.fromJson a non-Map data value also leaves data null',
      );
      final model = AuthModel.fromJson(const {'status': 1, 'data': 'oops'});

      printTestLog('data → expected: null, actual: ${model.data}');
      expect(model.data, isNull);
    });

    test('missing status/message/status_code default to 0/""/""', () {
      printTestDivider(
        'AuthModel.fromJson missing status/message/status_code default to 0/""/""',
      );
      final model = AuthModel.fromJson(const {});

      printTestLog('status → expected: 0, actual: ${model.status}');
      expect(model.status, 0);
      printTestLog('message → expected: "", actual: "${model.message}"');
      expect(model.message, '');
      printTestLog('statusCode → expected: "", actual: "${model.statusCode}"');
      expect(model.statusCode, '');
    });

    test('status lenient-parses a stringified numeric value', () {
      printTestDivider(
        'AuthModel.fromJson status lenient-parses a stringified numeric value',
      );
      final model = AuthModel.fromJson(const {'status': '1'});

      printTestLog('status → expected: 1, actual: ${model.status}');
      expect(model.status, 1);
    });
  });

  group('AuthModelData.fromJson', () {
    test('parses every field of a full real entry', () {
      printTestDivider(
        'AuthModelData.fromJson parses every field of a full real entry',
      );
      final row = fixture()['data'] as Map<String, dynamic>;
      final data = AuthModelData.fromJson(row);

      printTestLog('id → expected: 42, actual: ${data.id}');
      expect(data.id, 42);
      printTestLog('name → expected: "Jordan Blake", actual: "${data.name}"');
      expect(data.name, 'Jordan Blake');
      printTestLog(
        'email → expected: "jordan.blake@example.com", actual: "${data.email}"',
      );
      expect(data.email, 'jordan.blake@example.com');
      printTestLog(
        'countryCode → expected: "+1", actual: "${data.countryCode}"',
      );
      expect(data.countryCode, '+1');
      printTestLog('countryId → expected: 231, actual: ${data.countryId}');
      expect(data.countryId, 231);
      printTestLog('mobile → expected: "5551234567", actual: "${data.mobile}"');
      expect(data.mobile, '5551234567');
      printTestLog('balance → expected: 125.5, actual: ${data.balance}');
      expect(data.balance, 125.5);
      printTestLog(
        'referralCode → expected: "JORDAN42", actual: "${data.referralCode}"',
      );
      expect(data.referralCode, 'JORDAN42');
      printTestLog('type → expected: "email", actual: "${data.type}"');
      expect(data.type, 'email');
      printTestLog(
        'accessToken → expected: "test-access-token-abc123", actual: "${data.accessToken}"',
      );
      expect(data.accessToken, 'test-access-token-abc123');
    });

    test('missing/null string fields default to "" (not null)', () {
      printTestDivider(
        'AuthModelData.fromJson missing/null string fields default to "" (not null)',
      );
      final data = AuthModelData.fromJson(const {});

      printTestLog('name → expected: "", actual: "${data.name}"');
      expect(data.name, '');
      printTestLog('email → expected: "", actual: "${data.email}"');
      expect(data.email, '');
      printTestLog('countryCode → expected: "", actual: "${data.countryCode}"');
      expect(data.countryCode, '');
      printTestLog('mobile → expected: "", actual: "${data.mobile}"');
      expect(data.mobile, '');
      printTestLog('profile → expected: "", actual: "${data.profile}"');
      expect(data.profile, '');
      printTestLog(
        'referralCode → expected: "", actual: "${data.referralCode}"',
      );
      expect(data.referralCode, '');
      printTestLog('type → expected: "", actual: "${data.type}"');
      expect(data.type, '');
      printTestLog('accessToken → expected: "", actual: "${data.accessToken}"');
      expect(data.accessToken, '');
      printTestLog('id → expected: 0, actual: ${data.id}');
      expect(data.id, 0);
    });

    test('countryId/balance stay null when absent (no forced default)', () {
      printTestDivider(
        'AuthModelData.fromJson countryId/balance stay null when absent (no forced default)',
      );
      final data = AuthModelData.fromJson(const {});

      // Unlike the string fields (which fall back to ""), `countryId` uses
      // bare `parseInt(...)` with no `?? 0`, and `balance` uses
      // `parseDouble(...)` which itself defaults to 0.0, not null — worth
      // asserting both explicitly rather than assuming they match id's `?? 0`.
      printTestLog('countryId → expected: null, actual: ${data.countryId}');
      expect(data.countryId, isNull);
      printTestLog('balance → expected: 0.0, actual: ${data.balance}');
      expect(data.balance, 0.0);
    });

    test('id/countryId lenient-parse a stringified numeric value', () {
      printTestDivider(
        'AuthModelData.fromJson id/countryId lenient-parse a stringified numeric value',
      );
      final data = AuthModelData.fromJson(const {
        'id': '99',
        'country_id': '5',
      });

      printTestLog('id → expected: 99, actual: ${data.id}');
      expect(data.id, 99);
      printTestLog('countryId → expected: 5, actual: ${data.countryId}');
      expect(data.countryId, 5);
    });
  });

  group('AuthModel.toJson / AuthModelData.toJson', () {
    test('round-trips a full payload', () {
      printTestDivider('AuthModel.toJson round-trips a full payload');
      final model = AuthModel.fromJson(fixture());

      final json = model.toJson();
      final roundTripped = AuthModel.fromJson(json);

      printTestLog(
        'status → expected: ${model.status}, actual: ${roundTripped.status}',
      );
      expect(roundTripped.status, model.status);
      printTestLog(
        'data.accessToken → expected: "${model.data?.accessToken}", actual: "${roundTripped.data?.accessToken}"',
      );
      expect(roundTripped.data?.accessToken, model.data?.accessToken);
      printTestLog(
        'data.email → expected: "${model.data?.email}", actual: "${roundTripped.data?.email}"',
      );
      expect(roundTripped.data?.email, model.data?.email);
    });

    test('toJson omits the "data" key entirely when data is null', () {
      printTestDivider(
        'AuthModel.toJson omits the "data" key entirely when data is null',
      );
      final model = AuthModel.fromJson(const {'status': 1});

      final json = model.toJson();

      printTestLog(
        'containsKey("data") → expected: false, actual: ${json.containsKey("data")}',
      );
      expect(json.containsKey('data'), isFalse);
    });
  });
}
