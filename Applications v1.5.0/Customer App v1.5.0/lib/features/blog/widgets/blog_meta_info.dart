import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/blog/models/blog_model.dart';
import 'package:customer/utils/app_date_formatter.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';

class BlogMetaInfo extends StatelessWidget {
  final Blog blog;
  final double iconSize;
  final double dateIconSize;
  final SizedBox groupSpacing;
  final TextStyle? textStyle;
  final bool showDate;

  const BlogMetaInfo({
    super.key,
    required this.blog,
    this.iconSize = 13,
    this.dateIconSize = 12,
    this.groupSpacing = AppSpacing.w12,
    this.textStyle,
    this.showDate = true,
  });

  @override
  Widget build(BuildContext context) {
    final style =
        textStyle ??
        context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant);
    return Row(
      children: [
        AppSvgIcon(
          AssetsConstants.timeIcon,
          size: iconSize,
          color: context.cs.onSurfaceVariant,
        ),
        AppSpacing.w4,
        AppText(
          '${blog.readTime ?? '0'} ${context.translate(LanguageLabelKeys.read)}',
          style: style,
        ),
        groupSpacing,
        AppSvgIcon(
          AssetsConstants.passwordVisibleIcon,
          size: iconSize,
          color: context.cs.onSurfaceVariant,
        ),
        AppSpacing.w4,
        AppText(
          '${blog.viewsCount ?? '0'} ${context.translate(LanguageLabelKeys.views)}',
          style: style,
        ),
        if (showDate && (blog.createdAt ?? '').isNotEmpty) ...[
          groupSpacing,
          AppSvgIcon(
            AssetsConstants.dateIcon,
            size: dateIconSize,
            color: context.cs.onSurfaceVariant,
          ),
          AppSpacing.w4,
          Expanded(
            child: AppText(
              AppDateFormatter.formatDateTime(blog.createdAt!),
              style: style,
              maxLines: 1,
              overflow: .ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
