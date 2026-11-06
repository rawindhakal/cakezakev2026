import 'package:deliveryboy/commons/widgets/app_button.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:flutter/material.dart';
import '../../utils/extensions/context_extensions.dart';
import '../../utils/extensions/localization_extensions.dart';
import '../../utils/extensions/size_extensions.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';

/// Centered empty/error state with an icon, message, and optional retry button.
class EmptyStateWidget extends StatelessWidget {
  final String imagePath;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const EmptyStateWidget({
    super.key,
    required this.imagePath,
    required this.title,
    required this.subtitle,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    // Some callers place this inside an unbounded-height parent (e.g. a
    // ListView, so pull-to-refresh keeps working on an empty list) where
    // `Center` alone can't fill anything and the content hugs the top
    // instead. Falling back to a chunk of screen height in that case keeps
    // it visually centered everywhere without every call site needing its
    // own Expanded/ConstrainedBox wrapper.
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : context.screenHeight * 0.7;
        return SizedBox(height: height, child: _buildContent(context));
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.all(ThemeConstants.spaceXXXL),
        child: Column(
          mainAxisSize: .min,
          children: [
            AppSvgIcon(
              imagePath,
              size: context.widthFraction(0.373),
              color: context.cs.primary,
              useColorMapper: true,
            ),
            AppSpacing.h16,
            AppText(
              title,
              textAlign: .center,
              style: context.tt.headlineSmall?.copyWith(
                fontWeight: FontWeight.w400,
                color: context.cs.onSurface,
              ),
            ),
            AppSpacing.h8,
            AppText(
              subtitle,
              textAlign: .center,
              style: context.tt.bodyLarge?.copyWith(
                color: context.cs.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              AppSpacing.h24,
              AppButton(
                label: retryLabel ?? context.translate(LanguageLabelKeys.retry),
                onPressed: onRetry,
                variant: AppButtonVariant.outline,
                width: context.screenWidth * 0.427,
                height: context.screenHeight * 0.054,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
