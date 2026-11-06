import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/features/orders/models/additional_charges_model.dart';
import 'package:deliveryboy/features/orders/models/delivery_charges_model.dart';
import 'package:deliveryboy/features/orders/models/ecommerce_order_model.dart';
import 'package:deliveryboy/features/orders/models/order_detail_model.dart';
import 'package:deliveryboy/features/orders/models/order_status.dart';
import 'package:deliveryboy/features/orders/models/return_order_model.dart';
import 'package:deliveryboy/features/orders/models/surge_charges_model.dart';
import 'package:deliveryboy/features/orders/models/tax_charges_model.dart';
import 'package:deliveryboy/features/orders/utils/payment_breakdown.dart';
import 'package:deliveryboy/commons/widgets/tax_breakdown_sheet.dart';
import 'package:deliveryboy/features/orders/widgets/bill_row.dart';
import 'package:deliveryboy/features/orders/widgets/payment_summary_section.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/string_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// The 3 screens whose bill-summary card this widget renders. Pass [type]
/// plus the matching model (`order`+`detail` for [BillOrderType.order],
/// `ecommerceOrder` for [BillOrderType.ecommerce], `returnDetail` for
/// [BillOrderType.returnOrder]) — everything else (rows, spacing,
/// container, payment breakdown) is built here in one place.
enum BillOrderType { order, ecommerce, returnOrder }

class BillSummaryCard extends StatelessWidget {
  final BillOrderType type;
  final String symbol;
  final Order? order;
  final OrderDetailData? detail;
  final EcommerceOrderDataModel? ecommerceOrder;
  final ReturnRequestData? returnDetail;

  const BillSummaryCard({
    super.key,
    required this.type,
    required this.symbol,
    this.order,
    this.detail,
    this.ecommerceOrder,
    this.returnDetail,
  });

  /// Decimal digits to show for amounts, from the order's own API response
  /// (`decimal_point`) — falls back to 2 when the backend omits it.
  int get _decimals {
    final raw = switch (type) {
      BillOrderType.order => order?.decimalPoint,
      BillOrderType.ecommerce => ecommerceOrder?.decimalPoint,
      BillOrderType.returnOrder => returnDetail?.returnItem?.decimalPoint,
    };
    return int.tryParse(raw ?? '') ?? 2;
  }

  String _fmt(num amount) {
    var value = amount.toStringAsFixed(_decimals);
    if (value.contains('.')) {
      value = value.replaceFirst(RegExp(r'\.?0+$'), '');
    }
    return '$symbol$value';
  }

  /// Subtotal row — tapping the "(Incl. Tax)" suffix opens the full tax
  /// breakdown sheet when the order has one.
  BillRow _subtotalRow(
    BuildContext context, {
    required num subtotal,
    required List<TaxCharges>? taxBreakdown,
  }) {
    final taxes = taxBreakdown ?? const <TaxCharges>[];
    final hasTax = taxes.any((t) => t.amount != null && t.amount != 0);
    return BillRow(
      label: context.translate(LanguageLabelKeys.subTotal),
      value: _fmt(subtotal),
      suffixLabel: hasTax ? context.translate(LanguageLabelKeys.inclTax) : null,
      suffixTooltipMessage: hasTax
          ? taxBreakdownMessage(context, taxes, _fmt)
          : null,
      suffixSheetTitle: hasTax
          ? context.translate(LanguageLabelKeys.taxBreakdown)
          : null,
      suffixContentBuilder: hasTax
          ? (sheetContext) => taxBreakdownSheet(sheetContext, taxes, _fmt)
          : null,
    );
  }

