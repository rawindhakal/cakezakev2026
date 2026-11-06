import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';
import '../../../commons/widgets/app_text.dart';
import '../../../utils/extensions/context_extensions.dart';

/// Name-above-count column used for compact stat pairs (e.g. completed/pending,
/// orders breakdown).
class DashboardStatColumn extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;
  final bool alignCenter;
  final bool center;

  const DashboardStatColumn({
    super.key,
    required this.label,
    required this.value,
    this.alignEnd = false,
    this.alignCenter = false,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueAlign = center || alignCenter
        ? TextAlign.center
        : (alignEnd ? TextAlign.end : TextAlign.start);

    return Column(
      crossAxisAlignment: center ? .center : (alignEnd ? .end : .start),
      spacing: ThemeConstants.spaceXS,
      children: [
        AppText(
          label,
          textAlign: center ? TextAlign.center : null,
          style: context.tt.bodyMedium?.copyWith(
            color: context.cs.onSurfaceVariant,
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: AppText(
            value,
            textAlign: valueAlign,
            style: context.tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: context.cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
