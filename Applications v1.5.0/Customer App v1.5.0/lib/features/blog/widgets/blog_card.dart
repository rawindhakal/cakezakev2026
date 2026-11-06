import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/blog/models/blog_model.dart';
import 'package:customer/features/blog/widgets/blog_meta_info.dart';
import 'package:customer/utils/app_date_formatter.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class BlogCard extends StatelessWidget {
  final Blog blog;
  const BlogCard({super.key, required this.blog});

  @override
  Widget build(BuildContext context) {
    final categoryName = blog.category?.name;
    return GestureDetector(
      onTap: () => AppNavigator.pushNamed(
        context,
        RouteNames.blogDetail,
        arguments: blog,
      ),
      child: Container(
        decoration: AppDecorations.box(
          color: context.cs.surface,
          borderRadius: AppRadius.r10,
          border: Border.all(color: context.cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            if ((blog.imageUrl ?? '').isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 10,
                child: AppNetworkImage(
                  url: blog.imageUrl!,
                  borderRadius: AppRadius.top10,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    color: context.cs.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: FractionallySizedBox(
                      widthFactor: 0.3,
                      heightFactor: 0.3,
                      child: AppSvgIcon(
                        AssetsConstants.placeholder,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  errorWidget: Container(
                    color: context.cs.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: FractionallySizedBox(
                      widthFactor: 0.3,
                      heightFactor: 0.3,
                      child: AppSvgIcon(
                        AssetsConstants.placeholder,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  if ((categoryName != null && categoryName.isNotEmpty) ||
                      (blog.createdAt ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        bottom: ThemeConstants.paddingXS,
                      ),
                      child: Row(
                        mainAxisAlignment: .spaceBetween,
                        children: [
                          if (categoryName != null && categoryName.isNotEmpty)
                            Flexible(
                              child: Container(
                                padding: const EdgeInsetsDirectional.symmetric(
                                  horizontal: ThemeConstants.paddingS,
                                  vertical: ThemeConstants.paddingXS,
                                ),
                                decoration: AppDecorations.box(
                                  color: context.cs.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: AppRadius.r4,
                                ),
                                child: AppText(
                                  categoryName,
                                  maxLines: 1,
                                  overflow: .ellipsis,
                                  style: context.tt.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: context.cs.primary,
                                  ),
                                ),
                              ),
                            ),
                          if ((blog.createdAt ?? '').isNotEmpty) ...[
                            AppSpacing.w6,
                            AppText(
                              AppDateFormatter.formatDateTime(blog.createdAt!),
                              style: context.tt.labelSmall?.copyWith(
                                color: context.cs.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: .ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  AppText(
                    blog.title ?? '',
                    style: context.tt.bodyLarge?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.cs.onSurface,
                    ),
                    maxLines: 2,
                    overflow: .ellipsis,
                  ),
                  if ((blog.shortDescription ?? '').isNotEmpty) ...[
                    AppSpacing.h6,
                    AppText(
                      blog.shortDescription!,
                      style: context.tt.bodySmall?.copyWith(
                        fontSize: 13,
                        color: context.cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: .ellipsis,
                    ),
                  ],
                  AppSpacing.h10,
                  BlogMetaInfo(blog: blog, showDate: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
