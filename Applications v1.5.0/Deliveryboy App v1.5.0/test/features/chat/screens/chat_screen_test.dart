import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_theme.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/features/chat/cubit/chat_cubit.dart';
import 'package:deliveryboy/features/chat/models/chat_message.dart';
import 'package:deliveryboy/features/chat/screens/chat_screen.dart';
import 'package:deliveryboy/features/chat/services/chat_socket_service.dart';
import 'package:deliveryboy/features/chat/widgets/chat_bubble.dart';
import 'package:deliveryboy/features/chat/widgets/chat_date_divider.dart';
import 'package:deliveryboy/features/chat/widgets/chat_input_bar.dart';
import 'package:deliveryboy/features/chat/widgets/chat_skeleton_loader.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/fake_api_adapter.dart';
import '../../../helpers/fake_chat_socket_service.dart';
import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/mock_cubits.dart';
import '../../../helpers/test_logging.dart';

/// ChatScreen builds its own `ChatCubit` in `didChangeDependencies`, so no
/// mock cubit can be injected. The real cubit and repository run instead:
/// REST goes through the `ApiClient` adapter seam (as in
/// `notification_screen_test.dart`), and the websocket is replaced through
/// `ChatCubit.socketFactory` so no real connection — and no reconnect
/// timer — is ever created. Only `ConnectivityCubit` is read from outside.
void main() {
  const myId = 12;
  const conversationId = '41';

  late FakeApiAdapter adapter;
  late FakeChatSocketService socket;
  late MockConnectivityCubit connectivityCubit;
  late Map<String, dynamic> messagesResponse;
  late Map<String, dynamic> sendResponse;

  setUpAll(() {
    messagesResponse =
        jsonDecode(
              File('test/fixtures/chat/chat_messages.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    sendResponse =
        jsonDecode(
              File(
                'test/fixtures/chat/chat_send_message.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  setUp(() async {
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);
    await Hive.box(authBox).put(kUserId, '$myId');

    adapter = FakeApiAdapter({
      ApiEndpoints.chatMessages: (_) => messagesResponse,
      ApiEndpoints.sendChatMessage: (_) => sendResponse,
    });
    ApiClient().httpClientAdapter = adapter;

    socket = FakeChatSocketService();
    ChatCubit.socketFactory = (_) => socket;

    connectivityCubit = MockConnectivityCubit();
    whenListen(
      connectivityCubit,
      const Stream<ConnectivityState>.empty(),
      initialState: ConnectivityConnected(),
    );
  });

  tearDown(() async {
    ChatCubit.socketFactory = null;
    ChatCubit.active = null;
    await Hive.box(settingsBox).close();
    await Hive.deleteBoxFromDisk(settingsBox);
    await HiveTestHelper.tearDown(authBox);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpScreen(
    WidgetTester tester, {
    String? conversation = conversationId,
    Stream<ConnectivityState>? connectivityStream,
    Size viewport = const Size(500, 1400),
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;

    // AppTheme's text styles come from google_fonts, which otherwise tries to
    // download a font file and stalls the runner.
    GoogleFonts.config.allowRuntimeFetching = false;

    if (connectivityStream != null) {
      whenListen(
        connectivityCubit,
        connectivityStream,
        initialState: ConnectivityConnected(),
      );
    }

    await tester.pumpWidget(
      BlocProvider<ConnectivityCubit>.value(
        value: connectivityCubit,
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          // ChatScreen reads its ChatScreenArgs off the route, so it needs a
          // real route rather than MaterialApp's `home`.
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const ChatScreen(),
            settings: RouteSettings(
              arguments: ChatScreenArgs(
                chatType: ChatType.deliveryBoyChat,
                recipientName: 'Ana Cruz',
                recipientId: 88,
                orderId: '1204',
                conversationId: conversation,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Lets the fake adapter's response land, then brings the socket up.
  Future<void> connectSocket(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    socket.emitState(SocketConnectionState.connected);
    // The screen animates to the bottom of the list on connect (300ms).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('shows the recipient name and the skeleton while connecting', (
    tester,
  ) async {
    printTestDivider('ChatScreen shows the recipient name and the skeleton while connecting');
    await pumpScreen(tester);

    printTestLog('title → expected: "Ana Cruz" visible');
    expect(find.text('Ana Cruz'), findsOneWidget);
    printTestLog(
      'skeleton → expected: 1, actual: ${find.byType(ChatSkeletonLoader).evaluate().length}',
    );
    expect(find.byType(ChatSkeletonLoader), findsOneWidget);

    await connectSocket(tester);
  });

  testWidgets('loads history for the conversation and dials that same channel', (
    tester,
  ) async {
    printTestDivider(
      'ChatScreen loads history for the conversation and dials that same channel',
    );
    await pumpScreen(tester);
    await connectSocket(tester);

    final request = adapter.requests.firstWhere(
      (r) => r.path == ApiEndpoints.chatMessages,
    );
    printTestLog(
      'conversation_id → expected: "41", actual: ${request.queryParameters[ApiParameters.conversationId]}',
    );
    expect(request.queryParameters[ApiParameters.conversationId], conversationId);
    printTestLog(
      'socket connect → expected: (order_1204, 41), actual: ${socket.connectCalls.single}',
    );
    expect(socket.connectCalls.single.roomId, 'order_1204');
    expect(socket.connectCalls.single.channelId, conversationId);
  });

  testWidgets('renders a bubble per message with a single date divider', (
    tester,
  ) async {
    printTestDivider('ChatScreen renders a bubble per message with a single date divider');
    await pumpScreen(tester);
    await connectSocket(tester);

    printTestLog(
      'bubbles → expected: 4, actual: ${find.byType(ChatBubble).evaluate().length}',
    );
    expect(find.byType(ChatBubble), findsNWidgets(4));
    printTestLog('first message → expected: "Hi, are you nearby?" visible');
    expect(find.text('Hi, are you nearby?'), findsOneWidget);
    // Every fixture message is from the same day, so only the first one
    // carries a divider.
    printTestLog(
      'date dividers → expected: 1, actual: ${find.byType(ChatDateDivider).evaluate().length}',
    );
    expect(find.byType(ChatDateDivider), findsOneWidget);
  });

  testWidgets('an empty history shows the no-messages empty state', (tester) async {
    printTestDivider('ChatScreen an empty history shows the no-messages empty state');
    ApiClient().httpClientAdapter = FakeApiAdapter({
      ApiEndpoints.chatMessages: (_) => {
        'status': 1,
        'data': {'conversation': {}, 'messages': <dynamic>[]},
      },
    });

    await pumpScreen(tester);
    await connectSocket(tester);

    printTestLog(
      'empty state → expected: 1, actual: ${find.byType(EmptyStateWidget).evaluate().length}',
    );
    expect(find.byType(EmptyStateWidget), findsOneWidget);
    // Translations aren't loaded under `flutter test`, so translate() returns
    // the raw key.
    printTestLog('title → expected: "${LanguageLabelKeys.noMessagesYet}" visible');
    expect(find.text(LanguageLabelKeys.noMessagesYet), findsOneWidget);
    printTestLog(
      'bubbles → expected: none, actual: ${find.byType(ChatBubble).evaluate().length}',
    );
    expect(find.byType(ChatBubble), findsNothing);
  });

  testWidgets('the input bar is blocked while connecting and freed once connected', (
    tester,
  ) async {
    printTestDivider(
      'ChatScreen the input bar is blocked while connecting and freed once connected',
    );
    await pumpScreen(tester);

    printTestLog(
      'while connecting → expected: enabled false, actual: ${tester.widget<ChatInputBar>(find.byType(ChatInputBar)).enabled}',
    );
    expect(tester.widget<ChatInputBar>(find.byType(ChatInputBar)).enabled, isFalse);

    await connectSocket(tester);

    printTestLog(
      'once connected → expected: enabled true, actual: ${tester.widget<ChatInputBar>(find.byType(ChatInputBar)).enabled}',
    );
    expect(tester.widget<ChatInputBar>(find.byType(ChatInputBar)).enabled, isTrue);
  });

  testWidgets('typing and sending posts the message and shows it in the thread', (
    tester,
  ) async {
    printTestDivider(
      'ChatScreen typing and sending posts the message and shows it in the thread',
    );
    await pumpScreen(tester);
    await connectSocket(tester);

    await tester.enterText(find.byType(TextField), 'On my way');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is AppSvgIcon && w.path == AssetsConstants.sendIcon,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    printTestLog(
      'send request → expected: contains ${ApiEndpoints.sendChatMessage}, actual: ${adapter.requestedPaths}',
    );
    expect(adapter.requestedPaths, contains(ApiEndpoints.sendChatMessage));
    printTestLog(
      'bubbles → expected: 5, actual: ${find.byType(ChatBubble).evaluate().length}',
    );
    expect(find.byType(ChatBubble), findsNWidgets(5));
  });

  testWidgets('a message arriving over the socket is appended to the thread', (
    tester,
  ) async {
    printTestDivider('ChatScreen a message arriving over the socket is appended to the thread');
    await pumpScreen(tester);
    await connectSocket(tester);

    socket.emitMessage(
      ChatMessage(
        id: '910',
        senderId: 88,
        senderType: 'user',
        message: 'Thanks!',
        timestamp: DateTime(2026, 8, 19, 9, 20),
        isMe: false,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    printTestLog('new message → expected: "Thanks!" visible');
    expect(find.text('Thanks!'), findsOneWidget);
    printTestLog(
      'bubbles → expected: 5, actual: ${find.byType(ChatBubble).evaluate().length}',
    );
    expect(find.byType(ChatBubble), findsNWidgets(5));
  });

  testWidgets('regaining connectivity re-dials the socket without losing the thread', (
    tester,
  ) async {
    printTestDivider(
      'ChatScreen regaining connectivity re-dials the socket without losing the thread',
    );
    final connectivity = StreamController<ConnectivityState>.broadcast();
    addTearDown(connectivity.close);
    await pumpScreen(tester, connectivityStream: connectivity.stream);
    await connectSocket(tester);

    connectivity.add(ConnectivityConnected());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    printTestLog(
      'socket connect calls → expected: 2, actual: ${socket.connectCalls.length}',
    );
    expect(socket.connectCalls.length, 2);
    printTestLog(
      'bubbles → expected: still 4, actual: ${find.byType(ChatBubble).evaluate().length}',
    );
    expect(find.byType(ChatBubble), findsNWidgets(4));
  });

  testWidgets('losing the socket keeps the messages and the input bar on screen', (
    tester,
  ) async {
    printTestDivider(
      'ChatScreen losing the socket keeps the messages and the input bar on screen',
    );
    await pumpScreen(tester);
    await connectSocket(tester);

    socket.emitState(SocketConnectionState.disconnected);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    printTestLog(
      'bubbles → expected: 4, actual: ${find.byType(ChatBubble).evaluate().length}',
    );
    expect(find.byType(ChatBubble), findsNWidgets(4));
    printTestLog(
      'input bar → expected: still enabled, actual: ${tester.widget<ChatInputBar>(find.byType(ChatInputBar)).enabled}',
    );
    expect(tester.widget<ChatInputBar>(find.byType(ChatInputBar)).enabled, isTrue);
  });

  testWidgets('a chat with no conversation yet skips the history call', (tester) async {
    printTestDivider('ChatScreen a chat with no conversation yet skips the history call');
    await pumpScreen(tester, conversation: null);
    await connectSocket(tester);

    printTestLog('requests → expected: none, actual: ${adapter.requestedPaths}');
    expect(adapter.requestedPaths, isEmpty);
    printTestLog(
      'empty state → expected: 1, actual: ${find.byType(EmptyStateWidget).evaluate().length}',
    );
    expect(find.byType(EmptyStateWidget), findsOneWidget);
  });
}
