import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';

class CategorySpendRow extends StatelessWidget {
  const CategorySpendRow({
    required this.category,
    required this.amount,
    required this.share,
    super.key,
    this.onTap,
    this.rank,
  });

  final String category;
  final double amount;
  final double share;
  final VoidCallback? onTap;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = AppColors.category(category);
    final Color muted = AppColors.muted(theme.brightness);

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (rank != null)
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.soft(theme.brightness),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$rank',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.tertiary(theme.brightness),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(category, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '%${(share * 100).toStringAsFixed(0)} pay',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    Formatters.money(amount),
                    style: theme.textTheme.titleMedium?.copyWith(
                      letterSpacing: -0.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(share * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            child: SizedBox(
              height: 7,
              child: Stack(
                children: <Widget>[
                  ColoredBox(
                    color: color.withValues(alpha: theme.brightness == Brightness.dark ? 0.16 : 0.10),
                    child: const SizedBox.expand(),
                  ),
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    widthFactor: share.clamp(0.0, 1.0).toDouble(),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: <Color>[
                            color.withValues(alpha: 0.55),
                            color,
                          ],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: color.withValues(alpha: 0.22),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
