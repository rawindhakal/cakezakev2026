import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import '../../../utils/extensions/context_extensions.dart';

/// A single row in a [DashboardListCard] — label left, bold value right,
/// optionally with a progress bar underneath when [percent] is set.
class DashboardListRow {
  final String label;
  final String value;
  final double? percent;

  const DashboardListRow({
    required this.label,
    required this.value,
    this.percent,
  });
}

/// Title (rendered above, outside the card) + white card listing label/value
/// rows, used for the dashboard's performance/status/orders/returns summaries.
class DashboardListCard extends StatelessWidget {
  final String? title;
  final List<DashboardListRow> rows;

  const DashboardListCard({super.key, this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      spacing: ThemeConstants.spaceM,
      children: [
        if (title != null && title!.isNotEmpty)
          AppText(
            title!,
            style: context.tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.cs.onSurface,
            ),
          ),
        Container(
          padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
          decoration: AppDecorations.card(
            color: context.cs.surface,
            borderRadius: AppRadius.r16,
            boxShadow: [
              BoxShadow(
                color: context.cs.shadow,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(vertical: 3),
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: ThemeConstants.spaceS,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              rows[i].label,
                              style: context.tt.bodyMedium?.copyWith(
                                color: context.cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          AppText(
                            rows[i].value,
                            style: context.tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: context.cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                      if (rows[i].percent != null)
                        ClipRRect(
                          borderRadius: AppRadius.r20,
                          child: LinearProgressIndicator(
                            value: rows[i].percent!.clamp(0, 1),
                            minHeight: 6,
                            backgroundColor: context.cs.primary.withValues(
                              alpha: 0.12,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              context.cs.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
