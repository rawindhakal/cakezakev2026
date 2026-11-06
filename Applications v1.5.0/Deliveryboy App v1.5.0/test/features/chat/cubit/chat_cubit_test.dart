import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/features/chat/cubit/chat_cubit.dart';
import 'package:deliveryboy/features/chat/models/chat_message.dart';
import 'package:deliveryboy/features/chat/services/chat_socket_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/fake_chat_socket_service.dart';
import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_chat_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  const myId = 12;
  const conversationId = '41';
  const roomId = 'order_1204';

  late MockChatRepository repository;
  late FakeChatSocketService socket;

  setUp(() async {
    await HiveTestHelper.setUp(authBox);
    await Hive.box(authBox).put(kUserId, '$myId');
    repository = MockChatRepository();
    socket = FakeChatSocketService();
  });

  tearDown(() async {
    ChatCubit.active = null;
    await HiveTestHelper.tearDown(authBox);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  ChatMessage message({
    required String id,
    int senderId = 88,
    String text = 'hello',
    DateTime? at,
  }) => ChatMessage(
    id: id,
    senderId: senderId,
    senderType: senderId == myId ? 'delivery_boy' : 'user',
    message: text,
    timestamp: at ?? DateTime(2026, 8, 19, 9, 10),
    isMe: senderId == myId,
  );

  ChatCubit buildCubit() =>
      ChatCubit(repository: repository, socket: socket);

  void stubHistory(List<ChatMessage> messages, {int? offset}) {
    when(
      () => repository.getMessages(
        conversationId: conversationId,
        myId: myId,
        offset: offset ?? any(named: 'offset'),
      ),
    ).thenAnswer((_) async => messages);
  }

  List<ChatMessage> messagesOf(ChatState state) => switch (state) {
    ChatConnected s => s.messages,
    ChatReconnecting s => s.messages,
    ChatDisconnected s => s.messages,
    _ => const <ChatMessage>[],
  };

  group('connect', () {
    test('loads REST history and hands the room + channel to the socket', () async {
      printTestDivider(
        'ChatCubit.connect loads REST history and hands the room + channel to the socket',
      );
      stubHistory([message(id: '901'), message(id: '902', senderId: myId)]);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.connect(roomId, conversationId: conversationId);

      verify(
        () => repository.getMessages(
          conversationId: conversationId,
          myId: myId,
          offset: 0,
        ),
      ).called(1);
      printTestLog(
        'connect call → expected: (order_1204, 41), actual: ${socket.connectCalls.single}',
      );
      expect(socket.connectCalls.single.roomId, roomId);
      expect(socket.connectCalls.single.channelId, conversationId);
      printTestLog(
        'conversationId → expected: "41", actual: "${cubit.conversationId}"',
      );
      expect(cubit.conversationId, conversationId);
    });

    test('registers itself as the active chat cubit', () async {
      printTestDivider('ChatCubit.connect registers itself as the active chat cubit');
      stubHistory([]);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.connect(roomId, conversationId: conversationId);

      printTestLog(
        'ChatCubit.active → expected: this cubit, actual: ${identical(ChatCubit.active, cubit)}',
      );
      expect(identical(ChatCubit.active, cubit), isTrue);
    });

    test('emits ChatConnecting first', () async {
      printTestDivider('ChatCubit.connect emits ChatConnecting first');
      stubHistory([]);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      final states = <ChatState>[];
      cubit.stream.listen(states.add);

      await cubit.connect(roomId, conversationId: conversationId);
      await Future<void>.delayed(Duration.zero);

      printTestLog(
        'first state → expected: ChatConnecting, actual: ${states.first.runtimeType}',
      );
      expect(states.first, isA<ChatConnecting>());
    });

    test('skips the history call entirely when there is no conversation id', () async {
      printTestDivider(
        'ChatCubit.connect skips the history call entirely when there is no conversation id',
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.connect(roomId);

      verifyNever(
        () => repository.getMessages(
          conversationId: any(named: 'conversationId'),
          myId: any(named: 'myId'),
          offset: any(named: 'offset'),
        ),
      );
      printTestLog(
        'channelId → expected: null, actual: ${socket.connectCalls.single.channelId}',
      );
      expect(socket.connectCalls.single.channelId, isNull);
    });

    test('a failed history load still connects the socket', () async {
      printTestDivider('ChatCubit.connect a failed history load still connects the socket');
      when(
        () => repository.getMessages(
          conversationId: any(named: 'conversationId'),
          myId: any(named: 'myId'),
          offset: any(named: 'offset'),
        ),
      ).thenThrow(ApiException(message: 'boom'));
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.connect(roomId, conversationId: conversationId);
      socket.emitState(SocketConnectionState.connected);
      await Future<void>.delayed(Duration.zero);

      printTestLog(
        'state → expected: ChatConnected, actual: ${cubit.state.runtimeType}',
      );
      expect(cubit.state, isA<ChatConnected>());
      printTestLog('messages → expected: 0, actual: ${messagesOf(cubit.state).length}');
      expect(messagesOf(cubit.state), isEmpty);
    });
  });

  group('socket connection state', () {
    test('connected surfaces the loaded history', () async {
      printTestDivider('ChatCubit connected surfaces the loaded history');
      stubHistory([message(id: '901')]);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.connect(roomId, conversationId: conversationId);

      socket.emitState(SocketConnectionState.connected);
      await Future<void>.delayed(Duration.zero);

      printTestLog('state → expected: ChatConnected, actual: ${cubit.state.runtimeType}');
      expect(cubit.state, isA<ChatConnected>());
      printTestLog('messages → expected: 1, actual: ${messagesOf(cubit.state).length}');
      expect(messagesOf(cubit.state).length, 1);
    });

    test('reconnecting and disconnected both keep the messages on screen', () async {
      printTestDivider(
        'ChatCubit reconnecting and disconnected both keep the messages on screen',
      );
      stubHistory([message(id: '901')]);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.connect(roomId, conversationId: conversationId);

      socket.emitState(SocketConnectionState.reconnecting);
      await Future<void>.delayed(Duration.zero);
      printTestLog(
        'reconnecting → expected: ChatReconnecting w/ 1 message, actual: ${cubit.state.runtimeType} w/ ${messagesOf(cubit.state).length}',
      );
      expect(cubit.state, isA<ChatReconnecting>());
      expect(messagesOf(cubit.state).length, 1);

      socket.emitState(SocketConnectionState.disconnected);
      await Future<void>.delayed(Duration.zero);
      printTestLog(
        'disconnected → expected: ChatDisconnected w/ 1 message, actual: ${cubit.state.runtimeType} w/ ${messagesOf(cubit.state).length}',
      );
      expect(cubit.state, isA<ChatDisconnected>());
      expect(messagesOf(cubit.state).length, 1);
    });

    test('a retry pass through `connecting` keeps history instead of re-skeletoning', () async {
      printTestDivider(
        'ChatCubit a retry pass through connecting keeps history instead of re-skeletoning',
      );
      stubHistory([message(id: '901')]);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.connect(roomId, conversationId: conversationId);

      socket.emitState(SocketConnectionState.connecting);
      await Future<void>.delayed(Duration.zero);

      printTestLog(
        'state → expected: ChatReconnecting, actual: ${cubit.state.runtimeType}',
      );
      expect(cubit.state, isA<ChatReconnecting>());
      expect(messagesOf(cubit.state).length, 1);
    });

    test('`connecting` with nothing loaded yet still shows the skeleton state', () async {
      printTestDivider(
        'ChatCubit connecting with nothing loaded yet still shows the skeleton state',
      );
      stubHistory([]);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.connect(roomId, conversationId: conversationId);
      socket.emitState(SocketConnectionState.disconnected);
      await Future<void>.delayed(Duration.zero);

      socket.emitState(SocketConnectionState.connecting);
      await Future<void>.delayed(Duration.zero);

      printTestLog('state → expected: ChatConnecting, actual: ${cubit.state.runtimeType}');
      expect(cubit.state, isA<ChatConnecting>());
    });
  });

  group('inbound socket messages', () {
    test('an unseen message is appended to the list', () async {
      printTestDivider('ChatCubit an unseen message is appended to the list');
      stubHistory([message(id: '901')]);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.connect(roomId, conversationId: conversationId);
      socket.emitState(SocketConnectionState.connected);
      await Future<void>.delayed(Duration.zero);

      socket.emitMessage(message(id: '902', text: 'new one'));
      await Future<void>.delayed(Duration.zero);

      final messages = messagesOf(cubit.state);
      printTestLog('count → expected: 2, actual: ${messages.length}');
      expect(messages.length, 2);
      printTestLog('last message → expected: "new one", actual: "${messages.last.message}"');
      expect(messages.last.message, 'new one');
    });

    test('the server echo of a message already held replaces it instead of duplicating', () async {
      printTestDivider(
        'ChatCubit the server echo of a message already held replaces it instead of duplicating',
      );
      stubHistory([message(id: '901', text: 'original')]);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.connect(roomId, conversationId: conversationId);
      socket.emitState(SocketConnectionState.connected);
      await Future<void>.delayed(Duration.zero);

      socket.emitMessage(message(id: '901', text: 'edited'));
      await Future<void>.delayed(Duration.zero);

      final messages = messagesOf(cubit.state);
      printTestLog('count → expected: 1, actual: ${messages.length}');
      expect(messages.length, 1);
      printTestLog('message → expected: "edited", actual: "${messages.single.message}"');
      expect(messages.single.message, 'edited');
    });
  });

  group('sendMessage', () {
    setUp(() {
      when(
        () => repository.sendMessage(
          conversationId: any(named: 'conversationId'),
          message: any(named: 'message'),
          myId: any(named: 'myId'),
          imagePaths: any(named: 'imagePaths'),
          audioPaths: any(named: 'audioPaths'),
          videoPaths: any(named: 'videoPaths'),
          filePaths: any(named: 'filePaths'),
        ),
      ).thenAnswer((_) async => [message(id: '905', senderId: myId, text: 'On my way')]);
    });

    Future<ChatCubit> connected() async {
      stubHistory([]);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.connect(roomId, conversationId: conversationId);
      socket.emitState(SocketConnectionState.connected);
      await Future<void>.delayed(Duration.zero);
      return cubit;
    }

    test('ignores an empty message with no attachment', () async {
      printTestDivider('ChatCubit.sendMessage ignores an empty message with no attachment');
      final cubit = await connected();

      await cubit.sendMessage('   ');

      verifyNever(
        () => repository.sendMessage(
          conversationId: any(named: 'conversationId'),
          message: any(named: 'message'),
          myId: any(named: 'myId'),
        ),
      );
      printTestLog('messages → expected: 0, actual: ${messagesOf(cubit.state).length}');
      expect(messagesOf(cubit.state), isEmpty);
    });

    test('shows the message optimistically, then swaps in the server row', () async {
      printTestDivider(
        'ChatCubit.sendMessage shows the message optimistically, then swaps in the server row',
      );
      final cubit = await connected();
      final seen = <List<ChatMessage>>[];
      cubit.stream.listen((s) => seen.add(messagesOf(s)));

      await cubit.sendMessage('  On my way  ');
      await Future<void>.delayed(Duration.zero);

      printTestLog(
        'optimistic status → expected: ${MessageStatus.sending}, actual: ${seen.first.single.status}',
      );
      expect(seen.first.single.status, MessageStatus.sending);
      printTestLog('trimmed text → expected: "On my way", actual: "${seen.first.single.message}"');
      expect(seen.first.single.message, 'On my way');

      final messages = messagesOf(cubit.state);
      printTestLog('final count → expected: 1, actual: ${messages.length}');
      expect(messages.length, 1);
      printTestLog('final id → expected: "905", actual: "${messages.single.id}"');
      expect(messages.single.id, '905');
      printTestLog(
        'final status → expected: ${MessageStatus.sent}, actual: ${messages.single.status}',
      );
      expect(messages.single.status, MessageStatus.sent);
    });

    test('a realtime echo that landed first is not left behind as a duplicate', () async {
      printTestDivider(
        'ChatCubit.sendMessage a realtime echo that landed first is not left behind as a duplicate',
      );
      final cubit = await connected();
      // The broadcast of the same row arrives while the REST call is in flight.
      socket.emitMessage(message(id: '905', senderId: myId, text: 'On my way'));
      await Future<void>.delayed(Duration.zero);

      await cubit.sendMessage('On my way');
      await Future<void>.delayed(Duration.zero);

      final messages = messagesOf(cubit.state);
      printTestLog('count → expected: 1, actual: ${messages.length}');
      expect(messages.length, 1);
      printTestLog('id → expected: "905", actual: "${messages.single.id}"');
      expect(messages.single.id, '905');
    });

    test('routes an image attachment onto imagePaths only', () async {
      printTestDivider('ChatCubit.sendMessage routes an image attachment onto imagePaths only');
      final cubit = await connected();

      await cubit.sendMessage(
        'look',
        attachment: const ChatAttachment(
          localPath: '/tmp/photo.jpg',
          type: AttachmentType.image,
        ),
      );

      final call = verify(
        () => repository.sendMessage(
          conversationId: any(named: 'conversationId'),
          message: any(named: 'message'),
          myId: any(named: 'myId'),
          imagePaths: captureAny(named: 'imagePaths'),
          audioPaths: captureAny(named: 'audioPaths'),
          videoPaths: captureAny(named: 'videoPaths'),
          filePaths: captureAny(named: 'filePaths'),
        ),
      ).captured;
      printTestLog('imagePaths → expected: [/tmp/photo.jpg], actual: ${call[0]}');
      expect(call[0], ['/tmp/photo.jpg']);
      printTestLog('audioPaths → expected: null, actual: ${call[1]}');
      expect(call[1], isNull);
      printTestLog('videoPaths → expected: null, actual: ${call[2]}');
      expect(call[2], isNull);
      printTestLog('filePaths → expected: null, actual: ${call[3]}');
      expect(call[3], isNull);
    });

    test('routes an audio attachment onto audioPaths only', () async {
      printTestDivider('ChatCubit.sendMessage routes an audio attachment onto audioPaths only');
      final cubit = await connected();

      await cubit.sendMessage(
        '',
        attachment: const ChatAttachment(
          localPath: '/tmp/voice.m4a',
          type: AttachmentType.audio,
        ),
      );

      final call = verify(
        () => repository.sendMessage(
          conversationId: any(named: 'conversationId'),
          message: any(named: 'message'),
          myId: any(named: 'myId'),
          imagePaths: captureAny(named: 'imagePaths'),
          audioPaths: captureAny(named: 'audioPaths'),
          videoPaths: captureAny(named: 'videoPaths'),
          filePaths: captureAny(named: 'filePaths'),
        ),
      ).captured;
      printTestLog('audioPaths → expected: [/tmp/voice.m4a], actual: ${call[1]}');
      expect(call[1], ['/tmp/voice.m4a']);
      printTestLog('imagePaths → expected: null, actual: ${call[0]}');
      expect(call[0], isNull);
    });

    test('marks the message failed when the send throws', () async {
      printTestDivider('ChatCubit.sendMessage marks the message failed when the send throws');
      final cubit = await connected();
      when(
        () => repository.sendMessage(
          conversationId: any(named: 'conversationId'),
          message: any(named: 'message'),
          myId: any(named: 'myId'),
          imagePaths: any(named: 'imagePaths'),
          audioPaths: any(named: 'audioPaths'),
          videoPaths: any(named: 'videoPaths'),
          filePaths: any(named: 'filePaths'),
        ),
      ).thenThrow(ApiException(message: 'offline'));

      await cubit.sendMessage('On my way');

      final messages = messagesOf(cubit.state);
      printTestLog('count → expected: 1, actual: ${messages.length}');
      expect(messages.length, 1);
      printTestLog(
        'status → expected: ${MessageStatus.failed}, actual: ${messages.single.status}',
      );
      expect(messages.single.status, MessageStatus.failed);
    });

    test('marks the message failed without calling the api when no conversation exists', () async {
      printTestDivider(
        'ChatCubit.sendMessage marks the message failed without calling the api when no conversation exists',
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.connect(roomId);
      socket.emitState(SocketConnectionState.connected);
      await Future<void>.delayed(Duration.zero);

      await cubit.sendMessage('hello?');

      verifyNever(
        () => repository.sendMessage(
          conversationId: any(named: 'conversationId'),
          message: any(named: 'message'),
          myId: any(named: 'myId'),
          imagePaths: any(named: 'imagePaths'),
          audioPaths: any(named: 'audioPaths'),
          videoPaths: any(named: 'videoPaths'),
          filePaths: any(named: 'filePaths'),
        ),
      );
      printTestLog(
        'status → expected: ${MessageStatus.failed}, actual: ${messagesOf(cubit.state).single.status}',
      );
      expect(messagesOf(cubit.state).single.status, MessageStatus.failed);
    });

    test('an empty server response keeps the optimistic row, marked sent', () async {
      printTestDivider(
        'ChatCubit.sendMessage an empty server response keeps the optimistic row, marked sent',
      );
      final cubit = await connected();
      when(
        () => repository.sendMessage(
          conversationId: any(named: 'conversationId'),
          message: any(named: 'message'),
          myId: any(named: 'myId'),
          imagePaths: any(named: 'imagePaths'),
          audioPaths: any(named: 'audioPaths'),
          videoPaths: any(named: 'videoPaths'),
          filePaths: any(named: 'filePaths'),
        ),
      ).thenAnswer((_) async => []);

      await cubit.sendMessage('On my way');

      final messages = messagesOf(cubit.state);
      printTestLog('count → expected: 1, actual: ${messages.length}');
      expect(messages.length, 1);
      printTestLog(
        'status → expected: ${MessageStatus.sent}, actual: ${messages.single.status}',
      );
      expect(messages.single.status, MessageStatus.sent);
      printTestLog('id → expected: a local_ id, actual: "${messages.single.id}"');
      expect(messages.single.id, startsWith('local_'));
    });
  });

  group('loadOlderMessages', () {
    test('fetches from the offset already held and prepends the page', () async {
      printTestDivider(
        'ChatCubit.loadOlderMessages fetches from the offset already held and prepends the page',
      );
      stubHistory([message(id: '903'), message(id: '904')], offset: 0);
      stubHistory([message(id: '901'), message(id: '902')], offset: 2);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.connect(roomId, conversationId: conversationId);
      socket.emitState(SocketConnectionState.connected);
      await Future<void>.delayed(Duration.zero);

      await cubit.loadOlderMessages();

      final ids = messagesOf(cubit.state).map((m) => m.id).toList();
      printTestLog('ids → expected: [901, 902, 903, 904], actual: $ids');
      expect(ids, ['901', '902', '903', '904']);
    });

    test('an empty older page leaves the current state untouched', () async {
      printTestDivider(
        'ChatCubit.loadOlderMessages an empty older page leaves the current state untouched',
      );
      stubHistory([message(id: '903')], offset: 0);
      stubHistory([], offset: 1);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.connect(roomId, conversationId: conversationId);
      socket.emitState(SocketConnectionState.connected);
      await Future<void>.delayed(Duration.zero);
      final before = cubit.state;

      await cubit.loadOlderMessages();

      printTestLog(
        'state identity → expected: unchanged, actual: ${identical(before, cubit.state)}',
      );
      expect(identical(before, cubit.state), isTrue);
    });

    test('keeps a disconnected screen disconnected while still adding history', () async {
      printTestDivider(
        'ChatCubit.loadOlderMessages keeps a disconnected screen disconnected while still adding history',
      );
      stubHistory([message(id: '903')], offset: 0);
      stubHistory([message(id: '901')], offset: 1);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.connect(roomId, conversationId: conversationId);
      socket.emitState(SocketConnectionState.disconnected);
      await Future<void>.delayed(Duration.zero);

      await cubit.loadOlderMessages();

      printTestLog('state → expected: ChatDisconnected, actual: ${cubit.state.runtimeType}');
      expect(cubit.state, isA<ChatDisconnected>());
      printTestLog('count → expected: 2, actual: ${messagesOf(cubit.state).length}');
      expect(messagesOf(cubit.state).length, 2);
    });

    test('does nothing at all without a conversation id', () async {
      printTestDivider('ChatCubit.loadOlderMessages does nothing at all without a conversation id');
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.connect(roomId);

      await cubit.loadOlderMessages();

      verifyNever(
        () => repository.getMessages(
          conversationId: any(named: 'conversationId'),
          myId: any(named: 'myId'),
          offset: any(named: 'offset'),
        ),
      );
      printTestLog('no history call → expected: none, actual: none');
    });

    test('a failing page load is swallowed rather than surfacing an error state', () async {
      printTestDivider(
        'ChatCubit.loadOlderMessages a failing page load is swallowed rather than surfacing an error state',
      );
      stubHistory([message(id: '903')], offset: 0);
      when(
        () => repository.getMessages(
          conversationId: conversationId,
          myId: myId,
          offset: 1,
        ),
      ).thenThrow(ApiException(message: 'boom'));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.connect(roomId, conversationId: conversationId);
      socket.emitState(SocketConnectionState.connected);
      await Future<void>.delayed(Duration.zero);

      await cubit.loadOlderMessages();

      printTestLog('state → expected: ChatConnected, actual: ${cubit.state.runtimeType}');
      expect(cubit.state, isA<ChatConnected>());
      printTestLog('count → expected: 1, actual: ${messagesOf(cubit.state).length}');
      expect(messagesOf(cubit.state).length, 1);
    });
  });

  group('refreshFromNotification', () {
    test('pulls in a message the dead socket never delivered', () async {
      printTestDivider(
        'ChatCubit.refreshFromNotification pulls in a message the dead socket never delivered',
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      stubHistory([message(id: '901', at: DateTime(2026, 8, 19, 9, 10))]);
      await cubit.connect(roomId, conversationId: conversationId);
      socket.emitState(SocketConnectionState.disconnected);
      await Future<void>.delayed(Duration.zero);

      stubHistory([
        message(id: '901', at: DateTime(2026, 8, 19, 9, 10)),
        message(id: '902', text: 'missed you', at: DateTime(2026, 8, 19, 9, 15)),
      ]);
      await cubit.refreshFromNotification();

      final messages = messagesOf(cubit.state);
      printTestLog('count → expected: 2, actual: ${messages.length}');
      expect(messages.length, 2);
      printTestLog('last → expected: "missed you", actual: "${messages.last.message}"');
      expect(messages.last.message, 'missed you');
      printTestLog('state → expected: ChatConnected, actual: ${cubit.state.runtimeType}');
      expect(cubit.state, isA<ChatConnected>());
    });

    test('re-sorts the merged list by timestamp', () async {
      printTestDivider('ChatCubit.refreshFromNotification re-sorts the merged list by timestamp');
      final cubit = buildCubit();
      addTearDown(cubit.close);
      stubHistory([message(id: '902', at: DateTime(2026, 8, 19, 9, 15))]);
      await cubit.connect(roomId, conversationId: conversationId);
      socket.emitState(SocketConnectionState.disconnected);
      await Future<void>.delayed(Duration.zero);

      stubHistory([
        message(id: '901', at: DateTime(2026, 8, 19, 9, 10)),
        message(id: '902', at: DateTime(2026, 8, 19, 9, 15)),
      ]);
      await cubit.refreshFromNotification();

      final ids = messagesOf(cubit.state).map((m) => m.id).toList();
      printTestLog('ids → expected: [901, 902], actual: $ids');
      expect(ids, ['901', '902']);
    });

    test('emits nothing when the refresh brings no new message', () async {
      printTestDivider(
        'ChatCubit.refreshFromNotification emits nothing when the refresh brings no new message',
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      stubHistory([message(id: '901')]);
      await cubit.connect(roomId, conversationId: conversationId);
      socket.emitState(SocketConnectionState.disconnected);
      await Future<void>.delayed(Duration.zero);
      final before = cubit.state;

      await cubit.refreshFromNotification();

      printTestLog(
        'state identity → expected: unchanged, actual: ${identical(before, cubit.state)}',
      );
      expect(identical(before, cubit.state), isTrue);
    });

    test('does nothing at all without a conversation id', () async {
      printTestDivider('ChatCubit.refreshFromNotification does nothing at all without a conversation id');
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.connect(roomId);

      await cubit.refreshFromNotification();

      verifyNever(
        () => repository.getMessages(
          conversationId: any(named: 'conversationId'),
          myId: any(named: 'myId'),
          offset: any(named: 'offset'),
        ),
      );
      printTestLog('no history call → expected: none, actual: none');
    });
  });

  group('reconnect and close', () {
    test('reconnect drops the socket and dials the same channel again', () async {
      printTestDivider('ChatCubit.reconnect drops the socket and dials the same channel again');
      stubHistory([]);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.connect(roomId, conversationId: conversationId);

      cubit.reconnect(roomId);

      printTestLog('disconnect count → expected: 1, actual: ${socket.disconnectCount}');
      expect(socket.disconnectCount, 1);
      printTestLog('connect calls → expected: 2, actual: ${socket.connectCalls.length}');
      expect(socket.connectCalls.length, 2);
      printTestLog(
        'second channelId → expected: "41", actual: ${socket.connectCalls.last.channelId}',
      );
      expect(socket.connectCalls.last.channelId, conversationId);
    });

    test('isSocketConnected mirrors the transport state', () async {
      printTestDivider('ChatCubit.isSocketConnected mirrors the transport state');
      stubHistory([]);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.connect(roomId, conversationId: conversationId);

      printTestLog('before → expected: false, actual: ${cubit.isSocketConnected}');
      expect(cubit.isSocketConnected, isFalse);
      socket.emitState(SocketConnectionState.connected);
      printTestLog('after → expected: true, actual: ${cubit.isSocketConnected}');
      expect(cubit.isSocketConnected, isTrue);
    });

    test('close disposes the socket and clears the active pointer', () async {
      printTestDivider('ChatCubit.close disposes the socket and clears the active pointer');
      stubHistory([]);
      final cubit = buildCubit();
      await cubit.connect(roomId, conversationId: conversationId);

      await cubit.close();

      printTestLog('socket disposed → expected: true, actual: ${socket.disposed}');
      expect(socket.disposed, isTrue);
      printTestLog('ChatCubit.active → expected: null, actual: ${ChatCubit.active}');
      expect(ChatCubit.active, isNull);
    });

    test('closing a cubit that is not the active one leaves the pointer alone', () async {
      printTestDivider(
        'ChatCubit.close closing a cubit that is not the active one leaves the pointer alone',
      );
      stubHistory([]);
      final first = buildCubit();
      await first.connect(roomId, conversationId: conversationId);
      final second = ChatCubit(
        repository: repository,
        socket: FakeChatSocketService(),
      );
      addTearDown(second.close);
      await second.connect(roomId, conversationId: conversationId);

      await first.close();

      printTestLog(
        'ChatCubit.active → expected: the second cubit, actual: ${identical(ChatCubit.active, second)}',
      );
      expect(identical(ChatCubit.active, second), isTrue);
    });
  });

  group('socketFactory seam', () {
    tearDown(() => ChatCubit.socketFactory = null);

    test('a cubit built with no socket argument takes one from the factory', () async {
      printTestDivider(
        'ChatCubit.socketFactory a cubit built with no socket argument takes one from the factory',
      );
      final injected = FakeChatSocketService();
      ChatCubit.socketFactory = (_) => injected;
      stubHistory([]);

      final cubit = ChatCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.connect(roomId, conversationId: conversationId);

      printTestLog(
        'connect calls on the injected socket → expected: 1, actual: ${injected.connectCalls.length}',
      );
      expect(injected.connectCalls.length, 1);
    });
  });
}
