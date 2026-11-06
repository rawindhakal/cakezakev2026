import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import '../../utils/extensions/context_extensions.dart';
import '../../utils/extensions/size_extensions.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class EmptyStateWidget extends StatelessWidget {
  final String imagePath;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;
  final String retryLabel;

  const EmptyStateWidget({
    super.key,
    required this.imagePath,
    required this.title,
    required this.subtitle,
    this.onRetry,
    this.retryLabel = LanguageLabelKeys.retry,
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
              style: context.tt.headlineMedium?.copyWith(
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
                label: retryLabel,
                onPressed: onRetry,
                variant: AppButtonVariant.outline,
                fullWidth: false,
                height: 44,
                contentPadding: const EdgeInsetsDirectional.symmetric(
                  horizontal: ThemeConstants.paddingXXL,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
