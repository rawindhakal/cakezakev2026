import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/features/chat/models/chat_message.dart';
import 'package:deliveryboy/features/chat/repositories/chat_repository.dart';

import '../../../helpers/mock_api_client.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockApiClient mockApiClient;
  late ChatRepository repository;
  late Directory tempDir;

  setUpAll(registerApiClientFallbackValues);

  setUp(() {
    mockApiClient = MockApiClient();
    repository = ChatRepository(apiClient: mockApiClient);
    tempDir = Directory.systemTemp.createTempSync('chat_repository_test_');
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Map<String, dynamic> jsonFixture(String name) =>
      jsonDecode(File('test/fixtures/chat/$name.json').readAsStringSync())
          as Map<String, dynamic>;

  /// A real on-disk file, since `MultipartFile.fromFile` reads it eagerly.
  String tempFile(String name) {
    final file = File('${tempDir.path}/$name')..writeAsBytesSync([1, 2, 3, 4]);
    return file.path;
  }

  group('startAdminConversation', () {
    test('posts to chat/start_admin and parses the conversation', () async {
      printTestDivider(
        'startAdminConversation posts to chat/start_admin and parses the conversation',
      );
      when(
        () => mockApiClient.post(ApiEndpoints.chatStartAdmin),
      ).thenAnswer((_) async => jsonFixture('chat_start_admin'));

      final conversation = await repository.startAdminConversation();

      verify(() => mockApiClient.post(ApiEndpoints.chatStartAdmin)).called(1);
      printTestLog('id → expected: "7", actual: "${conversation.id}"');
      expect(conversation.id, '7');
      printTestLog(
        'isAdminChat → expected: true, actual: ${conversation.isAdminChat}',
      );
      expect(conversation.isAdminChat, isTrue);
    });
  });

  group('startOrderConversation', () {
    Map<String, dynamic> capturedBody() =>
        verify(
              () => mockApiClient.post(
                ApiEndpoints.chatStartOrder,
                data: captureAny(named: 'data'),
              ),
            ).captured.single
            as Map<String, dynamic>;

    void stubStartOrder() {
      when(
        () => mockApiClient.post(
          ApiEndpoints.chatStartOrder,
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => {
          'data': {'id': 41, 'type': 'delivery_boy_customer', 'order_id': 1204},
        },
      );
    }

    test('sends the order id and parses the conversation', () async {
      printTestDivider(
        'startOrderConversation sends the order id and parses the conversation',
      );
      stubStartOrder();

      final conversation = await repository.startOrderConversation(
        orderId: '1204',
      );

      final body = capturedBody();
      printTestLog(
        'order_id → expected: "1204", actual: ${body[ApiParameters.orderId]}',
      );
      expect(body[ApiParameters.orderId], '1204');
      printTestLog('id → expected: "41", actual: "${conversation.id}"');
      expect(conversation.id, '41');
    });

    test('includes order_item_id only when one is given', () async {
      printTestDivider(
        'startOrderConversation includes order_item_id only when one is given',
      );
      stubStartOrder();

      await repository.startOrderConversation(
        orderId: '1204',
        orderItemId: '9001',
      );

      final body = capturedBody();
      printTestLog(
        'order_item_id → expected: "9001", actual: ${body[ApiParameters.orderItemId]}',
      );
      expect(body[ApiParameters.orderItemId], '9001');
    });

    test('omits order_item_id when it is null or empty', () async {
      printTestDivider(
        'startOrderConversation omits order_item_id when it is null or empty',
      );
      stubStartOrder();

      await repository.startOrderConversation(orderId: '1204');
      await repository.startOrderConversation(orderId: '1204', orderItemId: '');

      final bodies = verify(
        () => mockApiClient.post(
          ApiEndpoints.chatStartOrder,
          data: captureAny(named: 'data'),
        ),
      ).captured.cast<Map<String, dynamic>>();

      for (final body in bodies) {
        printTestLog(
          'contains order_item_id → expected: false, actual: ${body.containsKey(ApiParameters.orderItemId)}',
        );
        expect(body.containsKey(ApiParameters.orderItemId), isFalse);
      }
    });
  });

  group('getMessages', () {
    void stubGet([Map<String, dynamic>? response]) {
      when(
        () => mockApiClient.get(
          ApiEndpoints.chatMessages,
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => response ?? jsonFixture('chat_messages'));
    }

    Map<String, dynamic> capturedQuery() =>
        verify(
              () => mockApiClient.get(
                ApiEndpoints.chatMessages,
                queryParameters: captureAny(named: 'queryParameters'),
              ),
            ).captured.single
            as Map<String, dynamic>;

    test('sends the conversation id with a default offset/limit', () async {
      printTestDivider(
        'getMessages sends the conversation id with a default offset/limit',
      );
      stubGet();

      await repository.getMessages(conversationId: '41', myId: 12);

      final query = capturedQuery();
      printTestLog(
        'conversation_id → expected: "41", actual: ${query[ApiParameters.conversationId]}',
      );
      expect(query[ApiParameters.conversationId], '41');
      printTestLog('offset → expected: 0, actual: ${query[ApiParameters.offset]}');
      expect(query[ApiParameters.offset], 0);
      printTestLog('limit → expected: 20, actual: ${query[ApiParameters.limit]}');
      expect(query[ApiParameters.limit], 20);
    });

    test('forwards a custom offset/limit', () async {
      printTestDivider('getMessages forwards a custom offset/limit');
      stubGet();

      await repository.getMessages(
        conversationId: '41',
        myId: 12,
        offset: 40,
        limit: 5,
      );

      final query = capturedQuery();
      printTestLog('offset → expected: 40, actual: ${query[ApiParameters.offset]}');
      expect(query[ApiParameters.offset], 40);
      printTestLog('limit → expected: 5, actual: ${query[ApiParameters.limit]}');
      expect(query[ApiParameters.limit], 5);
    });

    test('parses the nested messages array and marks own messages', () async {
      printTestDivider(
        'getMessages parses the nested messages array and marks own messages',
      );
      stubGet();

      final messages = await repository.getMessages(
        conversationId: '41',
        myId: 12,
      );

      printTestLog('count → expected: 4, actual: ${messages.length}');
      expect(messages.length, 4);
      printTestLog('first id → expected: "901", actual: "${messages.first.id}"');
      expect(messages.first.id, '901');
      printTestLog('first isMe → expected: false, actual: ${messages.first.isMe}');
      expect(messages.first.isMe, isFalse);
      printTestLog('second isMe → expected: true, actual: ${messages[1].isMe}');
      expect(messages[1].isMe, isTrue);
      printTestLog(
        'image attachment → expected: ${AttachmentType.image}, actual: ${messages[2].attachment?.type}',
      );
      expect(messages[2].attachment?.type, AttachmentType.image);
    });

    test('returns an empty list when data is not the expected envelope', () async {
      printTestDivider(
        'getMessages returns an empty list when data is not the expected envelope',
      );
      stubGet(const {'data': 'unexpected'});

      final messages = await repository.getMessages(
        conversationId: '41',
        myId: 12,
      );
      printTestLog('count → expected: 0, actual: ${messages.length}');
      expect(messages, isEmpty);
    });

    test('returns an empty list when messages is missing or not a list', () async {
      printTestDivider(
        'getMessages returns an empty list when messages is missing or not a list',
      );
      stubGet(const {
        'data': {'conversation': {}, 'messages': null},
      });

      final messages = await repository.getMessages(
        conversationId: '41',
        myId: 12,
      );
      printTestLog('count → expected: 0, actual: ${messages.length}');
      expect(messages, isEmpty);
    });
  });

  group('getBroadcastAuth', () {
    test('posts socket_id + channel_name to broadcasting/auth', () async {
      printTestDivider(
        'getBroadcastAuth posts socket_id + channel_name to broadcasting/auth',
      );
      when(
        () => mockApiClient.postRaw(
          ApiEndpoints.broadcastingAuth,
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => {'auth': 'key:signature'});

      final auth = await repository.getBroadcastAuth(
        socketId: '123.456',
        channelName: 'private-chat.conversation.41',
      );

      final body =
          verify(
                () => mockApiClient.postRaw(
                  ApiEndpoints.broadcastingAuth,
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      printTestLog(
        'socket_id → expected: "123.456", actual: ${body[ApiParameters.socketId]}',
      );
      expect(body[ApiParameters.socketId], '123.456');
      printTestLog(
        'channel_name → expected: "private-chat.conversation.41", actual: ${body[ApiParameters.channelName]}',
      );
      expect(body[ApiParameters.channelName], 'private-chat.conversation.41');
      printTestLog('auth → expected: "key:signature", actual: "${auth['auth']}"');
      expect(auth['auth'], 'key:signature');
    });

    test('decodes a JSON body that arrived as a raw String', () async {
      printTestDivider(
        'getBroadcastAuth decodes a JSON body that arrived as a raw String',
      );
      // Dio only auto-decodes when the content-type says JSON; this endpoint
      // sometimes replies with a mismatched one, leaving a String behind.
      when(
        () => mockApiClient.postRaw(
          ApiEndpoints.broadcastingAuth,
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => '{"auth":"key:signature"}');

      final auth = await repository.getBroadcastAuth(
        socketId: '123.456',
        channelName: 'private-chat.conversation.41',
      );
      printTestLog('auth → expected: "key:signature", actual: "${auth['auth']}"');
      expect(auth['auth'], 'key:signature');
    });
  });

  group('sendMessage', () {
    void stubUpload([Map<String, dynamic>? response]) {
      when(
        () => mockApiClient.upload(
          ApiEndpoints.sendChatMessage,
          formData: any(named: 'formData'),
        ),
      ).thenAnswer((_) async => response ?? jsonFixture('chat_send_message'));
    }

    FormData capturedFormData() =>
        verify(
              () => mockApiClient.upload(
                ApiEndpoints.sendChatMessage,
                formData: captureAny(named: 'formData'),
              ),
            ).captured.single
            as FormData;

    test('uploads conversation_id + message and parses the returned rows', () async {
      printTestDivider(
        'sendMessage uploads conversation_id + message and parses the returned rows',
      );
      stubUpload();

      final sent = await repository.sendMessage(
        conversationId: '41',
        message: 'On my way',
        myId: 12,
      );

      final fields = Map.fromEntries(capturedFormData().fields);
      printTestLog(
        'conversation_id → expected: "41", actual: "${fields[ApiParameters.conversationId]}"',
      );
      expect(fields[ApiParameters.conversationId], '41');
      printTestLog(
        'message → expected: "On my way", actual: "${fields[ApiParameters.message]}"',
      );
      expect(fields[ApiParameters.message], 'On my way');
      printTestLog('count → expected: 1, actual: ${sent.length}');
      expect(sent.length, 1);
      printTestLog('id → expected: "905", actual: "${sent.first.id}"');
      expect(sent.first.id, '905');
      printTestLog('isMe → expected: true, actual: ${sent.first.isMe}');
      expect(sent.first.isMe, isTrue);
    });

    test('attaches each media kind under its own multipart key', () async {
      printTestDivider(
        'sendMessage attaches each media kind under its own multipart key',
      );
      stubUpload();

      await repository.sendMessage(
        conversationId: '41',
        message: '',
        myId: 12,
        imagePaths: [tempFile('photo.jpg')],
        audioPaths: [tempFile('voice.m4a')],
        videoPaths: [tempFile('clip.mp4')],
        filePaths: [tempFile('invoice.pdf')],
      );

      final files = capturedFormData().files;
      final keys = files.map((e) => e.key).toList();
      printTestLog(
        'keys → expected: images[]/audios[]/videos[]/files[], actual: $keys',
      );
      expect(
        keys,
        containsAll([
          ApiParameters.images,
          ApiParameters.audios,
          ApiParameters.videos,
          ApiParameters.files,
        ]),
      );

      final imageEntry = files.firstWhere((e) => e.key == ApiParameters.images);
      printTestLog(
        'image filename → expected: "photo.jpg", actual: "${imageEntry.value.filename}"',
      );
      expect(imageEntry.value.filename, 'photo.jpg');
    });

    test('sends no file parts at all when every path list is null or empty', () async {
      printTestDivider(
        'sendMessage sends no file parts at all when every path list is null or empty',
      );
      stubUpload();

      await repository.sendMessage(
        conversationId: '41',
        message: 'text only',
        myId: 12,
        imagePaths: const [],
        audioPaths: null,
        videoPaths: const [],
        filePaths: null,
      );

      final files = capturedFormData().files;
      printTestLog('file part count → expected: 0, actual: ${files.length}');
      expect(files, isEmpty);
    });

    test('returns an empty list when data is not an array', () async {
      printTestDivider('sendMessage returns an empty list when data is not an array');
      stubUpload(const {'data': null});

      final sent = await repository.sendMessage(
        conversationId: '41',
        message: 'hi',
        myId: 12,
      );
      printTestLog('count → expected: 0, actual: ${sent.length}');
      expect(sent, isEmpty);
    });
  });

  group('downloadAttachment', () {
    test('delegates the url and save path straight to the api client', () async {
      printTestDivider(
        'downloadAttachment delegates the url and save path straight to the api client',
      );
      when(
        () => mockApiClient.downloadFile(any(), any()),
      ).thenAnswer((_) async {});

      await repository.downloadAttachment(
        'https://cdn.test/a.pdf',
        '/tmp/a.pdf',
      );

      verify(
        () => mockApiClient.downloadFile('https://cdn.test/a.pdf', '/tmp/a.pdf'),
      ).called(1);
      printTestLog('downloadFile called → expected: once, actual: once');
    });
  });
}
