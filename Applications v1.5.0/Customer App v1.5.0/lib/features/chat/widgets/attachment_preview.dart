import 'dart:io';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../../../commons/widgets/app_text.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/constants/theme_constants.dart';

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
        ? context.translate(LanguageLabelKeys.image)
        : attachment.isAudio
        ? context.translate(LanguageLabelKeys.voiceMessage)
        : (attachment.fileName ?? context.translate(LanguageLabelKeys.file));
    final sublabel = attachment.isImage
        ? context.translate(LanguageLabelKeys.photoReadyToSend)
        : attachment.isAudio
        ? context.translate(LanguageLabelKeys.voiceMessageReadyToSend)
        : context.translate(LanguageLabelKeys.fileReadyToSend);

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingM,
        ThemeConstants.paddingS,
        ThemeConstants.paddingS,
        ThemeConstants.paddingS,
      ),
      decoration: AppDecorations.box(
        color: context.cs.primaryContainer,
        border: Border(
          top: BorderSide(color: context.cs.primary.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          _Thumbnail(attachment: attachment),
          AppSpacing.w10,
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              mainAxisSize: .min,
              children: [
                AppText(
                  label,
                  style: context.tt.bodySmall?.copyWith(
                    fontSize: 13,
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
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    }
    final icon = attachment.isAudio
        ? AssetsConstants.microphoneIcon
        : AssetsConstants.fileIcon;
    return Container(
      width: 48,
      height: 48,
      decoration: AppDecorations.box(
        color: context.cs.primary.withValues(alpha: 0.1),
        borderRadius: AppRadius.r8,
      ),
      child: AppSvgIcon(
        icon,
        color: context.cs.primary,
        size: ThemeConstants.iconL,
      ),
    );
  }
}
