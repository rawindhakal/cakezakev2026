import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/payment_method/models/payment_method_item.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class PaymentMethodTile extends StatelessWidget {
  const PaymentMethodTile({
    super.key,
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  final PaymentMethodItem method;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderColor = isSelected ? cs.primary : cs.outline;
    final bgColor = isSelected
        ? cs.primary.withValues(alpha: 0.06)
        : cs.surface;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingS,
          vertical: ThemeConstants.paddingS,
        ),
        decoration: AppDecorations.box(
          color: bgColor,
          borderRadius: AppRadius.r12,
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            _PaymentIcon(iconPath: method.iconPath),
            AppSpacing.w12,
            Expanded(
              child: AppText(
                context.translate(method.label),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? Icon(
                      Icons.radio_button_checked_rounded,
                      color: cs.primary,
                      size: ThemeConstants.iconM,
                      key: const ValueKey('checked'),
                    )
                  : Icon(
                      Icons.radio_button_unchecked_rounded,
                      color: cs.outline,
                      size: ThemeConstants.iconM,
                      key: const ValueKey('unchecked'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentIcon extends StatelessWidget {
  const _PaymentIcon({required this.iconPath});

  final String iconPath;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 36,
      padding: const EdgeInsets.all(ThemeConstants.paddingXS),
      decoration: AppDecorations.outlinedCard(
        color: cs.surfaceContainerHighest,
        borderColor: cs.outline.withValues(alpha: 0.5),
        borderRadius: 8,
      ),
      child: AppSvgIcon(
        iconPath,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => const SizedBox.shrink(),
      ),
    );
  }
}
