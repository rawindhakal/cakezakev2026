import 'package:customer/commons/models/tax_charges_model.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';

String taxBreakdownMessage(
  BuildContext context,
  List<TaxCharges> taxes,
  String Function(num amount) formatAmount,
) {
  return taxes
      .where((TaxCharges c) => c.amount != null && c.amount != 0)
      .map(
        (TaxCharges c) =>
            '${c.name ?? ''}: ${formatAmount(c.amount ?? 0)} '
            '(${context.translate(LanguageLabelKeys.taxRate)}: ${c.rate ?? 0}%)',
      )
      .join('\n');
}

/// Whether a zone/surge charge carries any tax detail worth its own sheet.
bool hasChargeTaxDetail({
  String? taxName,
  double? taxAmount,
  double? taxableAmount,
  double? taxRate,
}) => (taxAmount ?? 0) > 0;

/// Tax detail sheet for a single zone/surge charge — shared by checkout and
/// order-detail screens so both stay in sync.
Widget additionalChargeDetailSheet(
  BuildContext context,
  String Function(num amount) formatAmount, {
  required String label,
  required num totalAmount,
  bool? isRefundable,
  String? taxName,
  double? taxAmount,
  double? taxRate,
}) {
  final baseAmount = totalAmount - (taxAmount ?? 0);
  final taxLabel = [
    if (taxName != null && taxName.isNotEmpty)
      taxName
    else
      context.translate(LanguageLabelKeys.tax),
    if (taxRate != null) '($taxRate%)',
  ].join(' ');
  Widget row(String text, num amount, {bool bold = false}) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(
      vertical: ThemeConstants.paddingXS,
    ),
    child: Row(
      mainAxisAlignment: .spaceBetween,
      children: [
        Expanded(
          child: AppText(
            text,
            style: bold
                ? context.tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.cs.onSurface,
                  )
                : context.tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: context.cs.onSurface,
                  ),
          ),
        ),
        AppText(
          formatAmount(amount),
          style: bold
              ? context.tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.cs.onSurface,
                )
              : context.tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.cs.onSurface,
                ),
        ),
      ],
    ),
  );
  return Column(
    crossAxisAlignment: .start,
    mainAxisSize: .min,
    children: [
      if (taxAmount != null) ...[
        row(label, baseAmount),
        row(taxLabel, taxAmount),
        AppSpacing.h8,
        const Divider(height: 1, thickness: 0.5),
        AppSpacing.h12,
        row(
          context.translate(LanguageLabelKeys.total),
          totalAmount,
          bold: true,
        ),
      ],
      if (isRefundable != null) ...[
        AppSpacing.h16,
        Row(
          crossAxisAlignment: .start,
          children: [
            AppSvgIcon(
              AssetsConstants.infoCircleIcon,
              size: ThemeConstants.iconS,
              color: context.cs.onSurfaceVariant,
            ),
            AppSpacing.w6,
            Expanded(
              child: AppText(
                context.translate(
                  isRefundable
                      ? LanguageLabelKeys.refundable
                      : LanguageLabelKeys.notRefundable,
                ),
                style: context.tt.bodySmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    ],
  );
}

Widget taxBreakdownSheet(
  BuildContext context,
  List<TaxCharges> taxes,
  String Function(num amount) formatAmount,
) {
  final nonZeroTaxes = taxes
      .where((TaxCharges c) => c.amount != null && c.amount != 0)
      .toList();
  final totalTax = nonZeroTaxes.fold<double>(
    0,
    (sum, c) => sum + (c.amount ?? 0),
  );
  return Column(
    crossAxisAlignment: .start,
    mainAxisSize: .min,
    children: [
      for (final c in nonZeroTaxes)
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: ThemeConstants.paddingXS,
          ),
          child: Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              Expanded(
                child: AppText(
                  [
                    if (c.name != null && c.name!.isNotEmpty) c.name!,
                    if (c.rate != null) '(${c.rate}%)',
                  ].join(' '),
                  style: context.tt.bodyMedium?.copyWith(
                    color: context.cs.onSurface,
                  ),
                ),
              ),
              AppText(
                formatAmount(c.amount ?? 0),
                style: context.tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      AppSpacing.h8,
      const Divider(height: 1, thickness: 0.5),
      AppSpacing.h12,
      Row(
        mainAxisAlignment: .spaceBetween,
        children: [
          AppText(
            context.translate(LanguageLabelKeys.total),
            style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          AppText(
            formatAmount(totalTax),
            style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ],
  );
}
