import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/analytics/month_scope.dart';
import '../../domain/models/transaction_record.dart';
import '../../state/month_scope_controller.dart';
import '../../state/wallet_controller.dart';

/// Minimum comfortable tap area. Below this the arrows are a coin toss.
const double _tapTarget = 44;

/// Steps the analytics surfaces through the months the wallet actually holds.
///
/// An imported statement usually covers a period that has already closed, so
/// without this its figures are stored but never reachable.
///
/// The month reads as a button rather than a caption: plain text gives no hint
/// that a period can be changed at all, which is how the control was missed.
class MonthSelector extends ConsumerWidget {
  const MonthSelector({super.key, this.dense = false});

  /// Tightens the pill for sitting inline above a headline figure. The tap
  /// area stays full size — only the padding and type scale shrink.
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime selected = ref.watch(selectedMonthProvider);
    final List<TransactionRecord> transactions =
        ref.watch(walletProvider).value?.transactions ?? const <TransactionRecord>[];
    final List<DateTime> months = MonthScope.availableMonths(transactions, now: DateTime.now());

    final bool canGoBack = MonthScope.canStep(selected, -1, months);
    final bool canGoForward = MonthScope.canStep(selected, 1, months);

    void step(int offset) {
      HapticFeedback.selectionClick();
      ref.read(selectedMonthProvider.notifier).step(offset);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Arrow(
          icon: Icons.chevron_left_rounded,
          label: 'Önceki ay',
          onPressed: canGoBack ? () => step(-1) : null,
        ),
        Flexible(
          child: _MonthPill(
            month: selected,
            dense: dense,
            hasData: _monthHasData(transactions, selected),
            onTap: () => _pickMonth(context, ref, months, transactions),
          ),
        ),
        _Arrow(
          icon: Icons.chevron_right_rounded,
          label: 'Sonraki ay',
          onPressed: canGoForward ? () => step(1) : null,
        ),
      ],
    );
  }

  static bool _monthHasData(List<TransactionRecord> transactions, DateTime month) {
    return transactions.any(
      (TransactionRecord item) => item.date.year == month.year && item.date.month == month.month,
    );
  }

  Future<void> _pickMonth(
    BuildContext context,
    WidgetRef ref,
    List<DateTime> months,
    List<TransactionRecord> transactions,
  ) async {
    HapticFeedback.lightImpact();
    final DateTime selected = ref.read(selectedMonthProvider);
    final DateTime? chosen = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.36),
      builder: (BuildContext sheetContext) => _MonthSheet(
        months: months,
        selected: selected,
        transactions: transactions,
      ),
    );
    if (chosen != null) ref.read(selectedMonthProvider.notifier).select(chosen);
  }
}

/// The month itself, styled as a button so it reads as changeable.
class _MonthPill extends StatelessWidget {
  const _MonthPill({
    required this.month,
    required this.dense,
    required this.hasData,
    required this.onTap,
  });

  final DateTime month;
  final bool dense;
  final bool hasData;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color ink = AppColors.ink(theme.brightness);

