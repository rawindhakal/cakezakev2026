import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/num_extensions.dart';
import 'package:flutter/material.dart';

/// Highlighted callout for a refund amount, shown standalone on order detail
/// screens (already credited) instead of blending into the bill summary card.
class OrderRefundCard extends StatelessWidget {
  final double refundAmount;
  final String currency;

  const OrderRefundCard({
    super.key,
    required this.refundAmount,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.cs.inversePrimary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
      decoration: AppDecorations.card(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: AppRadius.r12,
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: ThemeConstants.spaceM,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: AppDecorations.card(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: AppSvgIcon(
              AssetsConstants.walletIcon,
              size: ThemeConstants.iconS,
              color: context.cs.onPrimary,
              fit: BoxFit.scaleDown,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: ThemeConstants.spaceXXS,
              children: [
                AppText(
                  '${context.translate(LanguageLabelKeys.refundAmount)} $currency${refundAmount.trimmedFixed()}',
                  style: context.tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                AppText(
                  context.translate(LanguageLabelKeys.refundCreditedToWallet),
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
