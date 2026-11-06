import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:deliveryboy/features/chat/models/chat_conversation.dart';
import 'package:deliveryboy/features/chat/repositories/chat_repository.dart';

// ── States ────────────────────────────────────────────────────────────────────

abstract class ChatConversationsState {}

class ChatConversationsInitial extends ChatConversationsState {}

class ChatConversationsError extends ChatConversationsState {
  final String message;
  ChatConversationsError(this.message);
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

/// Starts (or resolves) chat conversations with admin/support or for a specific order.
class ChatConversationsCubit extends Cubit<ChatConversationsState> {
  final ChatRepository _repository;

  ChatConversationsCubit({ChatRepository? repository})
    : _repository = repository ?? ChatRepository(),
      super(ChatConversationsInitial());

  /// Starts (or fetches the existing) conversation with admin/support.
  Future<ChatConversation?> startAdminConversation() async {
    try {
      return await _repository.startAdminConversation();
    } on ApiException catch (e) {
      emit(ChatConversationsError(e.message));
      return null;
    } catch (e) {
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

  /// Starts (or fetches the existing) conversation tied to [orderId] / [orderItemId].
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
    } catch (e) {
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
