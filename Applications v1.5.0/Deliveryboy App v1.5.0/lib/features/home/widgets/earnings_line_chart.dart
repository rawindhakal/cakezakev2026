import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../utils/extensions/context_extensions.dart';

/// Line chart plotting earnings over time, built with fl_chart.
class EarningsLineChart extends StatelessWidget {
  final List<int> values;
  final double height;

  const EarningsLineChart({super.key, required this.values, this.height = 140});

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty
        ? 0
        : values.reduce((a, b) => a > b ? a : b);
    final niceMax = maxValue <= 0 ? 10 : ((maxValue * 1.2) / 5).ceil() * 5;
    final interval = niceMax / 4;
    final lineColor = context.cs.primary;

    if (values.length < 2) {
      return SizedBox(height: height);
    }

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: niceMax.toDouble(),
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: interval == 0 ? 1 : interval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: context.cs.outlineVariant.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: interval == 0 ? 1 : interval,
                getTitlesWidget: (value, meta) => Text(
                  value.round().toString(),
                  style: context.tt.labelSmall?.copyWith(
                    color: context.cs.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => context.cs.inverseSurface,
              getTooltipItems: (spots) => spots
                  .map(
                    (s) => LineTooltipItem(
                      s.y.round().toString(),
                      context.tt.labelMedium!.copyWith(
                        color: context.cs.onInverseSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i].toDouble()),
              ],
              isCurved: false,
              color: lineColor,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, barData) => spot.x == values.length - 1,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                      radius: 4,
                      color: lineColor,
                      strokeColor: Colors.white,
                      strokeWidth: 1.5,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    lineColor.withValues(alpha: 0.28),
                    lineColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
