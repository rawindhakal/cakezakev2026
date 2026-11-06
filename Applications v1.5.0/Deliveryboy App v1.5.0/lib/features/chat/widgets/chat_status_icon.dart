import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/loading_widget.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class ChatStatusIcon extends StatelessWidget {
  final MessageStatus status;
  const ChatStatusIcon({super.key, required this.status});

  @override
  Widget build(BuildContext context) => switch (status) {
    MessageStatus.sending => LoadingWidget(size: ThemeConstants.loaderSizeS),
    MessageStatus.sent => AppSvgIcon(
      AssetsConstants.checkReadIcon,
      size: ThemeConstants.iconXS,
      color: context.cs.onPrimary.withValues(alpha: 0.7),
    ),
    MessageStatus.failed => AppSvgIcon(
      AssetsConstants.infoCircleIcon,
      size: ThemeConstants.iconXS,
      color: context.cs.error,
    ),
  };
}
