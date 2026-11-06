import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/features/chat/services/chat_conversation_resolver.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/fake_api_adapter.dart';
import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/test_logging.dart';

/// The resolver builds its own `ChatConversationsCubit` (and therefore its own
/// `ChatRepository`/`ApiClient`) internally, so there is nothing to inject —
/// the real chain runs against the `ApiClient` adapter seam instead, the same
/// way `earnings_screen_test.dart` drives its screen-owned cubit.
void main() {
  late FakeApiAdapter adapter;
  late Map<String, dynamic> adminResponse;

  setUpAll(() {
    adminResponse =
        jsonDecode(
              File('test/fixtures/chat/chat_start_admin.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  setUp(() async {
    // DioInterceptor reads the auth token out of AuthHiveBox and the language
    // code out of SettingsHiveBox on every request.
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);

    adapter = FakeApiAdapter({
      ApiEndpoints.chatStartAdmin: (_) => adminResponse,
      ApiEndpoints.chatStartOrder: (_) => {
        'status': 1,
        'data': {'id': 41, 'type': 'delivery_boy_customer', 'order_id': 1204},
      },
    });
    ApiClient().httpClientAdapter = adapter;
  });

  tearDown(() async {
    await Hive.box(settingsBox).close();
    await Hive.deleteBoxFromDisk(settingsBox);
    await HiveTestHelper.tearDown(authBox);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  group('resolveAdminConversationId', () {
    test('starts the conversation and caches the id for the session', () async {
      printTestDivider(
        'resolveAdminConversationId starts the conversation and caches the id for the session',
      );
      final id = await resolveAdminConversationId();

      printTestLog('id → expected: "7", actual: "$id"');
      expect(id, '7');
      printTestLog(
        'requested → expected: [chat/start_admin], actual: ${adapter.requestedPaths}',
      );
      expect(adapter.requestedPaths, [ApiEndpoints.chatStartAdmin]);
      printTestLog(
        'cached → expected: "7", actual: "${AuthHiveBox.instance.adminConversationId}"',
      );
      expect(AuthHiveBox.instance.adminConversationId, '7');
    });

    test('reuses the cached id instead of calling start_admin again', () async {
      printTestDivider(
        'resolveAdminConversationId reuses the cached id instead of calling start_admin again',
      );
      await AuthHiveBox.instance.setAdminConversationId('7');

      final id = await resolveAdminConversationId();

      printTestLog('id → expected: "7", actual: "$id"');
      expect(id, '7');
      printTestLog('requests → expected: none, actual: ${adapter.requestedPaths}');
      expect(adapter.requestedPaths, isEmpty);
    });

    test('an empty cached id is treated as no cache at all', () async {
      printTestDivider(
        'resolveAdminConversationId an empty cached id is treated as no cache at all',
      );
      await AuthHiveBox.instance.setAdminConversationId('');

      final id = await resolveAdminConversationId();

      printTestLog('id → expected: "7", actual: "$id"');
      expect(id, '7');
      printTestLog(
        'requested → expected: [chat/start_admin], actual: ${adapter.requestedPaths}',
      );
      expect(adapter.requestedPaths, [ApiEndpoints.chatStartAdmin]);
    });

    test('a failing start_admin returns null and caches nothing', () async {
      printTestDivider(
        'resolveAdminConversationId a failing start_admin returns null and caches nothing',
      );
      ApiClient().httpClientAdapter = FakeApiAdapter({
        ApiEndpoints.chatStartAdmin: (_) => {
          'status': 0,
          'message': 'Chat is disabled',
        },
      });

      final id = await resolveAdminConversationId();

      printTestLog('id → expected: null, actual: $id');
      expect(id, isNull);
      printTestLog(
        'cached → expected: null, actual: ${AuthHiveBox.instance.adminConversationId}',
      );
      expect(AuthHiveBox.instance.adminConversationId, isNull);
    });
  });

  group('resolveOrderConversationId', () {
    test('starts the conversation and caches it under the order id', () async {
      printTestDivider(
        'resolveOrderConversationId starts the conversation and caches it under the order id',
      );
      final id = await resolveOrderConversationId('1204');

      printTestLog('id → expected: "41", actual: "$id"');
      expect(id, '41');
      printTestLog(
        'order_id sent → expected: "1204", actual: ${adapter.requests.single.data}',
      );
      expect(
        (adapter.requests.single.data as Map)[ApiParameters.orderId],
        '1204',
      );
      printTestLog(
        'cached → expected: "41", actual: "${AuthHiveBox.instance.getOrderConversationId('1204')}"',
      );
      expect(AuthHiveBox.instance.getOrderConversationId('1204'), '41');
    });

    test('an ecommerce order item gets its own cache key and thread', () async {
      printTestDivider(
        'resolveOrderConversationId an ecommerce order item gets its own cache key and thread',
      );
      await resolveOrderConversationId('1204', orderItemId: '9001');

      printTestLog(
        'cached under "1204_9001" → expected: "41", actual: "${AuthHiveBox.instance.getOrderConversationId('1204_9001')}"',
      );
      expect(AuthHiveBox.instance.getOrderConversationId('1204_9001'), '41');
      printTestLog(
        'cached under "1204" → expected: null, actual: ${AuthHiveBox.instance.getOrderConversationId('1204')}',
      );
      expect(AuthHiveBox.instance.getOrderConversationId('1204'), isNull);
      printTestLog(
        'order_item_id sent → expected: "9001", actual: ${(adapter.requests.single.data as Map)[ApiParameters.orderItemId]}',
      );
      expect(
        (adapter.requests.single.data as Map)[ApiParameters.orderItemId],
        '9001',
      );
    });

    test('reuses the cached id instead of calling start_order again', () async {
      printTestDivider(
        'resolveOrderConversationId reuses the cached id instead of calling start_order again',
      );
      await AuthHiveBox.instance.setOrderConversationId('1204', '41');

      final id = await resolveOrderConversationId('1204');

      printTestLog('id → expected: "41", actual: "$id"');
      expect(id, '41');
      printTestLog('requests → expected: none, actual: ${adapter.requestedPaths}');
      expect(adapter.requestedPaths, isEmpty);
    });

    test('a cache entry for the plain order does not satisfy an item-scoped lookup', () async {
      printTestDivider(
        'resolveOrderConversationId a cache entry for the plain order does not satisfy an item-scoped lookup',
      );
      await AuthHiveBox.instance.setOrderConversationId('1204', '41');

      await resolveOrderConversationId('1204', orderItemId: '9001');

      printTestLog(
        'requested → expected: [chat/start_order], actual: ${adapter.requestedPaths}',
      );
      expect(adapter.requestedPaths, [ApiEndpoints.chatStartOrder]);
    });

    test('a failing start_order returns null and caches nothing', () async {
      printTestDivider(
        'resolveOrderConversationId a failing start_order returns null and caches nothing',
      );
      ApiClient().httpClientAdapter = FakeApiAdapter({
        ApiEndpoints.chatStartOrder: (_) => {
          'status': 0,
          'message': 'Order not found',
        },
      });

      final id = await resolveOrderConversationId('1204');

      printTestLog('id → expected: null, actual: $id');
      expect(id, isNull);
      printTestLog(
        'cached → expected: null, actual: ${AuthHiveBox.instance.getOrderConversationId('1204')}',
      );
      expect(AuthHiveBox.instance.getOrderConversationId('1204'), isNull);
    });
  });
}
