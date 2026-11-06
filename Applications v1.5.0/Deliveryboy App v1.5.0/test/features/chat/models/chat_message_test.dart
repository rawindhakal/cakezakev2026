import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/features/chat/models/chat_message.dart';

import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Map<String, dynamic> fixture() =>
      jsonDecode(
            File('test/fixtures/chat/chat_messages.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  List<Map<String, dynamic>> fixtureMessages() =>
      ((fixture()['data'] as Map<String, dynamic>)['messages'] as List)
          .cast<Map<String, dynamic>>();

  group('ChatAttachment.fromJson (socket shape)', () {
    test('maps each attachment_type onto its enum value', () {
      printTestDivider(
        'ChatAttachment.fromJson maps each attachment_type onto its enum value',
      );
      final cases = {
        'image': AttachmentType.image,
        'audio': AttachmentType.audio,
        'video': AttachmentType.video,
        'file': AttachmentType.file,
      };
      cases.forEach((raw, expected) {
        final attachment = ChatAttachment.fromJson({
          'url': 'https://cdn.test/a',
          'file_name': 'a',
          'attachment_type': raw,
        });
        printTestLog(
          '"$raw" → expected: $expected, actual: ${attachment.type}',
        );
        expect(attachment.type, expected);
      });
    });

    test('an unknown or missing attachment_type falls back to file', () {
      printTestDivider(
        'ChatAttachment.fromJson an unknown or missing attachment_type falls back to file',
      );
      final unknown = ChatAttachment.fromJson(const {
        'attachment_type': 'hologram',
      });
      printTestLog(
        'unknown type → expected: ${AttachmentType.file}, actual: ${unknown.type}',
      );
      expect(unknown.type, AttachmentType.file);

      final missing = ChatAttachment.fromJson(const {});
      printTestLog(
        'missing type → expected: ${AttachmentType.file}, actual: ${missing.type}',
      );
      expect(missing.type, AttachmentType.file);
      printTestLog('missing url → expected: null, actual: ${missing.remoteUrl}');
      expect(missing.remoteUrl, isNull);
    });
  });

  group('ChatAttachment.fromRest (REST shape)', () {
    test('classifies by the storage path extension, case-insensitively', () {
      printTestDivider(
        'ChatAttachment.fromRest classifies by the storage path extension, case-insensitively',
      );
      final cases = {
        'chat/41/photo.JPG': AttachmentType.image,
        'chat/41/photo.webp': AttachmentType.image,
        'chat/41/clip.mp4': AttachmentType.video,
        'chat/41/clip.3gp': AttachmentType.video,
        'chat/41/voice-note.m4a': AttachmentType.audio,
        'chat/41/voice-note.caf': AttachmentType.audio,
        'chat/41/invoice.pdf': AttachmentType.file,
      };
      cases.forEach((path, expected) {
        final attachment = ChatAttachment.fromRest(
          path: path,
          url: 'https://cdn.test/$path',
        );
        printTestLog('"$path" → expected: $expected, actual: ${attachment.type}');
        expect(attachment.type, expected);
      });
    });

    test('an extensionless path is treated as a plain file', () {
      printTestDivider(
        'ChatAttachment.fromRest an extensionless path is treated as a plain file',
      );
      final attachment = ChatAttachment.fromRest(
        path: 'chat/41/receipt',
        url: 'https://cdn.test/chat/41/receipt',
      );
      printTestLog(
        'type → expected: ${AttachmentType.file}, actual: ${attachment.type}',
      );
      expect(attachment.type, AttachmentType.file);
    });

    test('fileName is the last path segment, not the whole storage path', () {
      printTestDivider(
        'ChatAttachment.fromRest fileName is the last path segment, not the whole storage path',
      );
      final attachment = ChatAttachment.fromRest(
        path: 'chat/41/gate-photo.jpg',
        url: 'https://cdn.test/storage/chat/41/gate-photo.jpg',
      );
      printTestLog(
        'fileName → expected: "gate-photo.jpg", actual: "${attachment.fileName}"',
      );
      expect(attachment.fileName, 'gate-photo.jpg');
      printTestLog(
        'remoteUrl → expected: the full url, actual: "${attachment.remoteUrl}"',
      );
      expect(
        attachment.remoteUrl,
        'https://cdn.test/storage/chat/41/gate-photo.jpg',
      );
    });
  });

  group('ChatAttachment flags and toJson', () {
    test('toJson writes the enum back as the wire string', () {
      printTestDivider(
        'ChatAttachment.toJson writes the enum back as the wire string',
      );
      for (final type in AttachmentType.values) {
        final json = ChatAttachment(
          remoteUrl: 'https://cdn.test/a',
          fileName: 'a',
          type: type,
        ).toJson();
        final expected = type.name; // image/file/audio/video map 1:1
        printTestLog(
          '$type → expected: "$expected", actual: "${json['attachment_type']}"',
        );
        expect(json['attachment_type'], expected);
      }
    });

    test('a fromJson → toJson round-trip keeps url, name and type', () {
      printTestDivider(
        'ChatAttachment fromJson → toJson round-trip keeps url, name and type',
      );
      const source = {
        'url': 'https://cdn.test/voice.m4a',
        'file_name': 'voice.m4a',
        'attachment_type': 'audio',
      };
      final json = ChatAttachment.fromJson(source).toJson();
      printTestLog('round-trip → expected: $source, actual: $json');
      expect(json, source);
    });

    test('hasRemote is false for a null or empty url', () {
      printTestDivider('ChatAttachment.hasRemote is false for a null or empty url');
      const nullUrl = ChatAttachment(type: AttachmentType.file);
      printTestLog('null url → expected: false, actual: ${nullUrl.hasRemote}');
      expect(nullUrl.hasRemote, isFalse);

      const emptyUrl = ChatAttachment(remoteUrl: '', type: AttachmentType.file);
      printTestLog('empty url → expected: false, actual: ${emptyUrl.hasRemote}');
      expect(emptyUrl.hasRemote, isFalse);
    });

    test('hasLocal reflects whether the file is actually on disk', () {
      printTestDivider(
        'ChatAttachment.hasLocal reflects whether the file is actually on disk',
      );
      final dir = Directory.systemTemp.createTempSync('chat_attachment_test_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/note.txt')..writeAsStringSync('hi');

      final present = ChatAttachment(
        localPath: file.path,
        type: AttachmentType.file,
      );
      printTestLog('existing file → expected: true, actual: ${present.hasLocal}');
      expect(present.hasLocal, isTrue);

      final missing = ChatAttachment(
        localPath: '${dir.path}/gone.txt',
        type: AttachmentType.file,
      );
      printTestLog('missing file → expected: false, actual: ${missing.hasLocal}');
      expect(missing.hasLocal, isFalse);
    });
  });

  group('ChatMessage.fromJson', () {
    test('parses every message off the real REST payload', () {
      printTestDivider(
        'ChatMessage.fromJson parses every message off the real REST payload',
      );
      final messages = fixtureMessages()
          .map((e) => ChatMessage.fromJson(e, 12))
          .toList();

      printTestLog('count → expected: 4, actual: ${messages.length}');
      expect(messages.length, 4);

      final first = messages.first;
      printTestLog('first id → expected: "901", actual: "${first.id}"');
      expect(first.id, '901');
      printTestLog('first senderId → expected: 88, actual: ${first.senderId}');
      expect(first.senderId, 88);
      printTestLog(
        'first senderType → expected: "user", actual: "${first.senderType}"',
      );
      expect(first.senderType, 'user');
      printTestLog(
        'first message → expected: "Hi, are you nearby?", actual: "${first.message}"',
      );
      expect(first.message, 'Hi, are you nearby?');
      printTestLog('first attachment → expected: null, actual: ${first.attachment}');
      expect(first.attachment, isNull);
      printTestLog(
        'default status → expected: ${MessageStatus.sent}, actual: ${first.status}',
      );
      expect(first.status, MessageStatus.sent);
    });

    test('isMe is true only for the id passed as myId', () {
      printTestDivider('ChatMessage.fromJson isMe is true only for the id passed as myId');
      final messages = fixtureMessages()
          .map((e) => ChatMessage.fromJson(e, 12))
          .toList();

      printTestLog('customer message isMe → expected: false, actual: ${messages[0].isMe}');
      expect(messages[0].isMe, isFalse);
      printTestLog('own message isMe → expected: true, actual: ${messages[1].isMe}');
      expect(messages[1].isMe, isTrue);
    });

    test('attachment_url + attachment build a REST attachment', () {
      printTestDivider(
        'ChatMessage.fromJson attachment_url + attachment build a REST attachment',
      );
      final image = ChatMessage.fromJson(fixtureMessages()[2], 12);
      printTestLog(
        'image type → expected: ${AttachmentType.image}, actual: ${image.attachment?.type}',
      );
      expect(image.attachment?.type, AttachmentType.image);
      printTestLog(
        'image fileName → expected: "gate-photo.jpg", actual: "${image.attachment?.fileName}"',
      );
      expect(image.attachment?.fileName, 'gate-photo.jpg');

      final audio = ChatMessage.fromJson(fixtureMessages()[3], 12);
      printTestLog(
        'audio type → expected: ${AttachmentType.audio}, actual: ${audio.attachment?.type}',
      );
      expect(audio.attachment?.type, AttachmentType.audio);
    });

    test('falls back to the nested socket attachment object when no attachment_url', () {
      printTestDivider(
        'ChatMessage.fromJson falls back to the nested socket attachment object when no attachment_url',
      );
      final message = ChatMessage.fromJson(const {
        'id': 55,
        'sender_id': 88,
        'sender_type': 'user',
        'message': 'look',
        'timestamp': '2026-08-19T09:10:02Z',
        'attachment': {
          'url': 'https://cdn.test/a.png',
          'file_name': 'a.png',
          'attachment_type': 'image',
        },
      }, 12);

      printTestLog(
        'type → expected: ${AttachmentType.image}, actual: ${message.attachment?.type}',
      );
      expect(message.attachment?.type, AttachmentType.image);
      printTestLog(
        'url → expected: "https://cdn.test/a.png", actual: "${message.attachment?.remoteUrl}"',
      );
      expect(message.attachment?.remoteUrl, 'https://cdn.test/a.png');
    });

    test('an empty attachment_url does not produce an attachment', () {
      printTestDivider(
        'ChatMessage.fromJson an empty attachment_url does not produce an attachment',
      );
      final message = ChatMessage.fromJson(const {
        'id': 56,
        'sender_id': 88,
        'message': 'plain',
        'attachment': null,
        'attachment_url': '',
      }, 12);
      printTestLog('attachment → expected: null, actual: ${message.attachment}');
      expect(message.attachment, isNull);
    });

    test('a missing sender_id/sender_type/message degrade to safe defaults', () {
      printTestDivider(
        'ChatMessage.fromJson a missing sender_id/sender_type/message degrade to safe defaults',
      );
      final message = ChatMessage.fromJson(const {'id': 60}, 12);
      printTestLog('senderId → expected: 0, actual: ${message.senderId}');
      expect(message.senderId, 0);
      printTestLog('senderType → expected: "", actual: "${message.senderType}"');
      expect(message.senderType, '');
      printTestLog('message → expected: "", actual: "${message.message}"');
      expect(message.message, '');
      printTestLog('isMe → expected: false, actual: ${message.isMe}');
      expect(message.isMe, isFalse);
    });

    test('sender_id arriving as a quoted string still parses', () {
      printTestDivider(
        'ChatMessage.fromJson sender_id arriving as a quoted string still parses',
      );
      final message = ChatMessage.fromJson(const {
        'id': 61,
        'sender_id': '12',
      }, 12);
      printTestLog('senderId → expected: 12, actual: ${message.senderId}');
      expect(message.senderId, 12);
      printTestLog('isMe → expected: true, actual: ${message.isMe}');
      expect(message.isMe, isTrue);
    });

    test('a missing id falls back to a non-empty generated one', () {
      printTestDivider(
        'ChatMessage.fromJson a missing id falls back to a non-empty generated one',
      );
      final message = ChatMessage.fromJson(const {'sender_id': 1}, 12);
      printTestLog('id → expected: non-empty, actual: "${message.id}"');
      expect(message.id, isNotEmpty);
    });
  });

  group('ChatMessage timestamp parsing', () {
    test('a bare wall-clock string is read as server UTC, then localized', () {
      printTestDivider(
        'ChatMessage.fromJson a bare wall-clock string is read as server UTC, then localized',
      );
      final message = ChatMessage.fromJson(const {
        'id': 1,
        'sender_id': 1,
        'created_at': '2026-08-19 09:10:02',
      }, 12);

      final utc = message.timestamp.toUtc();
      printTestLog(
        'as UTC → expected: 2026-08-19 09:10:02Z, actual: ${utc.toIso8601String()}',
      );
      expect(utc, DateTime.utc(2026, 8, 19, 9, 10, 2));
      printTestLog('isUtc → expected: false (local), actual: ${message.timestamp.isUtc}');
      expect(message.timestamp.isUtc, isFalse);
    });

    test('an explicit Z / offset suffix is honoured rather than re-interpreted', () {
      printTestDivider(
        'ChatMessage.fromJson an explicit Z / offset suffix is honoured rather than re-interpreted',
      );
      final zulu = ChatMessage.fromJson(const {
        'id': 1,
        'sender_id': 1,
        'created_at': '2026-08-19T09:10:02Z',
      }, 12);
      printTestLog(
        'Z suffix as UTC → expected: 2026-08-19 09:10:02Z, actual: ${zulu.timestamp.toUtc().toIso8601String()}',
      );
      expect(zulu.timestamp.toUtc(), DateTime.utc(2026, 8, 19, 9, 10, 2));

      final offset = ChatMessage.fromJson(const {
        'id': 1,
        'sender_id': 1,
        'created_at': '2026-08-19T14:40:02+05:30',
      }, 12);
      printTestLog(
        '+05:30 offset as UTC → expected: 2026-08-19 09:10:02Z, actual: ${offset.timestamp.toUtc().toIso8601String()}',
      );
      expect(offset.timestamp.toUtc(), DateTime.utc(2026, 8, 19, 9, 10, 2));
    });

    test('the socket `timestamp` key is used when `created_at` is absent', () {
      printTestDivider(
        'ChatMessage.fromJson the socket timestamp key is used when created_at is absent',
      );
      final message = ChatMessage.fromJson(const {
        'id': 1,
        'sender_id': 1,
        'timestamp': '2026-08-19 09:10:02',
      }, 12);
      printTestLog(
        'as UTC → expected: 2026-08-19 09:10:02Z, actual: ${message.timestamp.toUtc().toIso8601String()}',
      );
      expect(message.timestamp.toUtc(), DateTime.utc(2026, 8, 19, 9, 10, 2));
    });

    test('a missing or unparseable timestamp falls back to now', () {
      printTestDivider(
        'ChatMessage.fromJson a missing or unparseable timestamp falls back to now',
      );
      final before = DateTime.now().subtract(const Duration(seconds: 5));

      final missing = ChatMessage.fromJson(const {'id': 1, 'sender_id': 1}, 12);
      printTestLog(
        'missing → expected: after $before, actual: ${missing.timestamp}',
      );
      expect(missing.timestamp.isAfter(before), isTrue);

      final garbage = ChatMessage.fromJson(const {
        'id': 1,
        'sender_id': 1,
        'created_at': 'not-a-date',
      }, 12);
      printTestLog(
        'garbage → expected: after $before, actual: ${garbage.timestamp}',
      );
      expect(garbage.timestamp.isAfter(before), isTrue);
    });
  });

  group('ChatMessage.toJson / buildPayload / copyWith', () {
    ChatMessage sample({ChatAttachment? attachment}) => ChatMessage(
      id: '901',
      senderId: 12,
      senderType: 'delivery_boy',
      message: 'On my way',
      timestamp: DateTime.utc(2026, 8, 19, 9, 13, 5),
      isMe: true,
      attachment: attachment,
    );

    test('toJson omits the attachment key entirely when there is none', () {
      printTestDivider(
        'ChatMessage.toJson omits the attachment key entirely when there is none',
      );
      final json = sample().toJson();
      printTestLog(
        'contains attachment → expected: false, actual: ${json.containsKey('attachment')}',
      );
      expect(json.containsKey('attachment'), isFalse);
      printTestLog('sender_id → expected: 12, actual: ${json['sender_id']}');
      expect(json['sender_id'], 12);
      printTestLog(
        'timestamp → expected: 2026-08-19T09:13:05.000Z, actual: ${json['timestamp']}',
      );
      expect(json['timestamp'], '2026-08-19T09:13:05.000Z');
    });

    test('toJson nests the attachment when one is present', () {
      printTestDivider('ChatMessage.toJson nests the attachment when one is present');
      final json = sample(
        attachment: const ChatAttachment(
          remoteUrl: 'https://cdn.test/a.png',
          fileName: 'a.png',
          type: AttachmentType.image,
        ),
      ).toJson();
      printTestLog('attachment → expected: a map, actual: ${json['attachment']}');
      expect(json['attachment'], isA<Map<String, dynamic>>());
      expect(
        (json['attachment'] as Map<String, dynamic>)['attachment_type'],
        'image',
      );
    });

    test('buildPayload encodes the legacy socket frame', () {
      printTestDivider('ChatMessage.buildPayload encodes the legacy socket frame');
      final decoded =
          jsonDecode(
                ChatMessage.buildPayload(
                  senderId: 12,
                  senderType: 'delivery_boy',
                  message: 'hello',
                  roomId: 'order_1204',
                ),
              )
              as Map<String, dynamic>;

      printTestLog('type → expected: "message", actual: "${decoded['type']}"');
      expect(decoded['type'], 'message');
      printTestLog('room_id → expected: "order_1204", actual: "${decoded['room_id']}"');
      expect(decoded['room_id'], 'order_1204');
      printTestLog('sender_type → expected: "delivery_boy", actual: "${decoded['sender_type']}"');
      expect(decoded['sender_type'], 'delivery_boy');
      printTestLog(
        'attachment key → expected: absent, actual: ${decoded.containsKey('attachment')}',
      );
      expect(decoded.containsKey('attachment'), isFalse);
      printTestLog('timestamp → expected: parseable, actual: ${decoded['timestamp']}');
      expect(DateTime.tryParse(decoded['timestamp'] as String), isNotNull);
    });

    test('copyWith changes only status/attachment and keeps identity fields', () {
      printTestDivider(
        'ChatMessage.copyWith changes only status/attachment and keeps identity fields',
      );
      final original = sample();
      final failed = original.copyWith(status: MessageStatus.failed);

      printTestLog(
        'status → expected: ${MessageStatus.failed}, actual: ${failed.status}',
      );
      expect(failed.status, MessageStatus.failed);
      printTestLog('id → expected: "901", actual: "${failed.id}"');
      expect(failed.id, original.id);
      printTestLog('isMe → expected: true, actual: ${failed.isMe}');
      expect(failed.isMe, original.isMe);
      printTestLog('timestamp → expected: unchanged, actual: ${failed.timestamp}');
      expect(failed.timestamp, original.timestamp);
      printTestLog('original untouched → expected: ${MessageStatus.sent}, actual: ${original.status}');
      expect(original.status, MessageStatus.sent);
    });

    test('copyWith with no arguments keeps the existing status', () {
      printTestDivider('ChatMessage.copyWith with no arguments keeps the existing status');
      final sending = sample().copyWith(status: MessageStatus.sending);
      final untouched = sending.copyWith();
      printTestLog(
        'status → expected: ${MessageStatus.sending}, actual: ${untouched.status}',
      );
      expect(untouched.status, MessageStatus.sending);
    });
  });

  group('ChatScreenArgs.roomId', () {
    test('an order chat keys the room by order id', () {
      printTestDivider('ChatScreenArgs.roomId an order chat keys the room by order id');
      const args = ChatScreenArgs(
        chatType: ChatType.deliveryBoyChat,
        recipientName: 'Ana',
        recipientId: 88,
        orderId: '1204',
      );
      printTestLog('roomId → expected: "order_1204", actual: "${args.roomId}"');
      expect(args.roomId, 'order_1204');
    });

    test('an order chat without an order id falls back to the admin room shape', () {
      printTestDivider(
        'ChatScreenArgs.roomId an order chat without an order id falls back to the admin room shape',
      );
      const args = ChatScreenArgs(
        chatType: ChatType.deliveryBoyChat,
        recipientName: 'Ana',
        recipientId: 88,
      );
      printTestLog('roomId → expected: "admin_user_88", actual: "${args.roomId}"');
      expect(args.roomId, 'admin_user_88');
    });

    test('an admin chat keys the room by recipient id even with an order id', () {
      printTestDivider(
        'ChatScreenArgs.roomId an admin chat keys the room by recipient id even with an order id',
      );
      const args = ChatScreenArgs(
        chatType: ChatType.adminChat,
        recipientName: 'Support',
        recipientId: 4,
        orderId: '1204',
      );
      printTestLog('roomId → expected: "admin_user_4", actual: "${args.roomId}"');
      expect(args.roomId, 'admin_user_4');
    });
  });
}
