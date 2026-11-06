import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/constants/theme_constants.dart';

class MenuItemData {
  final String iconPath;
  final String label;
  final VoidCallback onTap;
  final String? trailing;
  final bool selected;
  const MenuItemData({
    required this.iconPath,
    required this.label,
    required this.onTap,
    this.trailing,
    this.selected = false,
  });
}

class MenuCard extends StatelessWidget {
  final String title;
  final List<MenuItemData> items;
  final Widget? footer;

  const MenuCard({
    super.key,
    required this.title,
    required this.items,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.shadowedCard(
        color: context.cs.surface,
        shadowColor: context.theme.shadowColor.withValues(alpha: 0.06),
        borderRadius: AppRadius.r16,
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              ThemeConstants.paddingL,
              ThemeConstants.paddingM,
              ThemeConstants.paddingL,
              ThemeConstants.paddingM,
            ),
            child: AppText(
              title,
              style: context.tt.titleMedium?.copyWith(
                color: context.cs.onSurface,
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: context.cs.outlineVariant),
          ...List.generate(items.length, (i) {
            final item = items[i];
            final isLast = i == items.length - 1 && footer == null;
            return Column(
              children: [
                InkWell(
                  onTap: item.onTap,
                  borderRadius: isLast ? AppRadius.bottom16 : null,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: ThemeConstants.paddingL,
                      vertical: ThemeConstants.paddingM,
                    ),
                    child: Row(
                      children: [
                        AppSvgIcon(
                          item.iconPath,
                          size: ThemeConstants.iconS,
                          color: context.cs.onSurfaceVariant,
                          bakeTint: true,
                        ),
                        AppSpacing.w10,
                        Expanded(
                          child: AppText(
                            item.label,
                            style: context.tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: context.cs.onSurface,
                            ),
                          ),
                        ),
                        if (item.trailing != null) ...[
                          AppText(
                            item.trailing!,
                            style: context.tt.bodySmall?.copyWith(
                              fontSize: 13,
                              color: context.cs.onSurfaceVariant,
                            ),
                          ),
                          AppSpacing.w4,
                        ],
                        Transform.flip(
                          flipX:
                              Directionality.of(context) == TextDirection.rtl,
                          child: AppSvgIcon(
                            AssetsConstants.arrowRightIcon,
                            color: context.cs.onSurfaceVariant,
                            size: ThemeConstants.iconS,
                            bakeTint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: context.cs.outlineVariant,
                  ),
              ],
            );
          }),
          if (footer != null) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: context.cs.outlineVariant,
              indent: ThemeConstants.paddingXXL * 2 + ThemeConstants.paddingXS,
            ),
            footer!,
          ],
        ],
      ),
    );
  }
}
