import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/analytics/month_scope.dart';
import '../../domain/models/transaction_record.dart';
import '../../state/month_scope_controller.dart';
import 'premium_surface.dart';

/// Explains a period that reports zero while the wallet is not empty.
///
/// Without it the page just shows 0 ₺ and the figures look lost, which is
/// exactly how an imported statement reads when its period has closed.
/// Renders nothing when the selected month holds data, or when the wallet is
/// empty and the screen's own empty state has it covered.
class EmptyMonthNotice extends ConsumerWidget {
  const EmptyMonthNotice({
    required this.month,
    required this.transactions,
    super.key,
  });

  final DateTime month;
  final List<TransactionRecord> transactions;

  /// Whether the notice would render anything, so callers can skip the gap
  /// they would otherwise put above it.
  static bool isNeeded(List<TransactionRecord> transactions, DateTime month) {
    if (transactions.isEmpty) return false;
    return !transactions.any(
      (TransactionRecord item) => item.date.year == month.year && item.date.month == month.month,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isNeeded(transactions, month)) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);

    final Map<DateTime, int> counts = <DateTime, int>{};
    for (final TransactionRecord item in transactions) {
      counts.update(MonthScope.monthOf(item.date), (int value) => value + 1, ifAbsent: () => 1);
    }

    DateTime? nearest;
    for (final DateTime candidate in counts.keys) {
      if (nearest == null || candidate.isAfter(nearest)) nearest = candidate;
    }
    if (nearest == null) return const SizedBox.shrink();

    final DateTime target = nearest;
    return PremiumSurface(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      radius: AppSpacing.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.event_busy_outlined, size: 18, color: AppColors.muted(theme.brightness)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${Formatters.monthYear(month)} döneminde işlem yok.',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Kayıtların ${Formatters.monthYear(target)} döneminde duruyor (${counts[target]} işlem).',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => ref.read(selectedMonthProvider.notifier).select(target),
              child: Text('${Formatters.monthYear(target)} dönemini aç'),
            ),
          ),
        ],
      ),
    );
  }
}
