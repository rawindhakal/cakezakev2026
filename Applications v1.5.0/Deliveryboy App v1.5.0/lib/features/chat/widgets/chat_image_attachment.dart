import 'package:deliveryboy/commons/widgets/shimmer_loading.dart';
import 'dart:io';
import 'package:deliveryboy/commons/widgets/app_network_image.dart';
import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class ChatImageAttachment extends StatelessWidget {
  final ChatAttachment attachment;
  final bool isMe;
  const ChatImageAttachment({
    super.key,
    required this.attachment,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    Widget img;
    if (attachment.hasLocal) {
      img = Image.file(
        File(attachment.localPath!),
        width: double.infinity,
        height: context.screenHeight * 0.246,
        fit: .cover,
      );
    } else if (attachment.hasRemote) {
      img = AppNetworkImage(
        url: attachment.remoteUrl!,
        width: double.infinity,
        height: context.screenHeight * 0.246,
        placeholder: Container(
          width: double.infinity,
          height: context.screenHeight * 0.246,
          color: isMe
              ? context.cs.primary.withValues(alpha: 0.3)
              : context.cs.surfaceContainerHighest,
          child: const ShimmerInline(size: 40),
        ),
        errorWidget: _brokenImage(context),
      );
    } else {
      img = _brokenImage(context);
    }
    return GestureDetector(
      onTap: () => AppNavigator.push(
        context,
        ChatFullScreenImage(attachment: attachment),
      ),
      child: img,
    );
  }

  Widget _brokenImage(BuildContext context) => Container(
    width: double.infinity,
    height: context.screenHeight * 0.148,
    color: isMe
        ? context.cs.primary.withValues(alpha: 0.3)
        : context.cs.surfaceContainerHighest,
    child: AppSvgIcon(
      AssetsConstants.fileBrokenIcon,
      color: isMe
          ? context.cs.onPrimary.withValues(alpha: 0.6)
          : context.cs.onSurfaceVariant,
      size: ThemeConstants.iconL,
      fit: BoxFit.scaleDown,
    ),
  );
}

class ChatFullScreenImage extends StatelessWidget {
  final ChatAttachment attachment;
  const ChatFullScreenImage({super.key, required this.attachment});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: context.cs.scrim,
      appBar: AppBar(
        backgroundColor: context.cs.scrim,
        foregroundColor: context.cs.onPrimary,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          child: attachment.hasLocal
              ? Image.file(File(attachment.localPath!))
              : attachment.hasRemote
              ? AppNetworkImage(url: attachment.remoteUrl!)
              : AppSvgIcon(
                  AssetsConstants.fileBrokenIcon,
                  color: context.cs.onPrimary,
                  size: ThemeConstants.iconL, fit: BoxFit.scaleDown,
                ),
        ),
      ),
    );
  }
}
