import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/commons/widgets/dashed_underline_tooltip.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/string_extensions.dart';
import 'package:flutter/material.dart';

class BillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDiscount;
  final String? suffixLabel;

  /// When true/false, a dashed-underline tag opens the refundable /
  /// non-refundable note in a bottom sheet. Ignored when
  /// [detailContentBuilder] is set — that sheet already carries the note.
  final bool? isRefundable;

  /// Overrides the default refundable-note tooltip body with structured
  /// content (e.g. a base-amount + tax breakdown) for the main [label].
  final WidgetBuilder? detailContentBuilder;

  /// Plain-message tooltip content for [suffixLabel] (e.g. subtotal's tax
  /// breakdown message).
  final String? suffixTooltipMessage;
  final String? suffixSheetTitle;
  final WidgetBuilder? suffixContentBuilder;

  const BillRow({
    super.key,
    required this.label,
    required this.value,
    this.isDiscount = false,
    this.suffixLabel,
    this.isRefundable,
    this.detailContentBuilder,
    this.suffixTooltipMessage,
    this.suffixSheetTitle,
    this.suffixContentBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDiscount
        ? context.cs.onSecondaryContainer
        : context.cs.onSurfaceVariant;
    final labelStyle = context.tt.labelMedium?.copyWith(color: color);
    final refundableMessage = isRefundable != null
        ? context.translate(
            isRefundable!
                ? LanguageLabelKeys.refundable
                : LanguageLabelKeys.notRefundable,
          )
        : null;

    return Row(
      mainAxisAlignment: .spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: .min,
            children: [
              if (detailContentBuilder != null || refundableMessage != null)
                DashedUnderlineTooltip(
                  text: label,
                  message: refundableMessage ?? '',
                  contentBuilder: detailContentBuilder,
                  style: labelStyle,
                )
              else
                AppText(label, style: labelStyle),
              if (suffixLabel.isNotNullOrEmpty) ...[
                AppSpacing.w4,
                Flexible(
                  child:
                      suffixTooltipMessage.isNotNullOrEmpty ||
                          suffixContentBuilder != null
                      ? DashedUnderlineTooltip(
                          text: suffixLabel!,
                          message: suffixTooltipMessage ?? '',
                          sheetTitle: suffixSheetTitle,
                          contentBuilder: suffixContentBuilder,
                          style: context.tt.labelSmall?.copyWith(
                            color: context.cs.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        )
                      : AppText(
                          suffixLabel!,
                          style: context.tt.labelSmall?.copyWith(
                            color: context.cs.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          overflow: .ellipsis,
                        ),
                ),
              ],
            ],
          ),
        ),
        AppText(
          value,
          style: context.tt.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
