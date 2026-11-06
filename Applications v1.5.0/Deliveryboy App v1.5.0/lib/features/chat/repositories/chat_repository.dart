import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/features/chat/models/chat_conversation.dart';
import 'package:deliveryboy/features/chat/models/chat_message.dart';

/// Data-access layer for chat — conversations, message history/sending, socket
/// auth, and attachment downloads; talks to [ApiClient] directly.
class ChatRepository {
  final ApiClient _apiClient;

  ChatRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Starts (or fetches the existing) admin/support conversation for this user.
  Future<ChatConversation> startAdminConversation() async {
    final response = await _apiClient.post(ApiEndpoints.chatStartAdmin);
    final data = (response as Map<String, dynamic>)['data'];
    return ChatConversation.fromJson(data as Map<String, dynamic>);
  }

  /// Starts (or fetches the existing) conversation tied to an order/order item.
  Future<ChatConversation> startOrderConversation({
    required String orderId,
    String? orderItemId,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.chatStartOrder,
      data: {
        ApiParameters.orderId: orderId,
        if (orderItemId != null && orderItemId.isNotEmpty)
          ApiParameters.orderItemId: orderItemId,
      },
    );
    final data = (response as Map<String, dynamic>)['data'];
    return ChatConversation.fromJson(data as Map<String, dynamic>);
  }

  /// `data` is `{conversation: {...}, messages: [...]}`.
  Future<List<ChatMessage>> getMessages({
    required String conversationId,
    required int myId,
    int offset = 0,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.chatMessages,
      queryParameters: {
        ApiParameters.conversationId: conversationId,
        ApiParameters.offset: offset,
        ApiParameters.limit: limit,
      },
    );
    final data = (response as Map<String, dynamic>)['data'];
    if (data is! Map<String, dynamic>) return [];
    final messages = data['messages'];
    if (messages is! List) return [];
    return messages
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>, myId))
        .toList();
  }

  /// Authorizes a private-channel websocket subscription (Pusher/Reverb
  /// protocol) — pass the `socket_id` from `pusher:connection_established`
  /// and the target `channel_name`; returns the raw `{auth: ...}` payload to
  /// send back in the `pusher:subscribe` frame.
  Future<Map<String, dynamic>> getBroadcastAuth({
    required String socketId,
    required String channelName,
  }) async {
    final response = await _apiClient.postRaw(
      ApiEndpoints.broadcastingAuth,
      data: {
        ApiParameters.socketId: socketId,
        ApiParameters.channelName: channelName,
      },
    );
    // Dio only auto-decodes JSON when the response's Content-Type says so —
    // this endpoint sometimes replies with a JSON body under a mismatched
    // content-type, which left `response` as a raw String and the direct
    // `as Map` cast throwing on every call.
    final decoded = response is String ? jsonDecode(response) : response;
    return Map<String, dynamic>.from(decoded as Map);
  }

  /// `data` is an array — sending with multiple attachments can return multiple rows.
  Future<List<ChatMessage>> sendMessage({
    required String conversationId,
    required String message,
    required int myId,
    List<String>? imagePaths,
    List<String>? audioPaths,
    List<String>? videoPaths,
    List<String>? filePaths,
  }) async {
    final fields = <String, dynamic>{
      ApiParameters.conversationId: conversationId,
      ApiParameters.message: message,
    };
    if (imagePaths != null && imagePaths.isNotEmpty) {
      fields[ApiParameters.images] = await Future.wait(
        imagePaths.map(
          (path) =>
              MultipartFile.fromFile(path, filename: path.split('/').last),
        ),
      );
    }
    if (audioPaths != null && audioPaths.isNotEmpty) {
      fields[ApiParameters.audios] = await Future.wait(
        audioPaths.map(
          (path) =>
              MultipartFile.fromFile(path, filename: path.split('/').last),
        ),
      );
    }
    if (videoPaths != null && videoPaths.isNotEmpty) {
      fields[ApiParameters.videos] = await Future.wait(
        videoPaths.map(
          (path) =>
              MultipartFile.fromFile(path, filename: path.split('/').last),
        ),
      );
    }
    if (filePaths != null && filePaths.isNotEmpty) {
      fields[ApiParameters.files] = await Future.wait(
        filePaths.map(
          (path) =>
              MultipartFile.fromFile(path, filename: path.split('/').last),
        ),
      );
    }
    final response = await _apiClient.upload(
      ApiEndpoints.sendChatMessage,
      formData: FormData.fromMap(fields),
    );
    final data = (response as Map<String, dynamic>)['data'];
    if (data is! List) return [];
    return data
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>, myId))
        .toList();
  }

  Future<void> downloadAttachment(String url, String savePath) async {
    await _apiClient.downloadFile(url, savePath);
  }
}
