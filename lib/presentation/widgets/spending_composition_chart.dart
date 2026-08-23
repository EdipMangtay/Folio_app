import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';

/// A classic 100% allocation chart. Easier to read than a donut on a phone and
/// more consistent with Folio's calm finance aesthetic.
class SpendingCompositionChart extends StatelessWidget {
  const SpendingCompositionChart({
    required this.categoryTotals,
    required this.total,
    super.key,
    this.maxSegments = 5,
  });

  final Map<String, double> categoryTotals;
  final double total;
  final int maxSegments;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<MapEntry<String, double>> entries = categoryTotals.entries.take(maxSegments).toList(growable: false);
    if (entries.isEmpty || total <= 0) return const SizedBox.shrink();

    final double shownTotal = entries.fold<double>(0, (double sum, MapEntry<String, double> item) => sum + item.value);
    final double remainder = (total - shownTotal).clamp(0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Toplam harcama', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      Formatters.money(total),
                      style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: -0.65),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('${entries.length}${remainder > 0.5 ? '+' : ''} kategori', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: SizedBox(
            height: 18,
            child: Row(
              children: <Widget>[
                for (final MapEntry<String, double> entry in entries)
                  Expanded(
                    flex: _flex(entry.value / total),
                    child: ColoredBox(color: AppColors.category(entry.key)),
                  ),
                if (remainder > 0)
                  Expanded(
                    flex: _flex(remainder / total),
                    child: ColoredBox(color: AppColors.slate.withValues(alpha: theme.brightness == Brightness.dark ? 0.55 : 0.42)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        for (int i = 0; i < entries.length; i++) ...<Widget>[
          _LegendRow(
            entry: entries[i],
            share: entries[i].value / total,
          ),
          if (i != entries.length - 1) const SizedBox(height: 10),
        ],
        if (remainder > 0.5) ...<Widget>[
          const SizedBox(height: 10),
          _LegendRow(
            entry: MapEntry<String, double>('Diğer', remainder),
            share: remainder / total,
          ),
        ],
      ],
    );
  }

  int _flex(double value) => (value.clamp(0.01, 1.0) * 1000).round();
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.entry, required this.share});

  final MapEntry<String, double> entry;
  final double share;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = AppColors.category(entry.key);
    return Row(
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            entry.key,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(share * 100).round()}%',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted(theme.brightness)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            Formatters.money(entry.value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: theme.textTheme.titleSmall?.copyWith(letterSpacing: -0.25),
          ),
        ),
      ],
    );
  }
}
