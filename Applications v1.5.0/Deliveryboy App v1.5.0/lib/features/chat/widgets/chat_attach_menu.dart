import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/utils/show_app_bottom_sheet.dart';
import 'package:deliveryboy/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

void showChatAttachMenu(
  BuildContext context, {
  required VoidCallback onCamera,
  required VoidCallback onGallery,
  required VoidCallback onFile,
}) {
  showAppBottomSheet(
    context,
    title: context.translate(LanguageLabelKeys.attachment),
    padding: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingL, ThemeConstants.paddingM, ThemeConstants.paddingL, ThemeConstants.paddingXXL),
    builder: (ctx) {
      final options = [
        _AttachOption(
          icon: AssetsConstants.cameraIcon,
          label: context.translate(LanguageLabelKeys.camera),
          color: ctx.cs.onSurfaceVariant,
          onTap: onCamera,
        ),
        _AttachOption(
          icon: AssetsConstants.galleryIcon,
          label: context.translate(LanguageLabelKeys.gallery),
          color: ctx.cs.onSurfaceVariant,
          onTap: onGallery,
        ),
        _AttachOption(
          icon: AssetsConstants.fileIcon,
          label: context.translate(LanguageLabelKeys.file),
          color: ctx.cs.onSurfaceVariant,
          onTap: onFile,
        ),
      ];

      return SlideAnimationScope(
        builder: (context, animationController) => Row(
          mainAxisAlignment: .spaceEvenly,
          children: [
            for (var i = 0; i < options.length; i++)
              SlideAnimation(
                position: i,
                slideDirection: SlideDirection.fromBottom,
                itemCount: options.length,
                animationController: animationController,
                child: options[i],
              ),
          ],
        ),
      );
    },
  );
}

class _AttachOption extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: .min,
        children: [
          Container(
            width: context.screenWidth * 0.16,
            height: context.screenWidth * 0.16,
            decoration: AppDecorations.circle(
              color: color.withValues(alpha: 0.12),
            ),
            child: AppSvgIcon(
              icon,
              size: ThemeConstants.iconL,
              color: color,
              fit: BoxFit.scaleDown,
            ),
          ),
          SizedBox(height: context.screenHeight * 0.010),
          AppText(
            label,
            style: context.tt.bodySmall?.copyWith(
              color: context.cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
