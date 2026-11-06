import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import '../../../core/theme/app_radius.dart';
import '../../../commons/widgets/app_text.dart';
import '../../../core/localization/language_label_key.dart';
import '../../../utils/extensions/context_extensions.dart';
import '../../../utils/extensions/localization_extensions.dart';
import '../../../utils/extensions/size_extensions.dart';
import '../models/dashboard_model.dart';

List<Color> _sliceColors(BuildContext context) => [
  context.cs.secondaryContainer,
  context.cs.errorContainer,
  context.cs.tertiaryContainer,
  context.cs.tertiary,
  context.cs.primaryFixedDim,
  context.cs.onErrorContainer,
  context.cs.inversePrimary,
  context.cs.primary,
];

/// Donut chart for the return/request status breakdown. Tap a slice (or its
/// legend row) to show a tooltip with that status's name and count right on
/// the chart.
class ReturnRequestsPieChart extends StatefulWidget {
  final List<StatusBreakdown> breakdown;
  final int total;

  const ReturnRequestsPieChart({
    super.key,
    required this.breakdown,
    required this.total,
  });

  @override
  State<ReturnRequestsPieChart> createState() => _ReturnRequestsPieChartState();
}

class _ReturnRequestsPieChartState extends State<ReturnRequestsPieChart> {
  static const double _chartSize = 110;

  int? _touchedIndex;
  Offset? _touchPosition;

  void _select(int? index, [Offset? position]) {
    setState(() {
      _touchedIndex = index;
      _touchPosition = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.breakdown;
    final selected = _touchedIndex != null && _touchedIndex! < items.length
        ? items[_touchedIndex!]
        : null;

    return Row(
      crossAxisAlignment: .center,
      spacing: ThemeConstants.spaceL,
      children: [
        SizedBox(
          width: _chartSize,
          height: _chartSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                  sections: [
                    for (var i = 0; i < items.length; i++)
                      PieChartSectionData(
                        value: (items[i].count ?? 0) == 0
                            ? 0.001
                            : (items[i].count ?? 0).toDouble(),
                        color: _sliceColors(
                          context,
                        )[i % _sliceColors(context).length],
                        radius: _touchedIndex == i ? 26 : 20,
                        showTitle: false,
                      ),
                  ],
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      final index =
                          response?.touchedSection?.touchedSectionIndex;
                      if (!event.isInterestedForInteractions ||
                          index == null ||
                          index < 0) {
                        _select(null);
                        return;
                      }
                      _select(index, event.localPosition);
                    },
                  ),
                ),
              ),
              IgnorePointer(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppText(
                        '${widget.total}',
                        style: context.tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.cs.onSurface,
                        ),
                      ),
                      AppText(
                        context.translate(LanguageLabelKeys.total),
                        style: context.tt.labelSmall?.copyWith(
                          color: context.cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (selected != null && _touchPosition != null)
                Positioned(
                  left: (_touchPosition!.dx - 55).clamp(-30, _chartSize - 40),
                  top: (_touchPosition!.dy - 46).clamp(-40, _chartSize - 30),
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: ThemeConstants.paddingS,
                        vertical: 5,
                      ),
                      decoration: AppDecorations.card(
                        color: context.cs.inverseSurface,
                        borderRadius: AppRadius.r8,
                        boxShadow: [
                          BoxShadow(
                            color: context.cs.shadow,
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: .start,
                        children: [
                          AppText(
                            selected.name ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.tt.labelSmall?.copyWith(
                              color: context.cs.onInverseSurface,
                            ),
                          ),
                          AppText(
                            '${selected.count ?? 0}',
                            style: context.tt.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: context.cs.onInverseSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            spacing: ThemeConstants.spaceS,
            children: [
              for (var i = 0; i < items.length; i++)
                InkWell(
                  onTap: () => _select(_touchedIndex == i ? null : i),
                  child: Row(
                    spacing: ThemeConstants.spaceS,
                    children: [
                      Container(
                        width: context.screenWidth * 0.027,
                        height: context.screenWidth * 0.027,
                        decoration: AppDecorations.circle(
                          color: _sliceColors(
                            context,
                          )[i % _sliceColors(context).length],
                        ),
                      ),
                      Expanded(
                        child: AppText(
                          items[i].name ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.bodySmall?.copyWith(
                            color: context.cs.onSurfaceVariant,
                            fontWeight: _touchedIndex == i
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      AppText(
                        '${items[i].count ?? 0}',
                        style: context.tt.bodySmall?.copyWith(
                          color: context.cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
