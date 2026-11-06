import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/utils/extensions/num_extensions.dart';
import 'package:customer/commons/widgets/cashback_banner.dart';
import 'package:customer/commons/widgets/dashed_underline_tooltip.dart';
import 'package:customer/commons/widgets/saved_amount_banner.dart';
import 'package:customer/commons/widgets/tax_breakdown_sheet.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/commons/models/additional_charges_model.dart';
import 'package:customer/features/cart/models/cart_model.dart';
import 'package:customer/commons/models/surge_charges_model.dart';
import 'package:customer/commons/models/tax_charges_model.dart';
import 'package:customer/features/checkout/widgets/checkout_shared_widgets.dart';
import 'package:customer/features/promo_code/models/enums/promo_apply_type.dart';
import 'package:customer/features/promo_code/models/enums/promo_discount_type.dart';
import 'package:customer/features/promo_code/models/promo_code_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

String _fmt(CartData cartData, num amount) =>
    '${cartData.currency}${amount.formatPrice(cartData.decimalPoint!)}';

/// Shared promo math between the collapsed row and the full sheet: a wallet
/// promo (`discount_apply_type: wallet`) is credited as cashback after
/// delivery instead of being subtracted from the bill like an instant
/// discount is.
class _PromoTotals {
  factory _PromoTotals(CartData cartData, PromoCodeData? appliedPromo) {
    final isWalletPromo =
        appliedPromo != null &&
        appliedPromo.discountApplyTypeEnum == PromoApplyType.wallet;
    final saved =
        (cartData.savedAmount ?? 0) +
        (appliedPromo != null && !isWalletPromo ? appliedPromo.discount : 0);
    final cashback = isWalletPromo ? appliedPromo.discount : 0;
    final total = appliedPromo != null
        ? (isWalletPromo
              ? cartData.totalAmount!
              : cartData.totalAmount! - appliedPromo.discount)
        : (cartData.totalAmount ?? 0);
    return _PromoTotals._(
      isWalletPromo: isWalletPromo,
      saved: saved,
      cashback: cashback,
      total: total,
    );
  }

  const _PromoTotals._({
    required this.isWalletPromo,
    required this.saved,
    required this.cashback,
    required this.total,
  });

  final bool isWalletPromo;
  final num saved;
  final num cashback;
  final num total;
}

class CheckoutBillDetailsSection extends StatelessWidget {
  const CheckoutBillDetailsSection({
    super.key,
    required this.cartData,
    required this.currency,
    this.appliedPromo,
    this.useWallet = false,
    this.isPickup = false,
  });

  final CartData cartData;
  final String currency;
  final PromoCodeData? appliedPromo;
  final bool useWallet;
  final bool isPickup;

  Future<void> _openSummarySheet(BuildContext context) {
    return showAppBottomSheet(
      context,
      showDragHandle: false,
      padding: null,
      backgroundColor: context.cs.surfaceContainer,
      builder: (_) => _BillSummarySheet(
        cartData: cartData,
        appliedPromo: appliedPromo,
        useWallet: useWallet,
        isPickup: isPickup,
      ),
    );
  }