    return Semantics(
      button: true,
      label: 'Dönem: ${Formatters.monthYear(month)}. Değiştirmek için dokun.',
      child: Material(
        color: AppColors.soft(theme.brightness),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          child: Container(
            constraints: const BoxConstraints(minHeight: _tapTarget),
            padding: EdgeInsets.fromLTRB(dense ? 14 : 16, 0, dense ? 8 : 10, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              border: Border.all(color: theme.dividerColor, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (!hasData) ...<Widget>[
                  Icon(
                    Icons.circle_outlined,
                    size: 8,
                    color: AppColors.tertiary(theme.brightness),
                  ),
                  const SizedBox(width: 7),
                ],
                Flexible(
                  child: Text(
                    // The year is noise in the tight dashboard slot while it is
                    // the current one; it reappears as soon as it differs.
                    dense && month.year == DateTime.now().year
                        ? Formatters.month(month)
                        : Formatters.monthYear(month),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (dense ? theme.textTheme.labelLarge : theme.textTheme.titleMedium)
                        ?.copyWith(color: ink, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.expand_more_rounded, size: dense ? 18 : 20, color: ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: SizedBox(
        width: _tapTarget,
        height: _tapTarget,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Icon(
              icon,
              size: 24,
              color: enabled
                  ? AppColors.ink(theme.brightness)
                  // Kept visible but clearly inert, rather than invisible.
                  : AppColors.muted(theme.brightness).withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}

/// The full period list. Months without data stay in the list rather than
/// being hidden, so a gap in the wallet reads as a gap and not as missing UI.
class _MonthSheet extends StatelessWidget {
  const _MonthSheet({
    required this.months,
    required this.selected,
    required this.transactions,
  });

  final List<DateTime> months;
  final DateTime selected;
  final List<TransactionRecord> transactions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime live = MonthScope.monthOf(DateTime.now());

    final Map<DateTime, double> expense = <DateTime, double>{};
    final Map<DateTime, double> income = <DateTime, double>{};
    final Map<DateTime, int> counts = <DateTime, int>{};
    for (final TransactionRecord item in transactions) {
      final DateTime month = MonthScope.monthOf(item.date);
      counts.update(month, (int value) => value + 1, ifAbsent: () => 1);
      final Map<DateTime, double> bucket = item.isExpense ? expense : income;
      bucket.update(month, (double value) => value + item.amount, ifAbsent: () => item.amount);
    }

    final List<DateTime> newestFirst = months.reversed.toList(growable: false);
    final int withData = counts.length;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.68),
        decoration: BoxDecoration(
          color: AppColors.elevated(theme.brightness),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSheet),
          border: Border.all(color: theme.dividerColor, width: 0.8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 34,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 16),
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text('Dönem seç', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  Text(
                    withData == 0 ? 'Kayıt yok' : '$withData ayda kayıt var',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 0.7, color: theme.dividerColor),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                itemCount: newestFirst.length,
                itemBuilder: (BuildContext context, int index) {
                  final DateTime month = newestFirst[index];
                  final bool showYear = index == 0 || newestFirst[index - 1].year != month.year;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (showYear)
                        Padding(
                          padding: EdgeInsets.fromLTRB(14, index == 0 ? 6 : 18, 14, 8),
                          child: Text('${month.year}', style: theme.textTheme.labelMedium),
                        ),
                      _MonthRow(
                        month: month,
                        isSelected: month.year == selected.year && month.month == selected.month,
                        isLive: month.year == live.year && month.month == live.month,
                        count: counts[month] ?? 0,
                        expense: expense[month] ?? 0,
                        income: income[month] ?? 0,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.month,
    required this.isSelected,
    required this.isLive,
    required this.count,
    required this.expense,
    required this.income,
  });

  final DateTime month;
  final bool isSelected;
  final bool isLive;
  final int count;
  final double expense;
  final double income;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool empty = count == 0;
    final Color ink = AppColors.ink(theme.brightness);

    return Material(
      color: isSelected ? AppColors.soft(theme.brightness) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(month),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: <Widget>[
              // A shape, not only a colour, marks what holds data.
              Icon(
                empty ? Icons.remove_rounded : Icons.circle,
                size: empty ? 12 : 8,
                color: empty
                    ? AppColors.tertiary(theme.brightness)
                    : AppColors.accent(theme.brightness),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            Formatters.month(month),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: empty ? AppColors.muted(theme.brightness) : ink,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isLive) ...<Widget>[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.soft(theme.brightness),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                              border: Border.all(color: theme.dividerColor, width: 0.7),
                            ),
                            child: Text('bu ay', style: theme.textTheme.labelSmall),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      empty ? 'işlem yok' : '$count işlem',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!empty) ...<Widget>[
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '−${Formatters.money(expense)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (income > 0) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        '+${Formatters.money(income)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.sage),
                      ),
                    ],
                  ],
                ),
              ],
              if (isSelected) ...<Widget>[
                const SizedBox(width: 10),
                Icon(Icons.check_rounded, size: 20, color: AppColors.accent(theme.brightness)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
