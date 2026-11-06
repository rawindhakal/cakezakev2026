import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Data for a single row inside a [ProfileMenuCard] or expandable section.
class ProfileMenuItemData {
  final String iconPath;
  final String label;
  final VoidCallback onTap;
  final String? trailing;
  final Widget? trailingWidget;
  const ProfileMenuItemData({
    required this.iconPath,
    required this.label,
    required this.onTap,
    this.trailing,
    this.trailingWidget,
  });
}

/// Section header label used above profile menu groups.
class ProfileSectionLabel extends StatelessWidget {
  final String text;
  const ProfileSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingL, 0, ThemeConstants.paddingL, ThemeConstants.paddingM),
      child: AppText(
        text,
        style: context.tt.titleSmall?.copyWith(color: context.cs.onSurface),
      ),
    );
  }
}

/// Card listing a group of tappable profile menu items.
class ProfileMenuCard extends StatelessWidget {
  final String? title;
  final List<ProfileMenuItemData> items;
  const ProfileMenuCard({super.key, this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.shadowedCard(
        color: Theme.of(context).cardColor,
        shadowColor: context.cs.shadow,
      ),
      clipBehavior: .antiAlias,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingL, ThemeConstants.paddingM, ThemeConstants.paddingL, ThemeConstants.paddingM),
              child: AppText(
                title!,
                style: context.tt.titleSmall?.copyWith(
                  color: context.cs.onSurface,
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: context.cs.outlineVariant),
          ],
          ...List.generate(items.length, (i) {
            final item = items[i];
            final isLast = i == items.length - 1;
            return Column(
              children: [
                InkWell(
                  onTap: item.onTap,
                  borderRadius: isLast ? AppRadius.bottom12 : null,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: ThemeConstants.paddingL,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        AppSvgIcon(
                          item.iconPath,
                          size: ThemeConstants.iconS,
                          color: context.cs.onSurfaceVariant,
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
                            style: context.tt.headlineLarge?.copyWith(
                              color: context.cs.onSurfaceVariant,
                            ),
                          ),
                          AppSpacing.w4,
                        ],
                        if (item.trailingWidget != null) ...[
                          item.trailingWidget!,
                          AppSpacing.w4,
                        ],
                        Transform.flip(
                          flipX:
                              Directionality.of(context) ==
                              TextDirection.rtl,
                          child: AppSvgIcon(
                            AssetsConstants.arrowRightIcon,
                            color: context.cs.onSurfaceVariant,
                            size: ThemeConstants.iconS,
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
        ],
      ),
    );
  }
}

/// Collapsible profile menu card that reveals a list of sub-items on tap.
class ProfileExpandableMenuSection extends StatefulWidget {
  final String iconPath;
  final String label;
  final String? title;
  final List<ProfileMenuItemData> children;

  const ProfileExpandableMenuSection({
    super.key,
    required this.iconPath,
    required this.label,
    this.title,
    required this.children,
  });

  @override
  State<ProfileExpandableMenuSection> createState() =>
      _ProfileExpandableMenuSectionState();
}

class _ProfileExpandableMenuSectionState
    extends State<ProfileExpandableMenuSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.shadowedCard(
        color: Theme.of(context).cardColor,
        shadowColor: context.cs.shadow,
      ),
      clipBehavior: .antiAlias,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          if (widget.title != null) ...[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingL, ThemeConstants.paddingM, ThemeConstants.paddingL, ThemeConstants.paddingM),
              child: AppText(
                widget.title!,
                style: context.tt.titleSmall?.copyWith(
                  color: context.cs.onSurface,
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: context.cs.outlineVariant),
          ],
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: _expanded ? null : AppRadius.bottom12,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: ThemeConstants.paddingL,
                vertical: 13,
              ),
              child: Row(
                children: [
                  AppSvgIcon(
                    widget.iconPath,
                    size: ThemeConstants.iconM,
                    color: context.cs.onSurfaceVariant,
                  ),
                  AppSpacing.w14,
                  Expanded(
                    child: AppText(
                      widget.label,
                      style: context.tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: context.cs.onSurface,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: AppSvgIcon(
                      AssetsConstants.arrowDownIcon,
                      color: context.cs.onSurfaceVariant,
                      size: ThemeConstants.iconS,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: List.generate(widget.children.length, (i) {
                final child = widget.children[i];
                return Column(
                  children: [
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: context.cs.outlineVariant,
                    ),
                    InkWell(
                      onTap: child.onTap,
                      borderRadius: i == widget.children.length - 1
                          ? AppRadius.bottom12
                          : null,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 52,
                          end: ThemeConstants.paddingL,
                          top: ThemeConstants.paddingM,
                          bottom: ThemeConstants.paddingM,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: AppText(
                                child.label,
                                style: context.tt.headlineLarge?.copyWith(
                                  color: context.cs.onSurface,
                                ),
                              ),
                            ),
                            Transform.flip(
                              flipX:
                                  Directionality.of(context) ==
                                  TextDirection.rtl,
                              child: AppSvgIcon(
                                AssetsConstants.arrowRightIcon,
                                color: context.cs.onSurfaceVariant,
                                size: ThemeConstants.iconS,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
