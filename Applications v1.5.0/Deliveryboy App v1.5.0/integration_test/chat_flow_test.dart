import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/features/auth/models/auth_model.dart';
import 'package:deliveryboy/features/chat/cubit/chat_cubit.dart';
import 'package:deliveryboy/features/chat/models/chat_message.dart';
import 'package:deliveryboy/features/chat/services/chat_socket_service.dart';
import 'package:deliveryboy/features/chat/widgets/chat_bubble.dart';
import 'package:deliveryboy/features/chat/widgets/chat_date_divider.dart';
import 'package:deliveryboy/features/chat/widgets/chat_skeleton_loader.dart';
import 'package:deliveryboy/features/chat/widgets/chat_status_icon.dart';
import 'package:deliveryboy/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'helpers/auth_fixtures.dart';
import 'helpers/auth_test_app.dart';
import 'helpers/chat_fixtures.dart';
import 'helpers/fake_api_adapter.dart';
import 'helpers/fake_chat_socket_service.dart';

/// The chat conversation end to end: real router, real `ChatScreen`, real
/// `ChatCubit`/`ChatRepository`, only the network faked.
///
/// The realtime transport is swapped through `ChatCubit.socketFactory` as
/// well: a real `ChatSocketService` would dial an unreachable ws(s) URL on
/// this device and then retry on a backoff timer for the rest of the run,
/// which is neither what these flows are about nor something the test can
/// wait out. The fake lets the flows drive "socket up", "message arrived"
/// and "socket dropped" directly.
///
/// `ChatScreen` reads its `ChatScreenArgs` off the route, so the args are
/// handed to `AuthTestApp` via `initialRouteArguments`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeApiAdapter adapter;
  late FakeChatSocketService socket;

  const args = ChatScreenArgs(
    chatType: ChatType.deliveryBoyChat,
    recipientName: 'Ana Cruz',
    recipientId: 88,
    orderId: '1204',
    conversationId: '41',
  );

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final dir = await Directory.systemTemp.createTemp('integration_hive_');
    Hive.init(dir.path);
    await Hive.openBox(authBox);
    await Hive.openBox(settingsBox);
    await LocalizationService.instance.loadFromAssets();
  });

  setUp(() async {
    await Hive.box(authBox).clear();
    await AuthHiveBox.instance.saveLoginData(
      auth: AuthModel.fromJson(loginResponseFixture),
    );
    // The logged-in delivery boy is sender_id 12 in the fixtures, so his own
    // messages come back as `isMe`.
    await Hive.box(authBox).put(kUserId, '12');

    adapter = _chatAdapter();
    ApiClient().httpClientAdapter = adapter;

    socket = FakeChatSocketService();
    ChatCubit.socketFactory = (_) => socket;
  });

  tearDown(() {
    ChatCubit.socketFactory = null;
    ChatCubit.active = null;
  });

  Future<void> waitForResponse(WidgetTester tester) async {
    // The live binding runs on real time, so pump(Duration) alone doesn't let
    // a pending network future complete.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> settleAndUnmount(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
  }

  Future<void> openChat(WidgetTester tester) async {
    await tester.pumpWidget(
      const AuthTestApp(
        initialRoute: RouteNames.chat,
        initialRouteArguments: args,
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// History has landed — bring the socket up, as a real handshake would.
  Future<void> connectSocket(WidgetTester tester) async {
    socket.emitState(SocketConnectionState.connected);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('opening a conversation loads its history and connects the room', (
    tester,
  ) async {
    await openChat(tester);
    // Before the history lands the screen is still on its skeleton.
    expect(find.byType(ChatSkeletonLoader), findsOneWidget);

    await waitForResponse(tester);
    await connectSocket(tester);

    final request = adapter.requests.firstWhere(
      (r) => r.path == ApiEndpoints.chatMessages,
    );
    expect(request.queryParameters[ApiParameters.conversationId], '41');
    expect(request.queryParameters[ApiParameters.offset], 0);

    // The socket is dialled on the order's room, authorized by conversation id.
    expect(socket.connectCalls.single.roomId, 'order_1204');
    expect(socket.connectCalls.single.channelId, '41');

    expect(find.text('Ana Cruz'), findsOneWidget);
    expect(find.byType(ChatBubble), findsNWidgets(4));
    expect(find.text('Hi, are you nearby?'), findsOneWidget);
    expect(find.text('Five minutes away.'), findsOneWidget);
    // Every fixture message is from the same day.
    expect(find.byType(ChatDateDivider), findsOneWidget);

    await settleAndUnmount(tester);
  });

  testWidgets('typing a message sends it over REST and adds it to the thread', (
    tester,
  ) async {
    await openChat(tester);
    await waitForResponse(tester);
    await connectSocket(tester);

    await tester.enterText(find.byType(TextField), 'On my way');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is AppSvgIcon && w.path == AssetsConstants.sendIcon,
      ),
    );
    await tester.pump();
    await waitForResponse(tester);

    final sendRequest = adapter.requests.firstWhere(
      (r) => r.path == ApiEndpoints.sendChatMessage,
    );
    expect(sendRequest.data, isNotNull);
    // The list only keeps on-screen bubbles mounted on a real device viewport
    // (see the ListView.builder gotcha in TESTING.md) — assert the new
    // message rendered rather than the total mounted count.
    expect(find.byType(ChatBubble), findsAtLeastNWidgets(1));
    expect(find.text('On my way'), findsOneWidget);
    // The field is cleared, so the action button is back to the microphone.
    expect(
      find.byWidgetPredicate(
        (w) => w is AppSvgIcon && w.path == AssetsConstants.microphoneIcon,
      ),
      findsOneWidget,
    );

    await settleAndUnmount(tester);
  });

  testWidgets('a rejected send leaves the message on screen marked failed', (
    tester,
  ) async {
    adapter = _chatAdapter(sendResponse: chatSendRejectedFixture);
    ApiClient().httpClientAdapter = adapter;

    await openChat(tester);
    await waitForResponse(tester);
    await connectSocket(tester);

    await tester.enterText(find.byType(TextField), 'Anyone there?');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is AppSvgIcon && w.path == AssetsConstants.sendIcon,
      ),
    );
    await tester.pump();
    await waitForResponse(tester);

    expect(find.text('Anyone there?'), findsOneWidget);
    final statuses = tester
        .widgetList<ChatStatusIcon>(find.byType(ChatStatusIcon))
        .map((s) => s.status);
    expect(statuses, contains(MessageStatus.failed));

    await settleAndUnmount(tester);
  });

  testWidgets('a message arriving over the socket shows up without a refetch', (
    tester,
  ) async {
    await openChat(tester);
    await waitForResponse(tester);
    await connectSocket(tester);

    final before = adapter.requestedPaths
        .where((p) => p == ApiEndpoints.chatMessages)
        .length;

    socket.emitMessage(
      ChatMessage(
        id: '910',
        senderId: 88,
        senderType: 'user',
        message: 'Thanks!',
        timestamp: DateTime.now(),
        isMe: false,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Thanks!'), findsOneWidget);
    expect(find.byType(ChatBubble), findsNWidgets(5));
    final after = adapter.requestedPaths
        .where((p) => p == ApiEndpoints.chatMessages)
        .length;
    expect(after, before);

    await settleAndUnmount(tester);
  });

  testWidgets('pulling down loads the older page and keeps the thread', (
    tester,
  ) async {
    // A short viewport, so the message list can actually scroll and the
    // RefreshIndicator arms — with everything already fitting on screen the
    // pull is a silent no-op.
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 700);
    tester.view.devicePixelRatio = 1.0;

    await openChat(tester);
    await waitForResponse(tester);
    await connectSocket(tester);

    // Drive the gesture by hand — drag()/fling() can finish before the
    // indicator arms.
    final gesture = await tester.startGesture(const Offset(250, 250));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await gesture.up();
    await tester.pump();
    await waitForResponse(tester);

    // The follow-up fetch asks for a non-zero offset — that request, not a
    // widget count, is the reliable evidence the page was loaded.
    final offsets = adapter.requests
        .where((r) => r.path == ApiEndpoints.chatMessages)
        .map((r) => r.queryParameters[ApiParameters.offset])
        .toList();
    expect(offsets, contains(4));
    expect(find.text('Good morning'), findsOneWidget);

    await settleAndUnmount(tester);
  });

  testWidgets('an empty conversation shows the start-the-conversation state', (
    tester,
  ) async {
    adapter = _chatAdapter(messagesResponse: chatNoMessagesFixture);
    ApiClient().httpClientAdapter = adapter;

    await openChat(tester);
    await waitForResponse(tester);
    await connectSocket(tester);

    // Integration tests load the real translations, so English copy is
    // asserted here rather than the raw keys widget tests see.
    expect(find.byType(EmptyStateWidget), findsOneWidget);
    expect(find.text('No messages yet'), findsOneWidget);
    expect(find.text('Start the conversation below'), findsOneWidget);
    expect(find.byType(ChatBubble), findsNothing);

    await settleAndUnmount(tester);
  });

  testWidgets('losing the socket keeps the thread and the input bar usable', (
    tester,
  ) async {
    await openChat(tester);
    await waitForResponse(tester);
    await connectSocket(tester);

    socket.emitState(SocketConnectionState.disconnected);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ChatBubble), findsNWidgets(4));

    // Sending still works while the socket is down — outgoing messages go
    // over REST, not the socket.
    await tester.enterText(find.byType(TextField), 'On my way');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is AppSvgIcon && w.path == AssetsConstants.sendIcon,
      ),
    );
    await tester.pump();
    await waitForResponse(tester);

    expect(
      adapter.requestedPaths,
      contains(ApiEndpoints.sendChatMessage),
    );

    await settleAndUnmount(tester);
  });
}

/// One adapter for every chat journey: the first page of history at offset 0,
/// the older page beyond it, and the send endpoint.
FakeApiAdapter _chatAdapter({
  Map<String, dynamic>? messagesResponse,
  Map<String, dynamic>? sendResponse,
}) {
  return FakeApiAdapter({
    ApiEndpoints.chatMessages: (options) {
      final offset =
          int.tryParse(
            options.queryParameters[ApiParameters.offset]?.toString() ?? '',
          ) ??
          0;
      if (offset > 0) return chatOlderMessagesFixture;
      return messagesResponse ?? chatMessagesFixture;
    },
    ApiEndpoints.sendChatMessage: (_) =>
        sendResponse ?? chatSendMessageFixture,
    ApiEndpoints.chatStartAdmin: (_) => chatStartAdminFixture,
    ApiEndpoints.settings: (_) => {'status': 1, 'data': <String, dynamic>{}},
    ApiEndpoints.countrySettings: (_) => {
      'status': 1,
      'data': {'currency': '₹'},
    },
  });
}