  /// Delivery-charge row — tapping the label opens a base/tax/total
  /// breakdown sheet when the charge carries tax detail.
  BillRow _deliveryChargeRow(BuildContext context, DeliveryCharges? dc) {
    final hasTaxDetail = hasChargeTaxDetail(
      taxName: dc?.taxName,
      taxAmount: dc?.taxAmount,
      taxableAmount: dc?.taxableAmount,
      taxRate: dc?.taxRate,
    );
    final label = context.translate(LanguageLabelKeys.deliveryCharge);
    return BillRow(
      label: label,
      value: _fmt(dc?.amount ?? 0),
      detailContentBuilder: hasTaxDetail
          ? (sheetContext) => additionalChargeDetailSheet(
              sheetContext,
              _fmt,
              label: label,
              totalAmount: dc?.amount ?? 0,
              taxName: dc?.taxName,
              taxAmount: dc?.taxAmount,
              taxRate: dc?.taxRate,
            )
          : null,
    );
  }

  /// Additional/surge charge rows — each tappable when it carries tax
  /// detail (base/tax/total sheet) or a refundable flag (plain note).
  List<Widget> _chargeRows(
    BuildContext context, {
    List<AdditionalCharges>? additional,
    List<SurgeCharges>? surge,
  }) {
    Widget spaced(Widget child) => Padding(
      padding: const EdgeInsetsDirectional.only(top: ThemeConstants.paddingS),
      child: child,
    );

    return [
      ...(additional ?? []).map((c) {
        final hasTaxDetail = hasChargeTaxDetail(
          taxName: c.taxName,
          taxAmount: c.taxAmount,
          taxableAmount: c.taxableAmount,
          taxRate: c.taxRate,
        );
        final label = c.name.isNotNullOrEmpty
            ? c.name!
            : context.translate(LanguageLabelKeys.additionalCharges);
        return spaced(
          BillRow(
            label: label,
            value: _fmt(c.amount ?? 0),
            isRefundable: hasTaxDetail ? null : c.isRefundable,
            detailContentBuilder: hasTaxDetail
                ? (sheetContext) => additionalChargeDetailSheet(
                    sheetContext,
                    _fmt,
                    label: label,
                    totalAmount: c.amount ?? 0,
                    isRefundable: c.isRefundable,
                    taxName: c.taxName,
                    taxAmount: c.taxAmount,
                    taxRate: c.taxRate,
                  )
                : null,
          ),
        );
      }),
      ...(surge ?? []).map((c) {
        final hasTaxDetail = hasChargeTaxDetail(
          taxName: c.taxName,
          taxAmount: c.taxAmount,
          taxableAmount: c.taxableAmount,
          taxRate: c.taxRate,
        );
        final label = c.label.isNotNullOrEmpty
            ? c.label!
            : context.translate(LanguageLabelKeys.surgeCharges);
        return spaced(
          BillRow(
            label: label,
            value: _fmt(c.charge ?? 0),
            isRefundable: hasTaxDetail ? null : c.isRefundable,
            detailContentBuilder: hasTaxDetail
                ? (sheetContext) => additionalChargeDetailSheet(
                    sheetContext,
                    _fmt,
                    label: label,
                    totalAmount: c.charge ?? 0,
                    isRefundable: c.isRefundable,
                    taxName: c.taxName,
                    taxAmount: c.taxAmount,
                    taxRate: c.taxRate,
                  )
                : null,
          ),
        );
      }),
    ];
  }

  List<Widget> _orderRows(BuildContext context) {
    return [
      _subtotalRow(
        context,
        subtotal: order?.total ?? 0,
        taxBreakdown: order?.taxBreakdown,
      ),
      AppSpacing.h8,
      _deliveryChargeRow(context, detail!.order?.deliveryCharges),
      if ((order?.discount ?? 0) != 0) ...[
        AppSpacing.h8,
        BillRow(
          label: context.translate(LanguageLabelKeys.discount),
          value: '-${_fmt(order?.discount ?? 0)}',
          isDiscount: true,
        ),
      ],
      if ((order?.promoDiscount ?? 0) != 0) ...[
        AppSpacing.h8,
        BillRow(
          label: context.translate(LanguageLabelKeys.promoDiscount),
          value: '-${_fmt(order?.promoDiscount ?? 0)}',
          isDiscount: true,
        ),
      ],
      ..._chargeRows(
        context,
        additional: detail!.order?.additionalCharges,
        surge: detail!.order?.surgeCharges,
      ),
    ];
  }

