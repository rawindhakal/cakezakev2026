import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/features/auth/models/auth_model.dart';

import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('fromJson parses a real /login response', () {
    printTestDivider('fromJson parses a real /login response');
    // Mirrors the real /login response's body — refresh
    // test/fixtures/auth/login_response.json when the backend contract
    // changes, instead of editing this test.
    final json =
        jsonDecode(
              File('test/fixtures/auth/login_response.json').readAsStringSync(),
            )
            as Map<String, dynamic>;

    final result = AuthModel.fromJson(json);

    printTestLog('status                   → expected: 1, actual: ${result.status}');
    expect(result.status, 1);
    printTestLog(
      'message                  → expected: "Success", actual: "${result.message}"',
    );
    expect(result.message, 'Success');
    printTestLog('data.id                  → expected: 2, actual: ${result.data?.id}');
    expect(result.data?.id, 2);
    printTestLog(
      'data.name                → expected: "Alex Johnson", actual: "${result.data?.name}"',
    );
    expect(result.data?.name, 'Alex Johnson');
    printTestLog(
      'data.email               → expected: "alex@gmail.com", actual: "${result.data?.email}"',
    );
    expect(result.data?.email, 'alex@gmail.com');
    printTestLog(
      'data.mobile              → expected: "1234567890", actual: "${result.data?.mobile}"',
    );
    expect(result.data?.mobile, '1234567890');
    printTestLog(
      'data.countryCode         → expected: "+91", actual: "${result.data?.countryCode}"',
    );
    expect(result.data?.countryCode, '+91');
    printTestLog(
      'data.countryId           → expected: 1, actual: ${result.data?.countryId}',
    );
    expect(result.data?.countryId, 1);
    printTestLog(
      'data.zoneId              → expected: 2, actual: ${result.data?.zoneId}',
    );
    expect(result.data?.zoneId, 2);
    printTestLog(
      'data.balance             → expected: 366.25, actual: ${result.data?.balance}',
    );
    expect(result.data?.balance, 366.25);
    printTestLog(
      'data.bonusMinAmount      → expected: 40.0, actual: ${result.data?.bonusMinAmount}',
    );
    expect(result.data?.bonusMinAmount, 40.0);
    printTestLog(
      'data.returnBonusMaxAmount→ expected: 60.0, actual: ${result.data?.returnBonusMaxAmount}',
    );
    expect(result.data?.returnBonusMaxAmount, 60.0);
    // cash_received arrives as a double but the model holds it as an int —
    // toSafeIntOrNull truncates rather than throwing on the fractional part.
    printTestLog(
      'data.cashReceived        → expected: 15996, actual: ${result.data?.cashReceived}',
    );
    expect(result.data?.cashReceived, 15996);
    printTestLog(
      'data.pendingOrderCount   → expected: 6, actual: ${result.data?.pendingOrderCount}',
    );
    expect(result.data?.pendingOrderCount, 6);
    printTestLog(
      'data.accessToken starts with expected JWT prefix → actual: "${result.data?.accessToken?.substring(0, 10)}..."',
    );
    expect(result.data?.accessToken, startsWith('eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9'));
    // Omitted entirely from the real response — fromJson must leave these null.
    printTestLog(
      'data.isAvailable         → expected: null, actual: ${result.data?.isAvailable}',
    );
    expect(result.data?.isAvailable, isNull);
    printTestLog(
      'data.fcmId               → expected: null, actual: ${result.data?.fcmId}',
    );
    expect(result.data?.fcmId, isNull);
  });

  test('fromJson defaults data to null when the key is absent', () {
    printTestDivider('fromJson defaults data to null when the key is absent');
    final result = AuthModel.fromJson(const {'status': null, 'message': null});

    printTestLog('status → expected: null, actual: ${result.status}');
    expect(result.status, isNull);
    printTestLog('data   → expected: null, actual: ${result.data}');
    expect(result.data, isNull);
  });

  test('fromJson parses status as a bare int', () {
    printTestDivider('fromJson parses status as a bare int');
    final result = AuthModel.fromJson(const {'status': 1});
    printTestLog('status → expected: 1, actual: ${result.status}');
    expect(result.status, 1);
  });

  test('fromJson parses status leniently when sent as a quoted string', () {
    printTestDivider(
      'fromJson parses status leniently when sent as a quoted string',
    );
    final result = AuthModel.fromJson(const {'status': '1'});
    printTestLog('status → expected: 1, actual: ${result.status}');
    expect(result.status, 1);
  });

  test('toJson round-trips fromJson output', () {
    printTestDivider('toJson round-trips fromJson output');
    final original = AuthModel.fromJson(const {
      'status': 1,
      'message': 'ok',
      'data': {'id': 5, 'name': 'Jane', 'access_token': 'abc'},
    });

    final roundTripped = AuthModel.fromJson(original.toJson());

    printTestLog(
      'data.name        → expected: "${original.data?.name}", actual: "${roundTripped.data?.name}"',
    );
    expect(roundTripped.data?.name, original.data?.name);
    printTestLog(
      'data.accessToken → expected: "${original.data?.accessToken}", actual: "${roundTripped.data?.accessToken}"',
    );
    expect(roundTripped.data?.accessToken, original.data?.accessToken);
    printTestLog(
      'status           → expected: ${original.status}, actual: ${roundTripped.status}',
    );
    expect(roundTripped.status, original.status);
  });
}
