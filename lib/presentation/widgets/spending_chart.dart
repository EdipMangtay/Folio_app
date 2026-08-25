import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/motion/folio_motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/analytics/analytics_engine.dart';

/// One column per day, at the amount actually spent that day.
///
/// This used to draw a weighted moving average as the prominent line, with the
/// real figures behind it at 16% opacity. Daily spending is not a continuous
/// signal with noise to remove — it is a set of discrete events — so smoothing
/// it invented money on days nothing happened (933 ₺ on a day with no
/// transactions, a 12.000 ₺ rent payment flattened to 4.120 ₺) and the curve
/// read as unrelated to the wallet. Columns state the record and nothing else.
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

    if (points.isEmpty) {
      return _ChartEmpty(height: height, label: 'Gösterilecek harcama günü yok.');
    }

    final List<double> amounts = points.map((DailySpendPoint e) => e.amount).toList(growable: false);
    final double peak = amounts.fold<double>(0, (double a, double b) => b > a ? b : a);
    if (peak <= 0) {
      return _ChartEmpty(height: height, label: 'Bu dönemde henüz harcama yok.');
    }

    final _Scale scale = _Scale.forPeak(peak);
    final double average =
        amounts.fold<double>(0, (double a, double b) => a + b) / amounts.length;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Thin marks: each column takes a little over half its slot, so the
          // gaps stay legible at 31 days without a border around every bar.
          const double axisWidth = 40;
          final double slot = (constraints.maxWidth - axisWidth) / points.length;
          final double barWidth = (slot * 0.58).clamp(2.0, 18.0);

          return BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              minY: 0,
              maxY: scale.max,
              groupsSpace: 0,
              barGroups: <BarChartGroupData>[
                for (int i = 0; i < points.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: <BarChartRodData>[
                      BarChartRodData(
                        toY: amounts[i],
                        width: barWidth,
                        color: accent,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(math.min(3, barWidth / 2)),
                        ),
                      ),
                    ],
                  ),
              ],
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: scale.step,
                getDrawingHorizontalLine: (double value) => FlLine(
                  color: theme.dividerColor.withValues(alpha: 0.60),
                  strokeWidth: 0.65,
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: <HorizontalLine>[
                  HorizontalLine(
                    y: average.clamp(0, scale.max),
                    color: AppColors.tertiary(brightness).withValues(alpha: 0.55),
                    strokeWidth: 0.9,
                    // Dashed reads as a threshold, which is what an average is.
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
                    reservedSize: axisWidth,
                    interval: scale.step,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      if ((value - meta.max).abs() < 0.01) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          _tick(value, scale),
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
                      if (!_showBottomLabel(index, points.length)) {
                        return const SizedBox.shrink();
                      }
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
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  tooltipBorderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  tooltipMargin: 12,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (BarChartGroupData group) => AppColors.ink(brightness),
                  getTooltipItem: (
                    BarChartGroupData group,
                    int groupIndex,
                    BarChartRodData rod,
                    int rodIndex,
                  ) {
                    final int index = group.x.clamp(0, points.length - 1);
                    return BarTooltipItem(
                      // The number named here is the one the column is drawn at.
                      '${Formatters.money(points[index].amount)}\n'
                      '${Formatters.fullDate(points[index].date)}',
                      TextStyle(
                        color: AppColors.canvas(brightness),
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.15,
                      ),
                    );
                  },
                ),
              ),
            ),
            duration: FolioMotion.reduce(context) ? Duration.zero : FolioMotion.page,
            curve: FolioMotion.enter,
          );
        },
      ),
    );
  }

  bool _showBottomLabel(int index, int length) {
    if (length <= 1) return index == 0;
    return index == 0 || index == length ~/ 2 || index == length - 1;
  }

  /// Formats one axis tick.
  ///
  /// Every tick is a multiple of the same step, so the decision is made once
  /// from the scale rather than per value — otherwise `5.0k` ends up sitting
  /// above `10k` and the axis reads as two scales. Decimals use a comma, like
  /// the rest of the app.
  String _tick(double value, _Scale scale) {
    if (value == 0) return '0';

    if (scale.max >= 1000000) {
      final bool whole = scale.step % 1000000 == 0;
      return '${_decimal(value / 1000000, whole ? 0 : 1)}m';
    }
    if (scale.max >= 10000) {
      final bool whole = scale.step % 1000 == 0;
      return '${_decimal(value / 1000, whole ? 0 : 1)}k';
    }
    return _grouped(value);
  }

  String _decimal(double value, int digits) =>
      value.toStringAsFixed(digits).replaceAll('.', ',');

  /// `1500` -> `1.500`, matching the thousands separator used for money.
  String _grouped(double value) {
    final String whole = value.toStringAsFixed(0);
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      final int remaining = whole.length - i;
      buffer.write(whole[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
    }
    return buffer.toString();
  }
}

/// A vertical scale whose gridlines land on round numbers without leaving the
/// tallest column stranded near the floor.
class _Scale {
  const _Scale({required this.max, required this.step});

  final double max;
  final double step;

  static _Scale forPeak(double peak) {
    if (peak <= 0) return const _Scale(max: 10, step: 5);

    // A little headroom so the tallest column does not touch the top edge.
    final double target = peak * 1.08;
    final double rawStep = target / 3;
    final double magnitude =
        math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
    final double residual = rawStep / magnitude;
    final double factor = residual <= 1
        ? 1
        : residual <= 1.5
            ? 1.5
            : residual <= 2
                ? 2
                : residual <= 2.5
                    ? 2.5
                    : residual <= 3
                        ? 3
                        : residual <= 4
                            ? 4
                            : residual <= 5
                                ? 5
                                : residual <= 7.5
                                    ? 7.5
                                    : 10;
    final double step = factor * magnitude;
    final int divisions = math.max(3, (target / step).ceil());
    return _Scale(max: step * divisions, step: step);
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
