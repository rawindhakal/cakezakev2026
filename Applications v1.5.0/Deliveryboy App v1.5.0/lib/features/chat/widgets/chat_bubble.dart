import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/utils/app_date_formatter.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import '../models/chat_message.dart';
import 'chat_audio_attachment.dart';
import 'chat_file_attachment.dart';
import 'chat_image_attachment.dart';
import 'chat_status_icon.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.screenWidth * 0.72,
        ),
        child: Container(
          margin: EdgeInsetsDirectional.only(
            top: ThemeConstants.paddingXS,
            bottom: ThemeConstants.paddingXS,
            start: isMe ? 48 : 0,
            end: isMe ? 0 : 48,
          ),
          decoration: AppDecorations.card(
            color: isMe
                ? context.cs.primary
                : context.cs.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: AppRadius.lg,
              topRight: AppRadius.lg,
              bottomLeft: isMe ? AppRadius.lg : AppRadius.xs,
              bottomRight: isMe ? AppRadius.xs : AppRadius.lg,
            ),
            boxShadow: [
              BoxShadow(
                color: context.cs.shadow.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: AppRadius.lg,
              topRight: AppRadius.lg,
              bottomLeft: isMe ? AppRadius.lg : AppRadius.xs,
              bottomRight: isMe ? AppRadius.xs : AppRadius.lg,
            ),
            child: Column(
              crossAxisAlignment: .start,
              mainAxisSize: .min,
              children: [
                if (message.attachment != null)
                  _AttachmentView(attachment: message.attachment!, isMe: isMe),
                if (message.message.isNotEmpty || message.attachment == null)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      14,
                      10,
                      14,
                      6,
                    ),
                    child: AppText(
                      message.message,
                      style: context.tt.bodyMedium?.copyWith(
                        color: isMe
                            ? context.cs.onPrimary
                            : context.cs.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, ThemeConstants.paddingS),
                  child: Row(
                    mainAxisSize: .min,
                    children: [
                      AppText(
                        AppDateFormatter.formatTime(message.timestamp),
                        style: context.tt.labelSmall?.copyWith(
                          fontSize: 10,
                          color: isMe
                              ? context.cs.onPrimary.withValues(alpha: 0.7)
                              : context.cs.onSurfaceVariant,
                        ),
                      ),
                      if (isMe) ...[
                        SizedBox(width: context.screenWidth * 0.011),
                        ChatStatusIcon(status: message.status),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentView extends StatelessWidget {
  final ChatAttachment attachment;
  final bool isMe;
  const _AttachmentView({required this.attachment, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage) {
      return ChatImageAttachment(attachment: attachment, isMe: isMe);
    }
    if (attachment.isAudio) {
      return ChatAudioAttachment(attachment: attachment, isMe: isMe);
    }
    return ChatFileAttachment(attachment: attachment, isMe: isMe);
  }
}
