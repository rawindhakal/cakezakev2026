import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Highlighted gift-style callout for a cashback amount — used on the
/// checkout bill summary (pending, credited after delivery) and on order
/// detail screens (already credited), so cashback always looks the same
/// wherever it shows up instead of blending into a plain bill row.
class CashbackBanner extends StatelessWidget {
  final String amountText;
  final String subtitle;
  final String icon;
  final Color? color;

  const CashbackBanner({
    super.key,
    required this.amountText,
    required this.subtitle,
    this.icon = AssetsConstants.giftIcon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? context.cs.onSecondaryContainer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
      decoration: AppDecorations.box(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            resolvedColor.withValues(alpha: 0.14),
            resolvedColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: AppRadius.r12,
        border: Border.all(
          color: resolvedColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: .center,
        spacing: ThemeConstants.spaceM,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: AppDecorations.box(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [resolvedColor, resolvedColor.withValues(alpha: 0.7)],
              ),
              shape: .circle,
              boxShadow: [
                BoxShadow(
                  color: resolvedColor.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: AppSvgIcon(
              icon,
              size: ThemeConstants.iconS,
              color: context.cs.onPrimary,
              fit: BoxFit.scaleDown,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              spacing: ThemeConstants.spaceXXS,
              children: [
                AppText(
                  amountText,
                  style: context.tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: resolvedColor,
                  ),
                ),
                AppText(
                  subtitle,
                  style: context.tt.labelSmall?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
