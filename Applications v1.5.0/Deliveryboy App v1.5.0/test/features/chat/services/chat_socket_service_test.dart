import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/models/app_settings_model.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/local_storage/settings_hive_box.dart';
import 'package:deliveryboy/features/chat/services/chat_socket_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_chat_repository.dart';
import '../../../helpers/test_logging.dart';

/// Drives the real service against a local Pusher-protocol server, same
/// approach as `maintenance_socket_service_test.dart` — pointing
/// `broadcast_config` at 127.0.0.1 exercises the real handshake/subscribe
/// frames end to end instead of mocking the socket.
///
/// [ChatSocketService]'s "legacy" self-hosted branch only ever resolves to
/// `AppConfig.socketBaseUrl` — a hardcoded production wss:// URL with no test
/// seam to redirect — so it can't be driven against a local server the way
/// the real-protocol branch can. What *is* testable without hitting that URL:
/// `_onData`'s frame parsing is shape-based, not mode-based (an `event` key
/// routes to the Pusher handler, its absence routes to the legacy raw-JSON
/// parser) — so the legacy message shape is exercised over the same local
/// real-protocol connection below. `sendMessage`'s legacy send path
/// specifically requires `_useRealProtocol == false`, which is unreachable
/// here for the same reason; only its real-protocol no-op branch is covered.
void main() {
  late HttpServer server;
  late int port;
  final serverSockets = <WebSocket>[];
  StreamController<Map<String, dynamic>>? received;
  late MockChatRepository mockRepo;
  late ChatSocketService service;

  Stream<Map<String, dynamic>> clientFrames() => received!.stream;

  setUp(() async {
    await HiveTestHelper.setUp(authBox);
    await Hive.box(authBox).put('user_id', '12');
    await Hive.box(authBox).put('token', 'test-token');
    await Hive.openBox(settingsBox);

    received = StreamController<Map<String, dynamic>>.broadcast();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = server.port;
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      serverSockets.add(socket);
      socket.listen((raw) {
        received?.add(jsonDecode(raw as String) as Map<String, dynamic>);
      }, onError: (_) {}, cancelOnError: false);
    });

    await SettingsHiveBox.instance.saveAppSettings(
      AppSettingsData.fromJson({
        'broadcast_driver': 'reverb',
        'broadcast_config': {
          'key': 'test-key',
          'host': '127.0.0.1',
          'port': '$port',
          'scheme': 'http',
        },
      }),
    );

    mockRepo = MockChatRepository();
    when(
      () => mockRepo.getBroadcastAuth(
        socketId: any(named: 'socketId'),
        channelName: any(named: 'channelName'),
      ),
    ).thenAnswer((_) async => {'auth': 'test-key:signature'});
    service = ChatSocketService(repository: mockRepo);
  });

  tearDown(() async {
    service.disconnect();
    for (final socket in serverSockets) {
      await socket.close();
    }
    serverSockets.clear();
    await received?.close();
    received = null;
    await server.close(force: true);
    await Hive.box(settingsBox).close();
    await Hive.deleteBoxFromDisk(settingsBox);
    await HiveTestHelper.tearDown(authBox);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<WebSocket> awaitConnection({int expectedCount = 1}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (serverSockets.length < expectedCount &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(serverSockets.length, greaterThanOrEqualTo(expectedCount));
    return serverSockets[expectedCount - 1];
  }

  void sendConnectionEstablished(WebSocket socket) {
    socket.add(
      jsonEncode({
        'event': 'pusher:connection_established',
        'data': jsonEncode({'socket_id': '123.456', 'activity_timeout': 120}),
      }),
    );
  }

  /// Connects, waits for the handshake, and drives the subscribe → ack
  /// round trip so the service reaches `connected`.
  Future<WebSocket> connectAndSubscribe({
    String roomId = 'order_55',
    String? channelId,
    int expectedCount = 1,
  }) async {
    service.connect(roomId, channelId: channelId);
    final socket = await awaitConnection(expectedCount: expectedCount);
    final subscribeFuture = clientFrames().firstWhere(
      (f) => f['event'] == 'pusher:subscribe',
    );
    sendConnectionEstablished(socket);
    final subscribeFrame = await subscribeFuture.timeout(
      const Duration(seconds: 5),
    );
    final channel = (subscribeFrame['data'] as Map)['channel'] as String;
    socket.add(
      jsonEncode({
        'event': 'pusher_internal:subscription_succeeded',
        'channel': channel,
        'data': '{}',
      }),
    );
    final state = await service.connectionState
        .firstWhere((s) => s == SocketConnectionState.connected)
        .timeout(const Duration(seconds: 5));
    expect(state, SocketConnectionState.connected);
    return socket;
  }

  test('real protocol: handshakes then subscribes to the private channel keyed by channelId', () async {
    printTestDivider('real protocol: handshakes then subscribes to the private channel keyed by channelId');
    service.connect('order_55', channelId: '42');
    final socket = await awaitConnection();

    final subscribe = clientFrames().firstWhere(
      (f) => f['event'] == 'pusher:subscribe',
    );
    sendConnectionEstablished(socket);
    final frame = await subscribe.timeout(const Duration(seconds: 5));

    final channel = (frame['data'] as Map)['channel'];
    printTestLog(
      'subscribe channel → expected: "private-chat.conversation.42", actual: "$channel"',
    );
    expect(channel, 'private-chat.conversation.42');
  });

  test('falls back to the roomId as the channel key when no channelId is given', () async {
    printTestDivider('falls back to the roomId as the channel key when no channelId is given');
    service.connect('admin_user_9');
    final socket = await awaitConnection();

    final subscribe = clientFrames().firstWhere(
      (f) => f['event'] == 'pusher:subscribe',
    );
    sendConnectionEstablished(socket);
    final frame = await subscribe.timeout(const Duration(seconds: 5));

    final channel = (frame['data'] as Map)['channel'];
    printTestLog(
      'subscribe channel → expected: "private-chat.conversation.admin_user_9", actual: "$channel"',
    );
    expect(channel, 'private-chat.conversation.admin_user_9');
  });

  test('authorizes the subscribe frame through ChatRepository.getBroadcastAuth', () async {
    printTestDivider('authorizes the subscribe frame through ChatRepository.getBroadcastAuth');
    service.connect('order_55', channelId: '42');
    final socket = await awaitConnection();

    final subscribe = clientFrames().firstWhere(
      (f) => f['event'] == 'pusher:subscribe',
    );
    sendConnectionEstablished(socket);
    final frame = await subscribe.timeout(const Duration(seconds: 5));

    verify(
      () => mockRepo.getBroadcastAuth(
        socketId: '123.456',
        channelName: 'private-chat.conversation.42',
      ),
    ).called(1);
    final auth = (frame['data'] as Map)['auth'];
    printTestLog('auth signature → expected: "test-key:signature", actual: "$auth"');
    expect(auth, 'test-key:signature');
  });

  test('subscription success moves the state to connected', () async {
    printTestDivider('subscription success moves the state to connected');
    await connectAndSubscribe();
    printTestLog('state → expected: connected, actual: ${service.state}');
    expect(service.state, SocketConnectionState.connected);
  });

  test('answers a server ping with a pong', () async {
    printTestDivider('answers a server ping with a pong');
    final socket = await connectAndSubscribe();

    final pong = clientFrames().firstWhere((f) => f['event'] == 'pusher:pong');
    socket.add(jsonEncode({'event': 'pusher:ping', 'data': {}}));
    final frame = await pong.timeout(const Duration(seconds: 5));

    printTestLog('reply event → expected: "pusher:pong", actual: "${frame['event']}"');
    expect(frame['event'], 'pusher:pong');
  });

  test('a broadcast on the subscribed channel is exposed as a ChatMessage', () async {
    printTestDivider('a broadcast on the subscribed channel is exposed as a ChatMessage');
    final socket = await connectAndSubscribe(roomId: 'order_55', channelId: '42');

    final received = service.messages.first;
    socket.add(
      jsonEncode({
        'event': 'App\\Events\\ChatMessageSent',
        'channel': 'private-chat.conversation.42',
        'data': jsonEncode({
          'id': '9001',
          'sender_id': '88',
          'sender_type': 'user',
          'message': 'On my way',
          'created_at': '2026-08-21 10:00:00',
        }),
      }),
    );
    final msg = await received.timeout(const Duration(seconds: 5));

    printTestLog('message text → expected: "On my way", actual: "${msg.message}"');
    expect(msg.message, 'On my way');
    printTestLog('sender id → expected: 88, actual: ${msg.senderId}');
    expect(msg.senderId, 88);
  });

  test('a broadcast on a different channel than subscribed is ignored', () async {
    printTestDivider('a broadcast on a different channel than subscribed is ignored');
    final socket = await connectAndSubscribe(roomId: 'order_55', channelId: '42');

    var emitted = false;
    final sub = service.messages.listen((_) => emitted = true);
    addTearDown(sub.cancel);

    socket.add(
      jsonEncode({
        'event': 'App\\Events\\ChatMessageSent',
        'channel': 'private-chat.conversation.other',
        'data': jsonEncode({'id': '1', 'message': 'stray'}),
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));

    printTestLog('emitted → expected: false, actual: $emitted');
    expect(emitted, isFalse);
  });

  test('a legacy raw-JSON frame with no event envelope still parses as a chat message', () async {
    printTestDivider('a legacy raw-JSON frame with no event envelope still parses as a chat message');
    // Frame shape used by the self-hosted server: no `event` key at all.
    // `_onData` routes on that key's presence, not on which protocol
    // connected the socket, so this exercises the legacy parsing branch.
    final socket = await connectAndSubscribe();

    final received = service.messages.first;
    socket.add(
      jsonEncode({
        'type': 'message',
        'id': '77',
        'sender_id': '88',
        'sender_type': 'user',
        'message': 'legacy shaped frame',
        'timestamp': '2026-08-21 11:00:00',
      }),
    );
    final msg = await received.timeout(const Duration(seconds: 5));

    printTestLog('message text → expected: "legacy shaped frame", actual: "${msg.message}"');
    expect(msg.message, 'legacy shaped frame');
  });

  test('sendMessage is a no-op while the real Pusher protocol is in use', () async {
    printTestDivider('sendMessage is a no-op while the real Pusher protocol is in use');
    await connectAndSubscribe();

    var sawMessageFrame = false;
    final sub = clientFrames().listen((f) {
      if (f['type'] == 'message') sawMessageFrame = true;
    });
    addTearDown(sub.cancel);

    service.sendMessage('hi there', 'delivery_boy');
    await Future<void>.delayed(const Duration(milliseconds: 300));

    printTestLog('message frame sent → expected: false, actual: $sawMessageFrame');
    expect(sawMessageFrame, isFalse);
  });

  test('a subscription_error frame falls back to disconnected and schedules a reconnect', () async {
    printTestDivider('a subscription_error frame falls back to disconnected and schedules a reconnect');
    service.connect('order_55', channelId: '42');
    final socket = await awaitConnection();

    final subscribe = clientFrames().firstWhere(
      (f) => f['event'] == 'pusher:subscribe',
    );
    sendConnectionEstablished(socket);
    await subscribe.timeout(const Duration(seconds: 5));

    final states = <SocketConnectionState>[];
    final sub = service.connectionState.listen(states.add);
    addTearDown(sub.cancel);

    socket.add(
      jsonEncode({
        'event': 'pusher_internal:subscription_error',
        'channel': 'private-chat.conversation.42',
        'data': jsonEncode({'type': 'AuthError'}),
      }),
    );

    // First backoff delay is reconnectAttempts(1) * 2s.
    await awaitConnection(expectedCount: 2);

    printTestLog(
      'states seen → expected: contains disconnected then reconnecting, actual: $states',
    );
    expect(states, contains(SocketConnectionState.disconnected));
    expect(states, contains(SocketConnectionState.reconnecting));
  }, timeout: const Timeout(Duration(seconds: 15)));

  test('a subscribe frame with no server ack times out to disconnected and reconnects', () async {
    printTestDivider('a subscribe frame with no server ack times out to disconnected and reconnects');
    service.connect('order_55', channelId: '42');
    final socket = await awaitConnection();
    sendConnectionEstablished(socket);
    // Never send subscription_succeeded/error — the 10s ack-timeout timer
    // (see ChatSocketService._subscribeTimeout) must fire on its own.

    final disconnected = service.connectionState.firstWhere(
      (s) => s == SocketConnectionState.disconnected,
    );
    final state = await disconnected.timeout(const Duration(seconds: 15));

    printTestLog('state after ack timeout → expected: disconnected, actual: $state');
    expect(state, SocketConnectionState.disconnected);
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('an auth-call failure falls back to disconnected and reconnects', () async {
    printTestDivider('an auth-call failure falls back to disconnected and reconnects');
    when(
      () => mockRepo.getBroadcastAuth(
        socketId: any(named: 'socketId'),
        channelName: any(named: 'channelName'),
      ),
    ).thenThrow(Exception('auth endpoint failed'));

    service.connect('order_55', channelId: '42');
    final socket = await awaitConnection();
    sendConnectionEstablished(socket);

    final disconnected = service.connectionState.firstWhere(
      (s) => s == SocketConnectionState.disconnected,
    );
    final state = await disconnected.timeout(const Duration(seconds: 5));
    printTestLog('state → expected: disconnected, actual: $state');
    expect(state, SocketConnectionState.disconnected);

    // Reconnect budget still burns down normally afterwards.
    await awaitConnection(expectedCount: 2);
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('a malformed auth response with no auth field falls back to disconnected', () async {
    printTestDivider('a malformed auth response with no auth field falls back to disconnected');
    when(
      () => mockRepo.getBroadcastAuth(
        socketId: any(named: 'socketId'),
        channelName: any(named: 'channelName'),
      ),
    ).thenAnswer((_) async => <String, dynamic>{});

    service.connect('order_55', channelId: '42');
    final socket = await awaitConnection();
    sendConnectionEstablished(socket);

    final disconnected = service.connectionState.firstWhere(
      (s) => s == SocketConnectionState.disconnected,
    );
    final state = await disconnected.timeout(const Duration(seconds: 5));
    printTestLog('state → expected: disconnected, actual: $state');
    expect(state, SocketConnectionState.disconnected);
  });

  test('the server dropping the connection triggers a backed-off reconnect', () async {
    printTestDivider('the server dropping the connection triggers a backed-off reconnect');
    await connectAndSubscribe();

    final states = <SocketConnectionState>[];
    final sub = service.connectionState.listen(states.add);
    addTearDown(sub.cancel);

    await serverSockets.first.close();

    // Backoff for the 1st attempt is 2s — wait for the 2nd server connection.
    await awaitConnection(expectedCount: 2);

    printTestLog('states seen → expected: disconnected then reconnecting, actual: $states');
    expect(states, contains(SocketConnectionState.disconnected));
    expect(states, contains(SocketConnectionState.reconnecting));
  }, timeout: const Timeout(Duration(seconds: 15)));

  test('disconnect() closes the socket and stops any pending reconnect attempts', () async {
    printTestDivider('disconnect() closes the socket and stops any pending reconnect attempts');
    await connectAndSubscribe();

    service.disconnect();
    printTestLog('state → expected: disconnected, actual: ${service.state}');
    expect(service.state, SocketConnectionState.disconnected);

    // Long enough to have crossed the first (2s) backoff if reconnects were
    // still scheduled.
    await Future<void>.delayed(const Duration(seconds: 3));

    printTestLog(
      'server connections → expected: still 1, actual: ${serverSockets.length}',
    );
    expect(serverSockets.length, 1);
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('a fresh connect() after disconnect() resets the retry budget', () async {
    printTestDivider('a fresh connect() after disconnect() resets the retry budget');
    await connectAndSubscribe();
    service.disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // disconnect() burns the whole retry budget — without connect()
    // resetting it, this second connect() would get exactly one attempt.
    await connectAndSubscribe(expectedCount: 2);
    printTestLog('state → expected: connected, actual: ${service.state}');
    expect(service.state, SocketConnectionState.connected);
  });
}
