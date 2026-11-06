import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/chat/cubit/chat_conversations_cubit.dart';
import 'package:deliveryboy/features/chat/models/chat_conversation.dart';

import '../../../helpers/mock_chat_repository.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late MockChatRepository repository;

  setUp(() => repository = MockChatRepository());

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  const conversation = ChatConversation(
    id: '7',
    type: 'admin_customer',
    title: 'Support',
  );

  group('startAdminConversation', () {
    test('returns the conversation and stays in the initial state', () async {
      printTestDivider(
        'ChatConversationsCubit.startAdminConversation returns the conversation and stays in the initial state',
      );
      when(
        () => repository.startAdminConversation(),
      ).thenAnswer((_) async => conversation);
      final cubit = ChatConversationsCubit(repository: repository);
      addTearDown(cubit.close);

      final result = await cubit.startAdminConversation();

      printTestLog('id → expected: "7", actual: "${result?.id}"');
      expect(result?.id, '7');
      printTestLog(
        'state → expected: ChatConversationsInitial, actual: ${cubit.state.runtimeType}',
      );
      expect(cubit.state, isA<ChatConversationsInitial>());
    });

    test('surfaces the server message on an ApiException and returns null', () async {
      printTestDivider(
        'ChatConversationsCubit.startAdminConversation surfaces the server message on an ApiException and returns null',
      );
      when(
        () => repository.startAdminConversation(),
      ).thenThrow(ApiException(message: 'Chat is disabled'));
      final cubit = ChatConversationsCubit(repository: repository);
      addTearDown(cubit.close);

      final result = await cubit.startAdminConversation();

      printTestLog('result → expected: null, actual: $result');
      expect(result, isNull);
      printTestLog(
        'state → expected: ChatConversationsError, actual: ${cubit.state.runtimeType}',
      );
      expect(cubit.state, isA<ChatConversationsError>());
      printTestLog(
        'message → expected: "Chat is disabled", actual: "${(cubit.state as ChatConversationsError).message}"',
      );
      expect(
        (cubit.state as ChatConversationsError).message,
        'Chat is disabled',
      );
    });

    test('falls back to the generic message on a non-Api failure', () async {
      printTestDivider(
        'ChatConversationsCubit.startAdminConversation falls back to the generic message on a non-Api failure',
      );
      when(() => repository.startAdminConversation()).thenThrow(StateError('x'));
      final cubit = ChatConversationsCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.startAdminConversation();

      // Translations aren't loaded under `flutter test`, so translate()
      // returns the raw key.
      final message = (cubit.state as ChatConversationsError).message;
      printTestLog(
        'message → expected: "${LanguageLabelKeys.somethingWentWrong}", actual: "$message"',
      );
      expect(message, LanguageLabelKeys.somethingWentWrong);
    });
  });

  group('startOrderConversation', () {
    test('forwards the order and order item ids to the repository', () async {
      printTestDivider(
        'ChatConversationsCubit.startOrderConversation forwards the order and order item ids to the repository',
      );
      when(
        () => repository.startOrderConversation(
          orderId: any(named: 'orderId'),
          orderItemId: any(named: 'orderItemId'),
        ),
      ).thenAnswer((_) async => conversation);
      final cubit = ChatConversationsCubit(repository: repository);
      addTearDown(cubit.close);

      final result = await cubit.startOrderConversation(
        orderId: '1204',
        orderItemId: '9001',
      );

      verify(
        () => repository.startOrderConversation(
          orderId: '1204',
          orderItemId: '9001',
        ),
      ).called(1);
      printTestLog('id → expected: "7", actual: "${result?.id}"');
      expect(result?.id, '7');
    });

    test('surfaces the server message on an ApiException and returns null', () async {
      printTestDivider(
        'ChatConversationsCubit.startOrderConversation surfaces the server message on an ApiException and returns null',
      );
      when(
        () => repository.startOrderConversation(
          orderId: any(named: 'orderId'),
          orderItemId: any(named: 'orderItemId'),
        ),
      ).thenThrow(ApiException(message: 'Order not found'));
      final cubit = ChatConversationsCubit(repository: repository);
      addTearDown(cubit.close);

      final result = await cubit.startOrderConversation(orderId: '1204');

      printTestLog('result → expected: null, actual: $result');
      expect(result, isNull);
      printTestLog(
        'message → expected: "Order not found", actual: "${(cubit.state as ChatConversationsError).message}"',
      );
      expect((cubit.state as ChatConversationsError).message, 'Order not found');
    });

    test('falls back to the generic message on a non-Api failure', () async {
      printTestDivider(
        'ChatConversationsCubit.startOrderConversation falls back to the generic message on a non-Api failure',
      );
      when(
        () => repository.startOrderConversation(
          orderId: any(named: 'orderId'),
          orderItemId: any(named: 'orderItemId'),
        ),
      ).thenThrow(StateError('x'));
      final cubit = ChatConversationsCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.startOrderConversation(orderId: '1204');

      final message = (cubit.state as ChatConversationsError).message;
      printTestLog(
        'message → expected: "${LanguageLabelKeys.somethingWentWrong}", actual: "$message"',
      );
      expect(message, LanguageLabelKeys.somethingWentWrong);
    });
  });
}
