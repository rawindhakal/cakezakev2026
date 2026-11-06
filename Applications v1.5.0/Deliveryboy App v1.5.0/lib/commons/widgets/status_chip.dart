import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Small rounded pill label used to display an order/request status.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color backgroundColor;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  factory StatusChip.fromReturnOrderStatus(
    BuildContext context,
    int? activeStatus, {
    String? orderStatusName,
  }) {
    return switch (activeStatus) {
      5 => StatusChip(
        label: orderStatusName ?? "", //'Out for Pickup',
        color: context.cs.errorContainer,
        backgroundColor: context.cs.errorContainer.withValues(alpha: 0.12),
      ),
      6 => StatusChip(
        label: orderStatusName ?? "", //'Received from Customer',
        color: context.cs.primaryFixedDim,
        backgroundColor: context.cs.primaryFixedDim.withValues(alpha: 0.12),
      ),
      7 => StatusChip(
        label: orderStatusName ?? "", //'Cancelled',
        color: context.cs.onErrorContainer,
        backgroundColor: context.cs.onErrorContainer.withValues(alpha: 0.12),
      ),
      8 => StatusChip(
        label: orderStatusName ?? "", //'Return to Seller',
        color: context.cs.onSecondaryContainer,
        backgroundColor: context.cs.onSecondaryContainer.withValues(
          alpha: 0.12,
        ),
      ),
      _ => StatusChip(
        label:
            orderStatusName ??
            context.translate(LanguageLabelKeys.statusUnknown),
        color: context.cs.onSurfaceVariant,
        backgroundColor: context.cs.surfaceContainerLowest,
      ),
    };
  }

  factory StatusChip.fromDynamicStatus(
    BuildContext context,
    String? activeStatus, {
    String? orderStatusName,
  }) {
    return switch (activeStatus) {
      '1' => StatusChip(
        label: orderStatusName ?? "", //'Payment Pending',
        color: context.cs.errorContainer,
        backgroundColor: context.cs.errorContainer.withValues(alpha: 0.12),
      ),
      '2' => StatusChip(
        label: orderStatusName ?? "", //'Received',
        color: context.cs.primaryFixedDim,
        backgroundColor: context.cs.primaryFixedDim.withValues(alpha: 0.12),
      ),
      '3' => StatusChip(
        label: orderStatusName ?? "", //'Processed',
        color: context.cs.inversePrimary,
        backgroundColor: context.cs.secondaryContainer.withValues(alpha: 0.12),
      ),
      '4' => StatusChip(
        label: orderStatusName ?? "", //'Shipped',
        color: context.cs.tertiaryContainer,
        backgroundColor: context.cs.tertiaryContainer.withValues(alpha: 0.12),
      ),
      '5' => StatusChip(
        label: orderStatusName ?? "", //'Out For Delivery',
        color: context.cs.inversePrimary,
        backgroundColor: context.cs.secondaryContainer.withValues(alpha: 0.12),
      ),
      '6' => StatusChip(
        label: orderStatusName ?? "", //'Delivered',
        color: context.cs.onSecondaryContainer,
        backgroundColor: context.cs.onSecondaryContainer.withValues(
          alpha: 0.12,
        ),
      ),
      '7' => StatusChip(
        label: orderStatusName ?? "", //'Cancelled',
        color: context.cs.onErrorContainer,
        backgroundColor: context.cs.onErrorContainer.withValues(alpha: 0.12),
      ),
      '8' => StatusChip(
        label: orderStatusName ?? "", //'Returned',
        color: context.cs.onSecondaryFixed,
        backgroundColor: context.cs.onSecondaryFixed.withValues(alpha: 0.12),
      ),
      _ => StatusChip(
        label:
            orderStatusName ??
            context.translate(LanguageLabelKeys.statusUnknown),
        color: context.cs.onSurfaceVariant,
        backgroundColor: context.cs.surfaceContainerLowest,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppText(
      label,
      style: context.tt.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}
