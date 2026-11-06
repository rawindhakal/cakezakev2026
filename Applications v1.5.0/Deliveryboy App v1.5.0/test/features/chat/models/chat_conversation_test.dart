import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/features/chat/models/chat_conversation.dart';

import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Map<String, dynamic> adminFixture() =>
      (jsonDecode(
                File(
                  'test/fixtures/chat/chat_start_admin.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>)['data']
          as Map<String, dynamic>;

  Map<String, dynamic> orderFixture() =>
      ((jsonDecode(
                    File(
                      'test/fixtures/chat/chat_messages.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>)['data']
              as Map<String, dynamic>)['conversation']
          as Map<String, dynamic>;

  group('ChatConversation.fromJson', () {
    test('parses the admin conversation off the real payload', () {
      printTestDivider(
        'ChatConversation.fromJson parses the admin conversation off the real payload',
      );
      final conversation = ChatConversation.fromJson(adminFixture());

      printTestLog('id → expected: "7", actual: "${conversation.id}"');
      expect(conversation.id, '7');
      printTestLog(
        'type → expected: "admin_customer", actual: "${conversation.type}"',
      );
      expect(conversation.type, 'admin_customer');
      printTestLog('title → expected: "Support", actual: "${conversation.title}"');
      expect(conversation.title, 'Support');
      printTestLog('userId → expected: 88, actual: ${conversation.userId}');
      expect(conversation.userId, 88);
      printTestLog(
        'deliveryBoyId → expected: 12, actual: ${conversation.deliveryBoyId}',
      );
      expect(conversation.deliveryBoyId, 12);
      printTestLog(
        'unreadCount → expected: 0, actual: ${conversation.unreadCount}',
      );
      expect(conversation.unreadCount, 0);
      printTestLog(
        'isAdminChat → expected: true, actual: ${conversation.isAdminChat}',
      );
      expect(conversation.isAdminChat, isTrue);
    });

    test('a null order_id stays null rather than becoming "null"', () {
      printTestDivider(
        'ChatConversation.fromJson a null order_id stays null rather than becoming "null"',
      );
      final conversation = ChatConversation.fromJson(adminFixture());
      printTestLog('orderId → expected: null, actual: ${conversation.orderId}');
      expect(conversation.orderId, isNull);
    });

    test('parses the order conversation, including its unread count', () {
      printTestDivider(
        'ChatConversation.fromJson parses the order conversation, including its unread count',
      );
      final conversation = ChatConversation.fromJson(orderFixture());

      printTestLog('id → expected: "41", actual: "${conversation.id}"');
      expect(conversation.id, '41');
      printTestLog('orderId → expected: "1204", actual: "${conversation.orderId}"');
      expect(conversation.orderId, '1204');
      printTestLog(
        'lastMessage → expected: "Please leave it at the gate", actual: "${conversation.lastMessage}"',
      );
      expect(conversation.lastMessage, 'Please leave it at the gate');
      printTestLog(
        'lastSenderType → expected: "user", actual: "${conversation.lastSenderType}"',
      );
      expect(conversation.lastSenderType, 'user');
      printTestLog(
        'lastTime → expected: "09:12 AM", actual: "${conversation.lastTime}"',
      );
      expect(conversation.lastTime, '09:12 AM');
      printTestLog('unreadCount → expected: 2, actual: ${conversation.unreadCount}');
      expect(conversation.unreadCount, 2);
      printTestLog(
        'isAdminChat → expected: false, actual: ${conversation.isAdminChat}',
      );
      expect(conversation.isAdminChat, isFalse);
    });

    test('last_message_at parses into a DateTime', () {
      printTestDivider('ChatConversation.fromJson last_message_at parses into a DateTime');
      final conversation = ChatConversation.fromJson(orderFixture());
      printTestLog(
        'lastMessageAt → expected: 2026-08-19 09:12:44, actual: ${conversation.lastMessageAt}',
      );
      expect(conversation.lastMessageAt, DateTime(2026, 8, 19, 9, 12, 44));
    });

    test('an unparseable last_message_at leaves the field null instead of throwing', () {
      printTestDivider(
        'ChatConversation.fromJson an unparseable last_message_at leaves the field null instead of throwing',
      );
      final conversation = ChatConversation.fromJson(const {
        'id': 1,
        'last_message_at': 'yesterday-ish',
      });
      printTestLog(
        'lastMessageAt → expected: null, actual: ${conversation.lastMessageAt}',
      );
      expect(conversation.lastMessageAt, isNull);
    });

    test('ids arriving as quoted strings still parse to ints', () {
      printTestDivider(
        'ChatConversation.fromJson ids arriving as quoted strings still parse to ints',
      );
      final conversation = ChatConversation.fromJson(const {
        'id': 'abc',
        'user_id': '88',
        'delivery_boy_id': '12',
        'unread_count': '5',
      });
      printTestLog('userId → expected: 88, actual: ${conversation.userId}');
      expect(conversation.userId, 88);
      printTestLog('deliveryBoyId → expected: 12, actual: ${conversation.deliveryBoyId}');
      expect(conversation.deliveryBoyId, 12);
      printTestLog('unreadCount → expected: 5, actual: ${conversation.unreadCount}');
      expect(conversation.unreadCount, 5);
    });

    test('an empty payload degrades to blank strings and a zero unread count', () {
      printTestDivider(
        'ChatConversation.fromJson an empty payload degrades to blank strings and a zero unread count',
      );
      final conversation = ChatConversation.fromJson(const {});

      printTestLog('id → expected: "", actual: "${conversation.id}"');
      expect(conversation.id, '');
      printTestLog('type → expected: "", actual: "${conversation.type}"');
      expect(conversation.type, '');
      printTestLog('title → expected: "", actual: "${conversation.title}"');
      expect(conversation.title, '');
      printTestLog('userId → expected: null, actual: ${conversation.userId}');
      expect(conversation.userId, isNull);
      printTestLog('unreadCount → expected: 0, actual: ${conversation.unreadCount}');
      expect(conversation.unreadCount, 0);
      printTestLog('isAdminChat → expected: false, actual: ${conversation.isAdminChat}');
      expect(conversation.isAdminChat, isFalse);
    });

    test('a non-numeric unread_count falls back to 0 rather than throwing', () {
      printTestDivider(
        'ChatConversation.fromJson a non-numeric unread_count falls back to 0 rather than throwing',
      );
      final conversation = ChatConversation.fromJson(const {
        'id': 1,
        'unread_count': 'many',
      });
      printTestLog('unreadCount → expected: 0, actual: ${conversation.unreadCount}');
      expect(conversation.unreadCount, 0);
    });
  });
}
