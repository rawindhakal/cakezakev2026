import 'package:deliveryboy/commons/widgets/shimmer_loading.dart';
import 'package:deliveryboy/commons/widgets/app_snack_bar.dart';
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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../cubit/chat_cubit.dart';
import '../models/chat_message.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

class ChatFileAttachment extends StatefulWidget {
  final ChatAttachment attachment;
  final bool isMe;
  const ChatFileAttachment({
    super.key,
    required this.attachment,
    required this.isMe,
  });

  @override
  State<ChatFileAttachment> createState() => _ChatFileAttachmentState();
}

class _ChatFileAttachmentState extends State<ChatFileAttachment> {
  bool _downloading = false;

  Future<void> _open() async {
    final att = widget.attachment;
    if (_downloading) return;
    if (att.hasLocal) {
      await OpenFile.open(att.localPath!);
      return;
    }
    if (!att.hasRemote) return;
    final chatCubit = context.read<ChatCubit>();
    setState(() => _downloading = true);
    try {
      final dir = await getTemporaryDirectory();
      final fileName = att.fileName ?? att.remoteUrl!.split('/').last;
      final savePath = '${dir.path}/$fileName';
      await chatCubit.downloadAttachment(att.remoteUrl!, savePath);
      if (mounted) await OpenFile.open(savePath);
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context: context,
          message: context.translate(LanguageLabelKeys.couldNotDownloadFile),
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    final attachment = widget.attachment;
    return InkWell(
      onTap: _open,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, ThemeConstants.paddingXS),
        child: Row(
          mainAxisSize: .min,
          children: [
            Container(
              width: context.screenWidth * 0.101,
              height: context.screenWidth * 0.101,
              decoration: AppDecorations.card(
                color: isMe
                    ? context.cs.onPrimary.withValues(alpha: 0.2)
                    : context.cs.primary.withValues(alpha: 0.12),
                borderRadius: AppRadius.r8,
              ),
              child: _downloading
                  ? Padding(
                      padding: const EdgeInsetsDirectional.all(10),
                      child: ShimmerInline(),
                    )
                  : AppSvgIcon(
                      attachment.isVideo
                          ? AssetsConstants.playCircleIcon
                          : AssetsConstants.fileIcon,
                      color: isMe ? context.cs.onPrimary : context.cs.primary,
                      size: ThemeConstants.iconL,
                      fit: BoxFit.scaleDown,
                    ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: AppText(
                attachment.fileName ??
                    context.translate(LanguageLabelKeys.attachmentFile),
                style: context.tt.labelMedium?.copyWith(
                  color: isMe ? context.cs.onPrimary : context.cs.onSurface,
                ),
                overflow: .ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
