import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/analytics/analytics_engine.dart';
import '../../domain/analytics/month_scope.dart';
import '../../domain/models/budget_record.dart';
import '../../domain/models/wallet_snapshot.dart';
import '../../state/month_scope_controller.dart';
import '../../state/wallet_controller.dart';
import '../widgets/folio_background.dart';
import '../widgets/loading_view.dart';
import '../widgets/premium_surface.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WalletSnapshot> wallet = ref.watch(walletProvider);
    final DateTime selectedMonth = ref.watch(selectedMonthProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bütçeler')),
      body: FolioBackground(
        child: wallet.when(
          loading: () => const LoadingView(),
          error: (Object error, StackTrace stack) => const Center(child: Text('Bütçeler açılamadı.')),
          data: (WalletSnapshot snapshot) {
            final WalletAnalytics analytics = AnalyticsEngine.compute(
              snapshot.transactions,
              now: MonthScope.anchorFor(selectedMonth, now: DateTime.now()),
            );
            final double totalLimit = snapshot.budgets.fold<double>(0, (double a, BudgetRecord b) => a + b.limitAmount);
            final double trackedSpend = snapshot.budgets.fold<double>(0, (double a, BudgetRecord b) => a + (analytics.categoryTotals[b.category] ?? 0));
            final double ratio = totalLimit <= 0 ? 0 : trackedSpend / totalLimit;
            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 44),
              children: <Widget>[
                Text('${Formatters.monthYear(selectedMonth)} sınırları', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text('Bütçeyi kısıt değil, karar desteği olarak kullan.', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 24),
                _BudgetOverview(spent: trackedSpend, limit: totalLimit, ratio: ratio),
                const SizedBox(height: 30),
                Text('KATEGORİLER', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 12),
                ...snapshot.budgets.map((BudgetRecord budget) {
                  final double spent = analytics.categoryTotals[budget.category] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BudgetCard(budget: budget, spent: spent, onEdit: () => _editBudget(context, ref, budget)),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _editBudget(BuildContext context, WidgetRef ref, BudgetRecord budget) async {
    final TextEditingController controller = TextEditingController(text: budget.limitAmount.toStringAsFixed(0));
    final double? value = await showDialog<double>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('${budget.category} limiti'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: '₺'),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () {
              final double? parsed = Formatters.parseMoneyInput(controller.text);
              if (parsed != null && parsed > 0) Navigator.pop(context, parsed);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await ref.read(walletProvider.notifier).saveBudget(BudgetRecord(id: budget.id, category: budget.category, limitAmount: value));
  }
}

class _BudgetOverview extends StatelessWidget {
  const _BudgetOverview({required this.spent, required this.limit, required this.ratio});
  final double spent;
  final double limit;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tone = ratio >= 0.9 ? AppColors.coral : AppColors.accent(theme.brightness);
    final double remaining = limit - spent;
    return PremiumSurface(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Takip edilen bütçe', style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          FittedBox(child: Text(Formatters.money(limit), style: theme.textTheme.displayMedium)),
          const SizedBox(height: 8),
          Text('${Formatters.money(spent)} kullanıldı', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: <Widget>[
                  ColoredBox(color: AppColors.soft(theme.brightness), child: const SizedBox.expand()),
                  FractionallySizedBox(
                    widthFactor: ratio.clamp(0.0, 1.0).toDouble(),
                    child: ColoredBox(color: tone.withValues(alpha: 0.78)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Text(remaining >= 0 ? '${Formatters.money(remaining)} alan kaldı' : '${Formatters.money(remaining.abs())} limit üzerinde', style: theme.textTheme.bodySmall?.copyWith(color: remaining >= 0 ? null : AppColors.coral)),
              const Spacer(),
              Text('%${(ratio * 100).clamp(0, 999).toStringAsFixed(0)}', style: theme.textTheme.titleSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget, required this.spent, required this.onEdit});
  final BudgetRecord budget;
  final double spent;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double ratio = budget.limitAmount <= 0 ? 0 : spent / budget.limitAmount;
    final double remaining = budget.limitAmount - spent;
    final Color color = ratio >= 0.9 ? AppColors.coral : AppColors.category(budget.category);

    return PremiumSurface(
      onTap: onEdit,
      elevated: true,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(13)), alignment: Alignment.center, child: Icon(Icons.wallet_outlined, color: color, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Text(budget.category, style: theme.textTheme.headlineSmall)),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.tertiary(theme.brightness)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(child: Text(Formatters.money(spent), style: theme.textTheme.titleLarge)),
              Text('/ ${Formatters.money(budget.limitAmount)}', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 7,
              child: Stack(
                children: <Widget>[
                  ColoredBox(color: color.withValues(alpha: 0.11), child: const SizedBox.expand()),
                  FractionallySizedBox(widthFactor: ratio.clamp(0.0, 1.0).toDouble(), child: ColoredBox(color: color.withValues(alpha: 0.78))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text(remaining >= 0 ? '${Formatters.money(remaining)} kaldı' : '${Formatters.money(remaining.abs())} limit üzerinde', style: theme.textTheme.bodySmall?.copyWith(color: remaining >= 0 ? null : AppColors.coral)),
              const Spacer(),
              Text('%${(ratio * 100).clamp(0, 999).toStringAsFixed(0)}', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