  List<Widget> _ecommerceRows(BuildContext context) {
    final o = ecommerceOrder!;
    return [
      _subtotalRow(
        context,
        subtotal: o.subTotal ?? 0,
        taxBreakdown: o.taxBreakdown,
      ),
      AppSpacing.h8,
      _deliveryChargeRow(context, o.deliveryCharges),
      ..._chargeRows(
        context,
        additional: o.additionalCharges,
        surge: o.surgeCharges,
      ),
      if ((o.promoDiscount ?? 0) > 0) ...[
        AppSpacing.h8,
        BillRow(
          label: context.translate(LanguageLabelKeys.promoDiscount),
          value: '-${_fmt(o.promoDiscount ?? 0)}',
          isDiscount: true,
        ),
      ],
    ];
  }

  List<Widget> _returnRows(BuildContext context) {
    final item = returnDetail!.returnItem;
    return [
      _subtotalRow(
        context,
        subtotal: item?.subTotal ?? 0,
        taxBreakdown: item?.taxBreakdown,
      ),
      ..._chargeRows(
        context,
        additional: item?.additionalCharges,
        surge: item?.surgeCharges,
      ),
      if ((item?.promoDiscount ?? 0) != 0) ...[
        AppSpacing.h8,
        BillRow(
          label: item?.promoCode.isNotNullOrEmpty ?? false
              ? '${context.translate(LanguageLabelKeys.promoDiscount)} (${item!.promoCode})'
              : context.translate(LanguageLabelKeys.promoDiscount),
          value: '-${_fmt(item!.promoDiscount ?? 0)}',
          isDiscount: true,
        ),
      ],
    ];
  }

  PaymentBreakdown _breakdown() {
    switch (type) {
      case BillOrderType.order:
        return PaymentBreakdown.compute(
          walletAmount: order?.walletBalance,
          remainingAmount: order?.finalTotal,
          paymentMethod: order?.paymentMethod,
          isDelivered: order?.activeStatus == OrderStatus.delivered.id,
          refundAmount: order?.refundAmount,
        );
      case BillOrderType.ecommerce:
        final o = ecommerceOrder!;
        return PaymentBreakdown.compute(
          walletAmount: o.walletBalance,
          remainingAmount: o.finalTotal,
          paymentMethod: o.paymentMethod,
          isDelivered: o.activeStatus == OrderStatus.delivered.id,
          refundAmount: o.refundAmount,
        );
      case BillOrderType.returnOrder:
        final item = returnDetail!.returnItem;
        return PaymentBreakdown.compute(
          walletAmount: item?.walletBalance,
          remainingAmount: item?.finalTotal,
          paymentMethod: item?.paymentMethod ?? returnDetail!.paymentMethod,
          isDelivered:
              returnDetail!.returnStatusEnum ==
              ReturnOrderStatus.receivedFromCustomer,
          refundAmount: item?.refundAmount,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = switch (type) {
      BillOrderType.order => _orderRows(context),
      BillOrderType.ecommerce => _ecommerceRows(context),
      BillOrderType.returnOrder => _returnRows(context),
    };
    final breakdown = _breakdown();
    final showDivider = type == BillOrderType.order;

    final title = AppText(
      context.translate(LanguageLabelKeys.billSummary),
      style: context.tt.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: context.cs.onSurface,
      ),
    );
    final decoration = AppDecorations.shadowedCard(
      color: Theme.of(context).cardColor,
      shadowColor: context.cs.shadow,
    );

    if (showDivider) {
      return Container(
        margin: const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingL),
        decoration: decoration,
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, ThemeConstants.paddingM),
              child: title,
            ),
            Divider(height: 1, color: context.cs.outlineVariant),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, ThemeConstants.paddingM, 14, 14),
              child: Column(
                children: [
                  ...rows,
                  AppSpacing.h8,
                  PaymentSummarySection(symbol: symbol, breakdown: breakdown),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          title,
          AppSpacing.h12,
          ...rows,
          AppSpacing.h8,
          PaymentSummarySection(symbol: symbol, breakdown: breakdown),
        ],
      ),
    );
  }
}
