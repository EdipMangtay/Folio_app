import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/motion/folio_motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/analytics/analytics_engine.dart';

class SpendingChart extends StatelessWidget {
  const SpendingChart({
    required this.points,
    super.key,
    this.height = 210,
  });

  final List<DailySpendPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Brightness brightness = theme.brightness;
    final Color accent = AppColors.accent(brightness);
    final Color muted = AppColors.muted(brightness);

    if (points.isEmpty) {
      return _ChartEmpty(height: height, label: 'Gösterilecek harcama günü yok.');
    }

    final List<double> raw = points.map((DailySpendPoint e) => e.amount).toList(growable: false);
    final double peak = raw.fold<double>(0, (double a, double b) => b > a ? b : a);
    if (peak <= 0) {
      return _ChartEmpty(height: height, label: 'Bu dönemde henüz harcama yok.');
    }

    final List<double> trend = _movingAverage(raw);
    final double maxY = _niceMax(peak);
    final double interval = maxY / 3;
    final double average = raw.fold<double>(0, (double a, double b) => a + b) / raw.length;

    final List<FlSpot> rawSpots = <FlSpot>[
      for (int i = 0; i < raw.length; i++) FlSpot(i.toDouble(), raw[i]),
    ];
    final List<FlSpot> trendSpots = <FlSpot>[
      for (int i = 0; i < trend.length; i++) FlSpot(i.toDouble(), trend[i]),
    ];

    final Widget chart = LineChart(
      LineChartData(
        minX: 0,
        maxX: math.max(1, points.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (double value) => FlLine(
            color: theme.dividerColor.withValues(alpha: 0.60),
            strokeWidth: 0.65,
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: <HorizontalLine>[
            HorizontalLine(
              y: average.clamp(0, maxY),
              color: AppColors.tertiary(brightness).withValues(alpha: 0.45),
              strokeWidth: 0.8,
              dashArray: const <int>[5, 5],
            ),
          ],
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: interval,
              getTitlesWidget: (double value, TitleMeta meta) {
                if ((value - meta.max).abs() < 0.01) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    _compact(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.tertiary(brightness),
                      fontSize: 9.5,
                      height: 1,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int index = value.round();
                if (!_showBottomLabel(index, points.length)) return const SizedBox.shrink();
                final int safeIndex = index.clamp(0, points.length - 1);
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    Formatters.shortDate(points[safeIndex].date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.tertiary(brightness),
                      fontSize: 9.5,
                      height: 1,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchSpotThreshold: 28,
          getTouchedSpotIndicator: (LineChartBarData bar, List<int> indexes) {
            if (bar.barWidth < 2) {
              return indexes
                  .map((_) => const TouchedSpotIndicatorData(FlLine(strokeWidth: 0), FlDotData(show: false)))
                  .toList(growable: false);
            }
            return indexes.map((int index) {
              return TouchedSpotIndicatorData(
                FlLine(color: accent.withValues(alpha: 0.22), strokeWidth: 1),
                FlDotData(
                  show: true,
                  getDotPainter: (FlSpot spot, double percent, LineChartBarData data, int i) {
                    return FlDotCirclePainter(
                      radius: 4.5,
                      color: AppColors.elevated(brightness),
                      strokeWidth: 2.2,
                      strokeColor: accent,
                    );
                  },
                ),
              );
            }).toList(growable: false);
          },
          touchTooltipData: LineTouchTooltipData(
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            tooltipBorderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            tooltipMargin: 12,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (LineBarSpot spot) => AppColors.ink(brightness),
            getTooltipItems: (List<LineBarSpot> touched) {
              return touched.map((LineBarSpot spot) {
                if (spot.barIndex == 0) return null;
                final int index = spot.x.round().clamp(0, points.length - 1);
                return LineTooltipItem(
                  '${Formatters.money(points[index].amount)}\n${Formatters.shortDate(points[index].date)}',
                  TextStyle(
                    color: AppColors.canvas(brightness),
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.15,
                  ),
                );
              }).toList(growable: false);
            },
          ),
        ),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: rawSpots,
            isCurved: false,
            color: muted.withValues(alpha: brightness == Brightness.dark ? 0.20 : 0.16),
            barWidth: 1.0,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
          LineChartBarData(
            spots: trendSpots,
            isCurved: true,
            curveSmoothness: raw.length < 4 ? 0.08 : 0.28,
            preventCurveOverShooting: true,
            color: accent,
            barWidth: 2.5,
            isStrokeCapRound: true,
            isStrokeJoinRound: true,
            dotData: FlDotData(
              show: raw.length <= 8,
              getDotPainter: (FlSpot spot, double percent, LineChartBarData bar, int index) {
                return FlDotCirclePainter(
                  radius: 3.2,
                  color: AppColors.elevated(brightness),
                  strokeWidth: 1.8,
                  strokeColor: accent,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  accent.withValues(alpha: brightness == Brightness.dark ? 0.15 : 0.10),
                  accent.withValues(alpha: 0.025),
                  Colors.transparent,
                ],
                stops: const <double>[0, 0.62, 1],
              ),
            ),
          ),
        ],
      ),
      duration: FolioMotion.reduce(context) ? Duration.zero : FolioMotion.page,
      curve: FolioMotion.enter,
    );

    return SizedBox(
      height: height,
      child: ClipRect(child: chart),
    );
  }

  bool _showBottomLabel(int index, int length) {
    if (length <= 1) return index == 0;
    if (length <= 7) return index == 0 || index == length - 1 || index == length ~/ 2;
    return index == 0 || index == length ~/ 2 || index == length - 1;
  }

  List<double> _movingAverage(List<double> values) {
    if (values.length < 5) return values;
    final int radius = values.length >= 16 ? 2 : 1;
    return List<double>.generate(values.length, (int index) {
      double total = 0;
      double weight = 0;
      for (int offset = -radius; offset <= radius; offset++) {
        final int i = (index + offset).clamp(0, values.length - 1);
        final double w = offset == 0 ? 3 : (offset.abs() == 1 ? 2 : 1);
        total += values[i] * w;
        weight += w;
      }
      return total / weight;
    }, growable: false);
  }

  double _niceMax(double value) {
    final double padded = value * 1.18;
    if (padded <= 10) return 10;
    final double magnitude = math.pow(10, (math.log(padded) / math.ln10).floor()).toDouble();
    final double residual = padded / magnitude;
    final double nice = residual <= 1
        ? 1
        : residual <= 2
            ? 2
            : residual <= 5
                ? 5
                : 10;
    return nice * magnitude;
  }

  String _compact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}m';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}k';
    return value.toStringAsFixed(0);
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.height, required this.label});

  final double height;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}
