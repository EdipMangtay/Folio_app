import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/analytics/analytics_engine.dart';
import '../../domain/analytics/month_scope.dart';
import '../../domain/models/wallet_snapshot.dart';
import '../../state/month_scope_controller.dart';
import '../../state/wallet_controller.dart';
import '../widgets/cash_flow_comparison_chart.dart';
import '../widgets/empty_month_notice.dart';
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
    return wallet.when(
      loading: () => const LoadingView(),
      error: (Object error, StackTrace stack) => const Center(child: Text('Analiz açılamadı.')),
      data: (WalletSnapshot snapshot) {
        final WalletAnalytics analytics = AnalyticsEngine.compute(
          snapshot.transactions,
          now: MonthScope.anchorFor(selectedMonth, now: DateTime.now()),
        );
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
                  _OverviewCard(analytics: analytics, month: selectedMonth),
                  const SizedBox(height: AppSpacing.section),
                  const SectionHeader(title: 'Harcama eğilimi', subtitle: 'Seçili dönemin günlük hareketleri ve yumuşatılmış ana trendi.'),
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
                  const SectionHeader(title: 'Harcama dağılımı', subtitle: 'Toplam giderin hangi kategorilerde toplandığını gör.'),
                  const SizedBox(height: 14),
                  PremiumSurface(
                    elevated: true,
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                    child: analytics.categoryTotals.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Bu dönemde kategori dağılımı yok.'),
                          )
                        : SpendingCompositionChart(
                            categoryTotals: analytics.categoryTotals,
                            total: analytics.monthExpense,
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

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.analytics, required this.month});
  final WalletAnalytics analytics;
  final DateTime month;

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
            child: Text(Formatters.money(analytics.monthExpense), style: theme.textTheme.displayMedium),
          ),
          const SizedBox(height: 6),
          Text('toplam harcama', style: theme.textTheme.bodySmall),
          const SizedBox(height: 20),
          Divider(height: 1, thickness: 0.7, color: theme.dividerColor),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(child: _Metric(label: 'Gelir', value: Formatters.money(analytics.monthIncome))),
              const SizedBox(width: 16),
              Expanded(child: _Metric(label: 'Sende kalan', value: Formatters.money(analytics.savings))),
              const SizedBox(width: 16),
              Expanded(child: _Metric(label: 'Tasarruf', value: '%${analytics.savingsRate.toStringAsFixed(0)}')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        ),
      ],
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
