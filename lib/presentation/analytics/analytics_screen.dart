import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/analytics/analytics_engine.dart';
import '../../domain/analytics/month_scope.dart';
import '../../domain/models/budget_record.dart';
import '../../domain/models/transaction_record.dart';
import '../../domain/models/wallet_snapshot.dart';
import '../../state/month_scope_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/wallet_controller.dart';
import '../add/add_transaction_sheet.dart';
import '../widgets/cash_flow_comparison_chart.dart';
import '../widgets/category_detail_sheet.dart';
import '../widgets/category_spend_row.dart';
import '../widgets/empty_month_notice.dart';
import '../widgets/financial_score_sheet.dart';
import '../widgets/folio_background.dart';
import '../widgets/folio_page.dart';
import '../widgets/loading_view.dart';
import '../widgets/month_selector.dart';
import '../widgets/premium_surface.dart';
import '../widgets/section_header.dart';
import '../widgets/spending_chart.dart';
import '../widgets/spending_composition_chart.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WalletSnapshot> wallet = ref.watch(walletProvider);
    final DateTime selectedMonth = ref.watch(selectedMonthProvider);
    final bool hideBalances = ref.watch(
      settingsProvider.select((SettingsState value) => value.hideBalances),
    );

    return wallet.when(
      loading: () => const LoadingView(),
      error: (Object error, StackTrace stack) => const Center(child: Text('Analiz açılamadı.')),
      data: (WalletSnapshot snapshot) {
        final WalletAnalytics analytics = AnalyticsEngine.compute(
          snapshot.transactions,
          now: MonthScope.anchorFor(selectedMonth, now: DateTime.now()),
        );
        final List<MapEntry<String, double>> topCategories = analytics.categoryTotals.entries.take(5).toList();

        return FolioBackground(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: FolioPage(
              padding: AppSpacing.pageInsetsTop,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Analiz', style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 7),
                  Text('Seçtiğin dönemin finansal görünümünü sade ve karşılaştırılabilir şekilde incele.', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 14),
                  const MonthSelector(),
                  const SizedBox(height: 20),
                  if (EmptyMonthNotice.isNeeded(snapshot.transactions, selectedMonth)) ...<Widget>[
                    EmptyMonthNotice(
                      month: selectedMonth,
                      transactions: snapshot.transactions,
                    ),
                    const SizedBox(height: 18),
                  ],
                  _OverviewCard(
                    analytics: analytics,
                    month: selectedMonth,
                    hideBalances: hideBalances,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: PremiumSurface(
                          elevated: true,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          onTap: () => context.push('/weekly-report'),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppColors.coffee.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.view_carousel_outlined,
                                  size: 18,
                                  color: AppColors.coffee,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Haftalık Özet',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '7 günlük hikâye',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: AppColors.muted(Theme.of(context).brightness),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PremiumSurface(
                          elevated: true,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          onTap: () => context.push('/monthly-report'),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppColors.sage.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.auto_awesome_outlined,
                                  size: 18,
                                  color: AppColors.sage,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Aylık Özet',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Dönem hikâyesi',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: AppColors.muted(Theme.of(context).brightness),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.section),
                  _FinancialScoreCard(
                    analytics: analytics,
                    onTap: () => showFinancialScoreSheet(context, analytics: analytics),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  const SectionHeader(title: 'Günlük harcama', subtitle: 'Seçili dönemde her günün harcaması. Kesikli çizgi günlük ortalaman.'),
                  const SizedBox(height: 14),
                  PremiumSurface(
                    elevated: true,
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                    child: SpendingChart(
                      key: ValueKey<String>(
                        'analytics-chart-${analytics.monthExpense}-${analytics.dailySeries.fold<double>(0, (double a, DailySpendPoint p) => a + p.amount)}',
                      ),
                      points: analytics.dailySeries,
                      height: 238,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  const SectionHeader(title: 'Nakit akışı', subtitle: 'Seçili dönemin geliri, harcaması ve sonunda kalan tutar.'),
                  const SizedBox(height: 14),
                  PremiumSurface(
                    elevated: true,
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                    child: CashFlowComparisonChart(
                      income: analytics.monthIncome,
                      expense: analytics.monthExpense,
                      savings: analytics.savings,
                      height: 220,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  const SectionHeader(title: 'Harcama dağılımı', subtitle: 'Toplam giderin hangi kategorilerde toplandığını gör. Detay için kategoriye dokun.'),
                  const SizedBox(height: 14),
                  PremiumSurface(
                    elevated: true,
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                    child: analytics.categoryTotals.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Bu dönemde kategori dağılımı yok.'),
                          )
                        : Column(
                            children: <Widget>[
                              SpendingCompositionChart(
                                categoryTotals: analytics.categoryTotals,
                                total: analytics.monthExpense,
                              ),
                              Divider(height: 1, thickness: 0.7, color: Theme.of(context).dividerColor),
                              for (int i = 0; i < topCategories.length; i++) ...<Widget>[
                                CategorySpendRow(
                                  category: topCategories[i].key,
                                  amount: topCategories[i].value,
                                  share: analytics.monthExpense <= 0 ? 0 : topCategories[i].value / analytics.monthExpense,
                                  rank: i + 1,
                                  onTap: () {
                                    BudgetRecord? categoryBudget;
                                    for (final BudgetRecord b in snapshot.budgets) {
                                      if (b.category == topCategories[i].key) {
                                        categoryBudget = b;
                                        break;
                                      }
                                    }
                                    showCategoryDetailSheet(
                                      context,
                                      category: topCategories[i].key,
                                      amount: topCategories[i].value,
                                      totalExpense: analytics.monthExpense,
                                      transactions: snapshot.transactions,
                                      budget: categoryBudget,
                                    );
                                  },
                                ),
                                if (i != topCategories.length - 1)
                                  Divider(height: 1, thickness: 0.7, color: Theme.of(context).dividerColor.withValues(alpha: 0.7)),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  _MerchantRanking(analytics: analytics),
                  const SizedBox(height: AppSpacing.section),
                  _WeekdayRhythm(analytics: analytics),
                  const SizedBox(height: AppSpacing.section),
                  _SavingsStory(analytics: analytics),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FinancialScoreCard extends StatelessWidget {
  const _FinancialScoreCard({required this.analytics, required this.onTap});

  final WalletAnalytics analytics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tone = AppColors.pulseForScore(analytics.financialScore);

    return PremiumSurface(
      onTap: onTap,
      elevated: true,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: theme.brightness == Brightness.dark ? 0.16 : 0.10),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${analytics.financialScore}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Skor',
                  style: theme.textTheme.labelSmall?.copyWith(color: tone, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Finansal Sağlık Skoru', style: theme.textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  'Tasarruf, bütçe uyumu ve düzenlilik analizi',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: AppColors.tertiary(theme.brightness),
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.analytics,
    required this.month,
    this.hideBalances = false,
  });

  final WalletAnalytics analytics;
  final DateTime month;
  final bool hideBalances;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();
    final bool isLiveMonth = month.year == now.year && month.month == now.month;
    return PremiumSurface(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            isLiveMonth ? 'BU AY' : Formatters.monthYear(month).toUpperCase(),
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              hideBalances ? '•••• ₺' : Formatters.money(analytics.monthExpense),
              style: theme.textTheme.displayMedium,
            ),
          ),
          const SizedBox(height: 6),
          Text('toplam harcama', style: theme.textTheme.bodySmall),
          const SizedBox(height: 20),
          Divider(height: 1, thickness: 0.7, color: theme.dividerColor),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _Metric(
                  label: 'Gelir',
                  value: hideBalances ? '•••• ₺' : Formatters.money(analytics.monthIncome),
                  onTap: () => showAddTransactionSheet(
                    context,
                    initialType: TransactionType.income,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Metric(
                  label: 'Sende kalan',
                  value: hideBalances ? '•••• ₺' : Formatters.money(analytics.savings),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Metric(
                  label: 'Tasarruf',
                  value: '%${analytics.savingsRate.toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(label, style: theme.textTheme.bodySmall),
            if (onTap != null) ...<Widget>[
              const SizedBox(width: 5),
              Icon(Icons.add_circle_outline_rounded,
                  size: 13, color: AppColors.muted(theme.brightness)),
            ],
          ],
        ),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        ),
      ],
    );

    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: '$label: $value. Gelir eklemek için dokun.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: content,
        ),
      ),
    );
  }
}

class _MerchantRanking extends StatelessWidget {
  const _MerchantRanking({required this.analytics});
  final WalletAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, double>> entries = analytics.merchantTotals.entries.take(6).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: 'En çok harcadığın yerler'),
        const SizedBox(height: 14),
        PremiumSurface(
          elevated: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: entries.isEmpty
              ? const Padding(
                  padding: EdgeInsets.fromLTRB(8, 22, 8, 22),
                  child: Text('Bu ay henüz mağaza harcaması yok.'),
                )
              : Column(
            children: <Widget>[
              for (int i = 0; i < entries.length; i++) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 26,
                        child: Text(
                          '${i + 1}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.tertiary(Theme.of(context).brightness)),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entries[i].key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(Formatters.money(entries[i].value), style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
                if (i != entries.length - 1)
                  Divider(height: 1, thickness: 0.7, color: Theme.of(context).dividerColor),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekdayRhythm extends StatelessWidget {
  const _WeekdayRhythm({required this.analytics});
  final WalletAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    const List<String> labels = <String>['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];
    double max = 1;
    for (final double value in analytics.weekdayTotals.values) {
      if (value > max) max = value;
    }
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: 'Haftalık ritim', subtitle: 'Harcamaların haftanın hangi günlerinde yoğunlaşıyor.'),
        const SizedBox(height: 14),
        PremiumSurface(
          elevated: true,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
          child: SizedBox(
            height: 176,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List<Widget>.generate(7, (int index) {
                final double value = analytics.weekdayTotals[index + 1] ?? 0;
                final double factor = max <= 0 ? 0 : value / max;
                final bool weekend = index >= 5;
                final Color color = weekend ? AppColors.terracotta : AppColors.accent(theme.brightness);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      children: <Widget>[
                        Expanded(
                          child: LayoutBuilder(
                            builder: (BuildContext context, BoxConstraints constraints) {
                              final double usable = constraints.maxHeight > 8 ? constraints.maxHeight - 8 : 0;
                              final double barHeight = value <= 0 ? 6 : 8 + factor * usable;
                              return Align(
                                alignment: Alignment.bottomCenter,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 480),
                                  curve: Curves.easeOutCubic,
                                  width: 22,
                                  height: barHeight,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: theme.brightness == Brightness.dark ? 0.78 : 0.70),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(labels[index], style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class _SavingsStory extends StatelessWidget {
  const _SavingsStory({required this.analytics});
  final WalletAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool healthy = analytics.savingsRate >= 20;
    final Color tone = healthy ? AppColors.sage : AppColors.accent(theme.brightness);
    return PremiumSurface(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.savings_outlined, size: 20, color: tone),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Tasarruf görünümü', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 7),
                Text(
                  healthy
                      ? 'Gelirinin anlamlı bir kısmı sende kalıyor. Bu ritim finansal esnekliğini güçlendiriyor.'
                      : 'Tasarruf payında daha fazla alan yaratmak için değişken giderleri biraz daha yakından takip edebilirsin.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted(theme.brightness)),
                ),
                const SizedBox(height: 12),
                Text('%${analytics.savingsRate.toStringAsFixed(0)} tasarruf oranı', style: theme.textTheme.titleMedium?.copyWith(color: tone)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
