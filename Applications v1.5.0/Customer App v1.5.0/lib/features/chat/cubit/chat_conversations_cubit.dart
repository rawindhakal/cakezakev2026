import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/chat/models/chat_conversation.dart';
import 'package:customer/features/chat/repositories/chat_repository.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

// ── States ────────────────────────────────────────────────────────────────────

sealed class ChatConversationsState {}

final class ChatConversationsInitial extends ChatConversationsState {}

final class ChatConversationsError extends ChatConversationsState {
  final String message;
  ChatConversationsError(this.message);
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

class ChatConversationsCubit extends Cubit<ChatConversationsState> {
  final ChatRepository _repository;

  ChatConversationsCubit({ChatRepository? repository})
    : _repository = repository ?? ChatRepository(),
      super(ChatConversationsInitial());

  Future<ChatConversation?> startAdminConversation() async {
    try {
      return await _repository.startAdminConversation();
    } on ApiException catch (e) {
      emit(ChatConversationsError(e.message));
      return null;
    } catch (_) {
      emit(
        ChatConversationsError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
      return null;
    }
  }

  Future<ChatConversation?> startOrderConversation({
    required String orderId,
    String? orderItemId,
  }) async {
    try {
      return await _repository.startOrderConversation(
        orderId: orderId,
        orderItemId: orderItemId,
      );
    } on ApiException catch (e) {
      emit(ChatConversationsError(e.message));
      return null;
    } catch (_) {
      emit(
        ChatConversationsError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
      return null;
    }
  }

  Future<ChatConversation?> startOrderAdminConversation({
    required String orderId,
  }) async {
    try {
      return await _repository.startOrderAdminConversation(orderId: orderId);
    } on ApiException catch (e) {
      emit(ChatConversationsError(e.message));
      return null;
    } catch (_) {
      emit(
        ChatConversationsError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
      return null;
    }
  }
}
