import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Common selectable row used with a [RadioGroup]: leading (optional) +
/// title (+ optional subtitle) + trailing [Radio]. Used across bottom
/// sheets like theme, language and sort selection.
class AppRadioOptionTile<T> extends StatelessWidget {
  final T value;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final bool showContainerDecoration;
  final bool highlightSelectedColor;
  final EdgeInsetsDirectional? margin;
  final EdgeInsetsDirectional padding;
  final Widget? trailing;

  const AppRadioOptionTile({
    super.key,
    required this.value,
    required this.selected,
    required this.onTap,
    required this.title,
    this.subtitle,
    this.leading,
    this.enabled = true,
    this.showContainerDecoration = true,
    this.highlightSelectedColor = true,
    this.margin,
    this.padding = const EdgeInsetsDirectional.symmetric(
      horizontal: ThemeConstants.paddingXS,
      vertical: ThemeConstants.paddingXS,
    ),
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = selected && highlightSelectedColor
        ? context.cs.primary
        : context.cs.onSurface;

    final titleStyle = context.tt.bodyMedium?.copyWith(
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      color: titleColor,
    );

    final content = Row(
      spacing: ThemeConstants.spaceL,
      children: [
        ?leading,
        Expanded(
          child: subtitle == null
              ? AppText(title, style: titleStyle)
              : Column(
                  crossAxisAlignment: .start,
                  spacing: ThemeConstants.spaceXXS,
                  children: [
                    AppText(title, style: titleStyle),
                    AppText(
                      subtitle!,
                      style: context.tt.labelSmall?.copyWith(
                        color: selected
                            ? context.cs.primary.withValues(alpha: 0.5)
                            : context.cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
        ),
        trailing ??
            Radio<T>(
              value: value,
              activeColor: context.cs.primary,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
      ],
    );

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: AppRadius.r12,
      child: showContainerDecoration
          ? Container(
              margin:
                  margin ?? const EdgeInsetsDirectional.symmetric(vertical: 1),
              padding: padding,
              decoration: AppDecorations.selectableOption(),
              child: content,
            )
          : Padding(padding: padding, child: content),
    );
  }
}
