import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import '../../../commons/widgets/app_text.dart';
import '../../../utils/extensions/context_extensions.dart';
import '../../../utils/extensions/size_extensions.dart';

/// Half-donut chart for the Active Orders status breakdown (Out for Pickup,
/// Delivered, Picked Up, ...). Primary color at varying shades — no
/// multi-color palette — with a legend row below.
class ActiveStatusChart extends StatefulWidget {
  final List<MapEntry<String, int>> items;

  const ActiveStatusChart({super.key, required this.items});

  @override
  State<ActiveStatusChart> createState() => _ActiveStatusChartState();
}

class _ActiveStatusChartState extends State<ActiveStatusChart> {
  static const double _chartSize = 140;
  static const List<double> _shades = [1.0, 0.65, 0.42, 0.26, 0.16];

  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final total = items.fold<int>(0, (acc, e) => acc + e.value);
    final safeTotal = total == 0 ? 1 : total;
    final primary = context.cs.primary;

    return Row(
      crossAxisAlignment: .center,
      spacing: ThemeConstants.spaceL,
      children: [
        SizedBox(
          width: _chartSize,
          height: _chartSize / 2,
          child: ClipRect(
            child: OverflowBox(
              maxHeight: _chartSize,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: _chartSize,
                height: _chartSize,
                child: PieChart(
                  PieChartData(
                    startDegreeOffset: -180,
                    sectionsSpace: 2,
                    centerSpaceRadius: 34,
                    sections: [
                      for (var i = 0; i < items.length; i++)
                        PieChartSectionData(
                          value: items[i].value == 0
                              ? 0.001
                              : items[i].value.toDouble(),
                          color: primary.withValues(
                            alpha: _shades[i % _shades.length],
                          ),
                          radius: _touchedIndex == i ? 26 : 22,
                          showTitle: false,
                        ),
                      PieChartSectionData(
                        value: safeTotal.toDouble(),
                        color: Colors.transparent,
                        radius: 22,
                        showTitle: false,
                      ),
                    ],
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        final index =
                            response?.touchedSection?.touchedSectionIndex;
                        if (!event.isInterestedForInteractions ||
                            index == null ||
                            index < 0 ||
                            index >= items.length) {
                          setState(() => _touchedIndex = null);
                          return;
                        }
                        setState(
                          () => _touchedIndex = index == _touchedIndex
                              ? null
                              : index,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            spacing: ThemeConstants.spaceS,
            children: [
              for (var i = 0; i < items.length; i++)
                InkWell(
                  onTap: () => setState(
                    () => _touchedIndex = _touchedIndex == i ? null : i,
                  ),
                  child: Row(
                    spacing: ThemeConstants.spaceS,
                    children: [
                      Container(
                        width: context.screenWidth * 0.027,
                        height: context.screenWidth * 0.027,
                        decoration: AppDecorations.circle(
                          color: primary.withValues(
                            alpha: _shades[i % _shades.length],
                          ),
                        ),
                      ),
                      Expanded(
                        child: AppText(
                          items[i].key,
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
                        '${items[i].value}',
                        style: context.tt.bodySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.cs.onSurface,
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
