import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

class CashFlowComparisonChart extends StatelessWidget {
  const CashFlowComparisonChart({
    required this.income,
    required this.expense,
    required this.savings,
    super.key,
    this.height = 190,
  });

  final double income;
  final double expense;
  final double savings;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double maxValue = <double>[income.abs(), expense.abs(), savings.abs(), 1].reduce((double a, double b) => a > b ? a : b);
    final List<_CashMetric> metrics = <_CashMetric>[
      _CashMetric('Gelir', income, AppColors.sage),
      _CashMetric('Harcama', expense, AppColors.accent(theme.brightness)),
      _CashMetric('Kalan', savings, savings >= 0 ? AppColors.blueGray : AppColors.terracotta),
    ];

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: metrics.map((_CashMetric metric) {
          final double factor = maxValue <= 0 ? 0 : (metric.value.abs() / maxValue).clamp(0.0, 1.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      Formatters.money(metric.value),
                      maxLines: 1,
                      style: theme.textTheme.labelLarge?.copyWith(letterSpacing: -0.25),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 520),
                            curve: Curves.easeOutCubic,
                            width: 42,
                            height: factor <= 0 ? 4 : constraints.maxHeight * factor,
                            decoration: BoxDecoration(
                              color: metric.color.withValues(alpha: theme.brightness == Brightness.dark ? 0.78 : 0.82),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(metric.label, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _CashMetric {
  const _CashMetric(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}
