import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';

/// Selectable row with optional leading icon, title/subtitle and a trailing
/// [Radio]. Used inside a [RadioGroup] for option sheets (theme, language, etc).
class AppRadioOptionTile<T> extends StatelessWidget {
  final T value;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final Widget? trailing;

  const AppRadioOptionTile({
    super.key,
    required this.value,
    required this.title,
    this.subtitle,
    this.leading,
    required this.selected,
    this.enabled = true,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: AppRadius.r12,
      child: Container(
        margin: const EdgeInsetsDirectional.symmetric(vertical: 1),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 5,
          vertical: 5,
        ),
        decoration: AppDecorations.selectableOption(
          primaryColor: context.cs.primary,
          outlineColor: context.cs.outline,
          selected: selected,
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, AppSpacing.w14],
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  AppText(
                    title,
                    style:
                        (selected
                                ? context.tt.labelLarge
                                : context.tt.bodyMedium)
                            ?.copyWith(
                              color: selected
                                  ? context.cs.primary
                                  : context.cs.onSurface,
                            ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    AppSpacing.h2,
                    AppText(
                      subtitle!,
                      style: context.tt.labelSmall?.copyWith(
                        color: selected
                            ? context.cs.primary.withValues(alpha: 0.5)
                            : context.cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
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
        ),
      ),
    );
  }
}
