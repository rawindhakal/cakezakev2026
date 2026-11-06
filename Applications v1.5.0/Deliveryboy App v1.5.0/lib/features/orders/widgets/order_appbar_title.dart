import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Two-line CustomAppBar title used across order-detail screens: status name
/// on top, id line (order/item/return id) below — replaces the standalone
/// order-summary card that used to repeat the same info in the body.
class OrderAppBarTitle extends StatelessWidget {
  final String statusLabel;
  final String idLine;

  const OrderAppBarTitle({
    super.key,
    required this.statusLabel,
    required this.idLine,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      children: [
        AppText(
          statusLabel,
          style: context.tt.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.cs.onSurface,
          ),
        ),
        AppText(
          idLine,
          style: context.tt.bodySmall?.copyWith(
            color: context.cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