  Widget _badge(
    BuildContext context, {
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ThemeConstants.paddingS,
        vertical: ThemeConstants.paddingXS,
      ),
      decoration: AppDecorations.box(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.r6,
      ),
      child: AppText(
        text,
        style: context.tt.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totals = _PromoTotals(cartData, appliedPromo);
    final saved = totals.saved;
    final cashback = totals.cashback;
    final total = totals.total;
    final original = total + saved;

    return InkWell(
      borderRadius: AppRadius.r12,
      onTap: () => _openSummarySheet(context),
      child: CheckoutCard(
        child: Row(
          crossAxisAlignment: .start,
          mainAxisAlignment: .center,
          children: [
            AppSvgIcon(
              AssetsConstants.billIcon,
              size: ThemeConstants.iconM,
              color: context.cs.onSurfaceVariant,
            ),
            AppSpacing.w10,
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: ThemeConstants.spaceS,
                children: [
                  AppText(
                    context.translate(LanguageLabelKeys.totalAmount),
                    style: context.tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (saved > 0)
                    AppText(
                      _fmt(cartData, original),
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.onSurfaceVariant,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  AppText(
                    _fmt(cartData, total),
                    style: context.tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (saved > 0)
                    _badge(
                      context,
                      text:
                          '${context.translate(LanguageLabelKeys.youSaved)} ${_fmt(cartData, saved)}',
                      color: context.cs.primary,
                    ),
                  if (cashback > 0)
                    _badge(
                      context,
                      text:
                          '${context.translate(LanguageLabelKeys.cashback)} ${_fmt(cartData, cashback)}',
                      color: context.cs.onSecondaryContainer,
                    ),
                ],
              ),
            ),
            Transform.flip(
              flipX: Directionality.of(context) == TextDirection.rtl,
              child: AppSvgIcon(
                AssetsConstants.arrowRightIcon,
                color: context.cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full bill breakdown, opened from the collapsed [CheckoutBillDetailsSection]
/// row — its rows reveal bottom-to-top, staggered one by one.
class _BillSummarySheet extends StatefulWidget {
  const _BillSummarySheet({
    required this.cartData,
    this.appliedPromo,
    this.useWallet = false,
    this.isPickup = false,
  });

  final CartData cartData;
  final PromoCodeData? appliedPromo;
  final bool useWallet;
  final bool isPickup;

  @override
  State<_BillSummarySheet> createState() => _BillSummarySheetState();
}

class _BillData {
  const _BillData({
    required this.subTotal,
    required this.delivery,
    required this.totals,
    required this.walletUsed,
    required this.payable,
  });

  final num subTotal;
  final double delivery;
  final _PromoTotals totals;
  final num walletUsed;
  final num payable;
}

class _BillSummarySheetState extends State<_BillSummarySheet> {
  _BillData _computeBillData() {
    final cartData = widget.cartData;
    final totals = _PromoTotals(cartData, widget.appliedPromo);

    final walletBalance = cartData.userBalance ?? 0.0;
    final walletUsed = widget.useWallet && walletBalance > 0
        ? (walletBalance >= totals.total ? totals.total : walletBalance)
        : 0.0;

    return _BillData(
      subTotal: cartData.subTotal ?? 0,
      delivery: cartData.deliveryCharges?.amount ?? 0,
      totals: totals,
      walletUsed: walletUsed,
      payable: totals.total - walletUsed,
    );
  }

  Widget _totalRow(BuildContext context, String label, num amount) {
    return Row(
      mainAxisAlignment: .spaceBetween,
      children: [
        AppText(
          label,
          style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        AppText(
          _fmt(widget.cartData, amount),
          style: context.tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.cs.primary,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCardRows(BuildContext context, _BillData data) {
    final cartData = widget.cartData;
    final appliedPromo = widget.appliedPromo;
    final totals = data.totals;
    final hasTax =
        cartData.taxBreakdown?.any(
          (TaxCharges c) => c.amount != null && c.amount != 0,
        ) ??
        false;
    return [
      CheckoutBillRow(
        label: context.translate(LanguageLabelKeys.subtotal),
        value: _fmt(cartData, data.subTotal),
        suffixLabel: hasTax
            ? context.translate(LanguageLabelKeys.inclTax)
            : null,
        suffixTooltipMessage: hasTax
            ? taxBreakdownMessage(
                context,
                cartData.taxBreakdown!,
                (amount) => _fmt(cartData, amount),
              )
            : null,
        suffixSheetTitle: hasTax
            ? context.translate(LanguageLabelKeys.taxBreakdown)
            : null,
        suffixContentBuilder: hasTax
            ? (sheetContext) => taxBreakdownSheet(
                sheetContext,
                cartData.taxBreakdown!,
                (amount) => _fmt(cartData, amount),
              )
            : null,
      ),
      AppSpacing.h8,
      if (widget.isPickup)
        ...[]
      else if (appliedPromo != null &&
          appliedPromo.discountTypeEnum == PromoDiscountType.freeDelivery)
        CheckoutBillRow(
          label: context.translate(LanguageLabelKeys.deliveryCharge),
          value:
              '${context.translate(LanguageLabelKeys.free)} ${context.translate(LanguageLabelKeys.withCode)} \'${appliedPromo.promoCode}\'',
          valueColor: context.cs.onSecondaryContainer,
        )
      else if (data.delivery > 0)
        CheckoutBillRow(
          label: context.translate(LanguageLabelKeys.deliveryCharge),
          value: _fmt(cartData, data.delivery),
          detailContentBuilder:
              hasChargeTaxDetail(
                taxName: cartData.deliveryCharges?.taxName,
                taxAmount: cartData.deliveryCharges?.taxAmount,
                taxableAmount: cartData.deliveryCharges?.taxableAmount,
                taxRate: cartData.deliveryCharges?.taxRate,
              )
              ? (sheetContext) => additionalChargeDetailSheet(
                  sheetContext,
                  (amount) => _fmt(cartData, amount),
                  label: context.translate(LanguageLabelKeys.deliveryCharge),
                  totalAmount: data.delivery,
                  taxName: cartData.deliveryCharges?.taxName,
                  taxAmount: cartData.deliveryCharges?.taxAmount,
                  taxRate: cartData.deliveryCharges?.taxRate,
                )
              : null,
        )
      else
        CheckoutBillRow(
          label: context.translate(LanguageLabelKeys.deliveryCharge),
          value: context.translate(LanguageLabelKeys.free),
          valueColor: context.cs.onSecondaryContainer,
        ),
      ...?(cartData.surgeCharges?.map((SurgeCharges c) {
        final hasTaxDetail = hasChargeTaxDetail(
          taxName: c.taxName,
          taxAmount: c.taxAmount,
          taxableAmount: c.taxableAmount,
          taxRate: c.taxRate,
        );
        return Padding(
          padding: const EdgeInsetsDirectional.only(
            top: ThemeConstants.paddingS,
          ),
          child: CheckoutBillRow(
            label: c.label ?? '',
            value: _fmt(cartData, c.charge ?? 0),
            isRefundable: hasTaxDetail ? null : c.isRefundable,
            detailContentBuilder: hasTaxDetail
                ? (sheetContext) => additionalChargeDetailSheet(
                    sheetContext,
                    (amount) => _fmt(cartData, amount),
                    label: c.label ?? '',
                    totalAmount: c.charge ?? 0,
                    isRefundable: c.isRefundable,
                    taxName: c.taxName,
                    taxAmount: c.taxAmount,
                    taxRate: c.taxRate,
                  )
                : null,
          ),
        );
      })),
      ...?(cartData.zoneAdditionalCharges?.map((AdditionalCharges c) {
        final hasTaxDetail = hasChargeTaxDetail(
          taxName: c.taxName,
          taxAmount: c.taxAmount,
          taxableAmount: c.taxableAmount,
          taxRate: c.taxRate,
        );
        return Padding(
          padding: const EdgeInsetsDirectional.only(
            top: ThemeConstants.paddingS,
          ),
          child: CheckoutBillRow(
            label: c.name ?? '',
            value: _fmt(cartData, c.amount ?? 0),
            isRefundable: hasTaxDetail ? null : c.isRefundable,
            detailContentBuilder: hasTaxDetail
                ? (sheetContext) => additionalChargeDetailSheet(
                    sheetContext,
                    (amount) => _fmt(cartData, amount),
                    label: c.name ?? '',
                    totalAmount: c.amount ?? 0,
                    isRefundable: c.isRefundable,
                    taxName: c.taxName,
                    taxAmount: c.taxAmount,
                    taxRate: c.taxRate,
                  )
                : null,
          ),
        );
      })),
      if (appliedPromo != null &&
          (totals.isWalletPromo ||
              appliedPromo.discountTypeEnum ==
                  PromoDiscountType.freeDelivery)) ...[
        // Wallet promos: cashback isn't part of this bill — it's credited to
        // the wallet after delivery — so it gets its own highlighted callout
        // below instead of sitting in the itemized total like a discount.
        // Free-delivery promos: already reflected above on the delivery
        // charge row, so no separate promo line is needed here.
      ] else if (appliedPromo != null) ...[
        AppSpacing.h8,
        CheckoutBillRow(
          label:
              '${context.translate(LanguageLabelKeys.promo)} (${appliedPromo.promoCode})',
          value: '-${_fmt(cartData, appliedPromo.discount)}',
          valueColor: context.cs.onSecondaryContainer,
        ),
      ],
      AppSpacing.h12,
      const Divider(height: 1, thickness: 0.5),
      AppSpacing.h12,
      _totalRow(
        context,
        context.translate(LanguageLabelKeys.totalAmount),
        totals.total,
      ),
      if (data.walletUsed > 0) ...[
        AppSpacing.h8,
        CheckoutBillRow(
          label: context.translate(LanguageLabelKeys.walletUsed),
          value: '-${_fmt(cartData, data.walletUsed)}',
          valueColor: context.cs.onSecondaryContainer,
        ),
        AppSpacing.h8,
        const Divider(height: 1, thickness: 0.5),
        AppSpacing.h8,
        _totalRow(
          context,
          context.translate(LanguageLabelKeys.payable),
          data.payable,
        ),
      ],
    ];
  }

  List<Widget> _buildSections(BuildContext context, _BillData data) {
    final cartData = widget.cartData;
    return [
      AppText(
        context.translate(LanguageLabelKeys.billDetails),
        style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      ClipRRect(
        borderRadius: AppRadius.r12,
        child: Container(
          width: double.infinity,
          decoration: AppDecorations.box(
            color: context.cs.surface,
            borderRadius: AppRadius.r12,
            border: Border.all(
              color: context.cs.outline.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.all(
                  ThemeConstants.paddingM,
                ),
                child: Column(
                  crossAxisAlignment: .start,
                  children: _buildCardRows(context, data),
                ),
              ),
              if (data.totals.saved > 0)
                SavedAmountBanner(
                  amountText: _fmt(cartData, data.totals.saved),
                ),
            ],
          ),
        ),
      ),
      if (data.totals.cashback > 0) ...[
        AppSpacing.h4,
        CashbackBanner(
          amountText:
              '${context.translate(LanguageLabelKeys.cashback)} ${_fmt(cartData, data.totals.cashback)}',
          subtitle: context.translate(LanguageLabelKeys.cashbackAfterDelivery),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final data = _computeBillData();
    final sections = _buildSections(context, data);

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingL,
        ThemeConstants.paddingL,
        ThemeConstants.paddingL,
        ThemeConstants.paddingL +
            context.keyboardInset +
            context.bottomSafePadding,
      ),
      child: SlideAnimationList(
        crossAxisAlignment: .start,
        spacing: ThemeConstants.spaceL,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: AppDecorations.dragHandle(color: context.cs.outline),
            ),
          ),
          ...sections,
        ],
      ),
    );
  }
}

class CheckoutBillRow extends StatelessWidget {
  const CheckoutBillRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.isRefundable,
    this.tooltipMessage,
    this.detailContentBuilder,
    this.suffixLabel,
    this.suffixTooltipMessage,
    this.suffixSheetTitle,
    this.suffixContentBuilder,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool? isRefundable;
  final String? tooltipMessage;

  /// Overrides the default plain-message tooltip body with structured
  /// content (e.g. tax breakdown rows) for the main [label] tooltip.
  final WidgetBuilder? detailContentBuilder;
  final String? suffixLabel;
  final String? suffixTooltipMessage;
  final String? suffixSheetTitle;
  final WidgetBuilder? suffixContentBuilder;

  @override
  Widget build(BuildContext context) {
    final labelStyle = context.tt.bodySmall?.copyWith(
      color: context.cs.onSurface.withValues(alpha: 0.7),
    );
    final refundableMessage = isRefundable != null
        ? context.translate(
            isRefundable!
                ? LanguageLabelKeys.refundable
                : LanguageLabelKeys.notRefundable,
          )
        : null;
    final combinedMessage = [?refundableMessage, ?tooltipMessage].join('\n');
    return Row(
      mainAxisAlignment: .spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: .min,
            children: [
              if (detailContentBuilder != null || combinedMessage.isNotEmpty)
                DashedUnderlineTooltip(
                  text: label,
                  message: combinedMessage,
                  contentBuilder: detailContentBuilder,
                  style: labelStyle,
                )
              else
                AppText(label, style: labelStyle),
              if (suffixLabel != null && suffixLabel!.isNotEmpty) ...[
                AppSpacing.w4,
                Flexible(
                  child:
                      suffixTooltipMessage != null &&
                          suffixTooltipMessage!.isNotEmpty
                      ? DashedUnderlineTooltip(
                          text: suffixLabel!,
                          message: suffixTooltipMessage!,
                          sheetTitle: suffixSheetTitle,
                          contentBuilder: suffixContentBuilder,
                          style: labelStyle?.copyWith(
                            fontSize: 11,
                            color: context.cs.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        )
                      : AppText(
                          suffixLabel!,
                          style: labelStyle?.copyWith(
                            fontSize: 11,
                            color: context.cs.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
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
          style: context.tt.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? context.cs.onSurface,
          ),
        ),
      ],
    );
  }
}
