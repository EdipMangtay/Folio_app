import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/budget_record.dart';
import '../../domain/models/transaction_record.dart';
import 'brand_avatar.dart';
import 'premium_surface.dart';
import 'transaction_row.dart';

Future<void> showCategoryDetailSheet(
  BuildContext context, {
  required String category,
  required double amount,
  required double totalExpense,
  required List<TransactionRecord> transactions,
  BudgetRecord? budget,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (BuildContext context) => CategoryDetailSheet(
      category: category,
      amount: amount,
      totalExpense: totalExpense,
      transactions: transactions,
      budget: budget,
    ),
  );
}

class CategoryDetailSheet extends StatelessWidget {
  const CategoryDetailSheet({
    required this.category,
    required this.amount,
    required this.totalExpense,
    required this.transactions,
    this.budget,
    super.key,
  });

  final String category;
  final double amount;
  final double totalExpense;
  final List<TransactionRecord> transactions;
  final BudgetRecord? budget;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tone = AppColors.category(category);
    final double share = totalExpense <= 0 ? 0 : (amount / totalExpense) * 100;
    final List<TransactionRecord> categoryTxns = transactions
        .where((TransactionRecord item) => item.category == category)
        .toList(growable: false);
    final double avgTxn = categoryTxns.isEmpty ? 0 : amount / categoryTxns.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.elevated(theme.brightness),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusSheet),
        ),
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.80),
            width: 0.75,
          ),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.90,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.tertiary(theme.brightness).withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  BrandAvatar(name: category, category: category, size: 44),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(category, style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 2),
                        Text(
                          'Kategori Detayı ve Harcamalar',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Kapat',
                  ),
                ],
              ),
              const SizedBox(height: 22),
              PremiumSurface(
                elevated: true,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('TOPLAM HARCAMA', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 8),
                    FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Formatters.money(amount),
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: AppColors.ink(theme.brightness),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Divider(height: 1, thickness: 0.7, color: theme.dividerColor),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _MetricTile(
                            label: 'Pay',
                            value: '%${share.toStringAsFixed(1).replaceAll('.', ',')}',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MetricTile(
                            label: 'İşlem',
                            value: '${categoryTxns.length} adet',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MetricTile(
                            label: 'Ortalama',
                            value: Formatters.money(avgTxn),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (budget != null) ...<Widget>[
                const SizedBox(height: 18),
                _CategoryBudgetCard(budget: budget!, spent: amount, tone: tone),
              ],
              const SizedBox(height: 26),
              Text(
                'BU KATEGORİDEKİ İŞLEMLER (${categoryTxns.length})',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 12),
              PremiumSurface(
                elevated: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: categoryTxns.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.fromLTRB(8, 22, 8, 22),
                        child: Center(
                          child: Text('Bu dönemde henüz işlem kaydı yok.'),
                        ),
                      )
                    : Column(
                        children: categoryTxns.map((TransactionRecord item) {
                          final bool isLast = identical(item, categoryTxns.last);
                          return Column(
                            children: <Widget>[
                              TransactionRow(
                                transaction: item,
                                compact: true,
                                onTap: () {
                                  Navigator.of(context).pop();
                                  context.push('/transaction/${item.id}');
                                },
                              ),
                              if (!isLast)
                                Divider(
                                  height: 1,
                                  thickness: 0.7,
                                  color: theme.dividerColor,
                                ),
                            ],
                          );
                        }).toList(growable: false),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryBudgetCard extends StatelessWidget {
  const _CategoryBudgetCard({
    required this.budget,
    required this.spent,
    required this.tone,
  });

  final BudgetRecord budget;
  final double spent;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double ratio = budget.limitAmount <= 0 ? 0 : spent / budget.limitAmount;
    final double remaining = budget.limitAmount - spent;
    final bool over = remaining < 0;

    return PremiumSurface(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.donut_large_rounded, size: 16, color: tone),
              const SizedBox(width: 8),
              Text('Aylık Bütçe Durumu', style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                over
                    ? '${Formatters.money(remaining.abs())} aşıldı'
                    : '${Formatters.money(remaining)} kaldı',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: over ? AppColors.coral : AppColors.sage,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: <Widget>[
                  ColoredBox(
                    color: AppColors.soft(theme.brightness),
                    child: const SizedBox.expand(),
                  ),
                  FractionallySizedBox(
                    widthFactor: ratio.clamp(0.0, 1.0),
                    child: ColoredBox(
                      color: over ? AppColors.coral : tone,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '${Formatters.money(spent)} harcandı',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                'Limit: ${Formatters.money(budget.limitAmount)} (%${(ratio * 100).round()})',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
