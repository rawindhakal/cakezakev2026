import 'dart:io';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import '../models/chat_message.dart';
import '../../../commons/widgets/app_text.dart';

class AttachmentPreviewBar extends StatelessWidget {
  final ChatAttachment attachment;
  final VoidCallback onRemove;

  const AttachmentPreviewBar({
    super.key,
    required this.attachment,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final label = attachment.isImage
        ? context.translate(LanguageLabelKeys.attachmentImage)
        : attachment.isAudio
        ? context.translate(LanguageLabelKeys.attachmentVoiceMessage)
        : (attachment.fileName ??
              context.translate(LanguageLabelKeys.attachmentFile));
    final sublabel = attachment.isImage
        ? context.translate(LanguageLabelKeys.attachmentPhotoReady)
        : attachment.isAudio
        ? context.translate(LanguageLabelKeys.attachmentVoiceReady)
        : context.translate(LanguageLabelKeys.attachmentFileReady);

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingM, ThemeConstants.paddingS, ThemeConstants.paddingS, ThemeConstants.paddingS),
      decoration: AppDecorations.card(
        color: context.cs.primaryContainer,
        border: Border(
          top: BorderSide(color: context.cs.primary.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          _Thumbnail(attachment: attachment),
          SizedBox(width: context.screenWidth * 0.027),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              mainAxisSize: .min,
              children: [
                AppText(
                  label,
                  style: context.tt.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.cs.primary,
                  ),
                  overflow: .ellipsis,
                ),
                AppText(
                  sublabel,
                  style: context.tt.labelSmall?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: AppSvgIcon(
              AssetsConstants.closeIcon,
              size: ThemeConstants.iconM,
              color: context.cs.onSurfaceVariant,
            ),
            padding: EdgeInsetsDirectional.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final ChatAttachment attachment;
  const _Thumbnail({required this.attachment});

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage && attachment.localPath != null) {
      return ClipRRect(
        borderRadius: AppRadius.r8,
        child: Image.file(
          File(attachment.localPath!),
          width: context.screenWidth * 0.128,
          height: context.screenWidth * 0.128,
          fit: .cover,
        ),
      );
    }
    final icon = attachment.isAudio
        ? AssetsConstants.microphoneIcon
        : AssetsConstants.fileIcon;
    return Container(
      width: context.screenWidth * 0.128,
      height: context.screenWidth * 0.128,
      decoration: AppDecorations.card(
        color: context.cs.primary.withValues(alpha: 0.1),
        borderRadius: AppRadius.r8,
      ),
      child: AppSvgIcon(icon, color: context.cs.primary, size: ThemeConstants.iconL),
    );
  }
}
