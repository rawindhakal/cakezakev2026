import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/zigzag_top_clipper.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Layout for [SavedAmountBanner]: [zigzag] is the torn-ticket strip used at
/// the bottom of the bill card / compact-total sheet; [rounded] is a plain
/// gradient pill for standalone placement (e.g. top of the checkout screen).
enum SavedAmountBannerStyle { zigzag, rounded }

/// "You saved X on this order" banner — shown when a promo/wallet discount
/// reduced the total. Caller passes the already-formatted amount text (e.g.
/// `'$currency${saved.toStringAsFixed(2)}'`).
class SavedAmountBanner extends StatelessWidget {
  final String amountText;
  final SavedAmountBannerStyle style;

  const SavedAmountBanner({
    super.key,
    required this.amountText,
    this.style = SavedAmountBannerStyle.zigzag,
  });

  @override
  Widget build(BuildContext context) {
    final text =
        '${context.translate(LanguageLabelKeys.youSaved)} $amountText ${context.translate(LanguageLabelKeys.onThisOrder)}';

    if (style == SavedAmountBannerStyle.rounded) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingL,
          vertical: ThemeConstants.paddingM,
        ),
        decoration: BoxDecoration(
          borderRadius: AppRadius.r16,
          gradient: LinearGradient(
            begin: AlignmentDirectional.centerEnd,
            end: AlignmentDirectional.centerStart,
            colors: [
              context.cs.primary.withValues(alpha: 0.22),
              context.cs.primary.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: AppText(
          text,
          style: context.tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.cs.primary,
          ),
        ),
      );
    }

    return ClipPath(
      clipper: const ZigzagTopClipper(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.fromSTEB(
          0,
          ThemeConstants.paddingL,
          0,
          ThemeConstants.paddingS,
        ),
        color: context.cs.primary.withValues(alpha: 0.1),
        child: Row(
          mainAxisAlignment: .center,
          spacing: ThemeConstants.spaceS,
          children: [
            AppText(AppConstants.celebrateSymbol, style: context.tt.bodyMedium),
            AppText(
              text,
              style: context.tt.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
