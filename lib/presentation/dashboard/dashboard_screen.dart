import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/analytics/analytics_engine.dart';
import '../../domain/analytics/month_scope.dart';
import '../../domain/models/subscription_record.dart';
import '../../domain/models/transaction_record.dart';
import '../../domain/models/wallet_snapshot.dart';
import '../../state/month_scope_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/wallet_controller.dart';
import '../add/add_transaction_sheet.dart';
import '../widgets/category_spend_row.dart';
import '../widgets/empty_month_notice.dart';
import '../widgets/folio_background.dart';
import '../widgets/folio_page.dart';
import '../widgets/folio_wordmark.dart';
import '../widgets/insight_block.dart';
import '../widgets/loading_view.dart';
import '../widgets/month_selector.dart';
import '../widgets/premium_surface.dart';
import '../widgets/section_header.dart';
import '../widgets/spending_chart.dart';
import '../widgets/spending_composition_chart.dart';
import '../widgets/transaction_row.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WalletSnapshot> asyncWallet = ref.watch(walletProvider);
    final DateTime selectedMonth = ref.watch(selectedMonthProvider);
    final String userName = ref.watch(
      settingsProvider.select((SettingsState value) => value.userName),
    );

    return asyncWallet.when(
      loading: () => const LoadingView(),
      error: (Object error, StackTrace stack) => _ErrorState(
        onRetry: () => ref.read(walletProvider.notifier).refresh(),
      ),
      data: (WalletSnapshot wallet) {
        if (wallet.transactions.isEmpty) {
          return FolioBackground(child: _EmptyWallet(userName: userName));
        }
        final WalletAnalytics analytics = AnalyticsEngine.compute(
          wallet.transactions,
          now: MonthScope.anchorFor(selectedMonth, now: DateTime.now()),
        );
        return FolioBackground(
          child: FolioScroll(
            onRefresh: () => ref.read(walletProvider.notifier).refresh(),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: FolioPage(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _TopBar(userName: userName),
                      const SizedBox(height: 30),
                      _HeroSummary(analytics: analytics, month: selectedMonth),
                      if (EmptyMonthNotice.isNeeded(wallet.transactions, selectedMonth)) ...<Widget>[
                        const SizedBox(height: 18),
                        EmptyMonthNotice(
                          month: selectedMonth,
                          transactions: wallet.transactions,
                        ),
                      ],
                      const SizedBox(height: 28),
                      _RhythmSurface(analytics: analytics),
                      const SizedBox(height: 18),
                      _BalancePanel(analytics: analytics),
                      const SizedBox(height: AppSpacing.section),
                      _CategorySection(analytics: analytics),
                      const SizedBox(height: AppSpacing.section),
                      if (analytics.insights.isNotEmpty) ...<Widget>[
                        InsightBlock(insight: analytics.insights.first),
                        const SizedBox(height: AppSpacing.section),
                      ],
                      _RecentSection(transactions: wallet.transactions),
                      const SizedBox(height: AppSpacing.compactSection),
                      _QuickLinks(wallet: wallet),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.userName});
  final String userName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        const FolioWordmark(),
        const Spacer(),
        FolioIconButton(
          icon: Icons.auto_awesome_outlined,
          tooltip: 'Aylık rapor',
          label: 'Aylık raporu aç',
          onPressed: () => context.push('/monthly-report'),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: 'Profil',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.go('/profile'),
            child: Ink(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.soft(theme.brightness),
                shape: BoxShape.circle,
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.78), width: 0.8),
              ),
              child: Center(
                child: Text(
                  userName.isEmpty ? 'F' : userName.substring(0, 1).toUpperCase(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.ink(theme.brightness),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroSummary extends StatelessWidget {
  const _HeroSummary({required this.analytics, required this.month});
  final WalletAnalytics analytics;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();
    final bool isLiveMonth = month.year == now.year && month.month == now.month;
    final bool down = analytics.changePercent <= 0;
    final Color deltaColor = down ? AppColors.sage : AppColors.terracotta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            // Expanded, not Spacer: a Row hands unbounded width to inflexible
            // children, and the selector needs a real bound to ellipsize
            // against instead of overflowing on a narrow screen.
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: MonthSelector(dense: true),
              ),
            ),
            const SizedBox(width: 8),
            Icon(down ? Icons.south_east_rounded : Icons.north_east_rounded, size: 15, color: deltaColor),
            const SizedBox(width: 6),
            Text(
              '%${analytics.changePercent.abs().toStringAsFixed(1).replaceAll('.', ',')}',
              style: theme.textTheme.labelLarge?.copyWith(color: deltaColor),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            Formatters.money(analytics.monthExpense),
            style: theme.textTheme.displayLarge?.copyWith(fontSize: 58),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isLiveMonth ? 'bu ay harcadın' : '${Formatters.monthYear(month)} içinde harcadın',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted(theme.brightness)),
        ),
        const SizedBox(height: 22),
        PremiumSurface(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          radius: AppSpacing.radiusMd,
          child: Row(
            children: <Widget>[
              Expanded(
                child: _HeroMetric(
                  label: 'Gelir',
                  value: Formatters.money(analytics.monthIncome),
                  // Everything that reports what is left is income minus
                  // expense, so the figure people need to correct first is
                  // this one. Tapping it goes straight to the income form.
                  onTap: () => showAddTransactionSheet(
                    context,
                    initialType: TransactionType.income,
                  ),
                ),
              ),
              Container(width: 1, height: 38, color: theme.dividerColor),
              const SizedBox(width: 16),
              Expanded(child: _HeroMetric(label: 'Sende kaldı', value: Formatters.money(analytics.savings))),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value, this.onTap});
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
        const SizedBox(height: 6),
        FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _RhythmSurface extends StatelessWidget {
  const _RhythmSurface({required this.analytics});
  final WalletAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<double> last7 = analytics.dailySeries
        .skip(analytics.dailySeries.length > 7 ? analytics.dailySeries.length - 7 : 0)
        .map((DailySpendPoint point) => point.amount)
        .toList(growable: false);
    final double recentAverage = last7.isEmpty
        ? 0
        : last7.fold<double>(0, (double sum, double value) => sum + value) / last7.length;
    double peak = 0;
    for (final DailySpendPoint point in analytics.dailySeries) {
      if (point.amount > peak) peak = point.amount;
    }

    return PremiumSurface(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Günlük harcama', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 5),
          Text('Seçili dönemde her günün harcaması. Kesikli çizgi günlük ortalaman.', style: theme.textTheme.bodySmall),
          const SizedBox(height: 18),
          SpendingChart(
            key: ValueKey<String>(
              'home-chart-${analytics.monthExpense}-${analytics.dailySeries.fold<double>(0, (double a, DailySpendPoint p) => a + p.amount)}',
            ),
            points: analytics.dailySeries,
            height: 228,
          ),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 0.7, color: theme.dividerColor),
          const SizedBox(height: 13),
          Row(
            children: <Widget>[
              Expanded(child: _InlineMetric(label: '7 gün ortalaması', value: Formatters.money(recentAverage))),
              const SizedBox(width: 18),
              Expanded(child: _InlineMetric(label: 'En yüksek gün', value: Formatters.money(peak))),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _BalancePanel extends StatelessWidget {
  const _BalancePanel({required this.analytics});
  final WalletAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tone = AppColors.pulseForScore(analytics.financialScore);
    final String summary = analytics.financialScore >= 80
        ? 'Gelir ve gider ritmin dengeli ilerliyor.'
        : analytics.financialScore >= 65
            ? 'Denge iyi; birkaç kategori daha yakından izlenebilir.'
            : 'Bu ay gider yoğunluğu daha yüksek seyrediyor.';

    return PremiumSurface(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: theme.brightness == Brightness.dark ? 0.14 : 0.09),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('${analytics.financialScore}', style: theme.textTheme.headlineMedium?.copyWith(color: tone)),
                      Text('Denge', style: theme.textTheme.labelSmall?.copyWith(color: tone)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Finansal denge', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    Text(summary, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted(theme.brightness))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: <Widget>[
                  ColoredBox(color: AppColors.soft(theme.brightness), child: const SizedBox.expand()),
                  FractionallySizedBox(
                    widthFactor: (analytics.financialScore / 100).clamp(0.0, 1.0),
                    child: ColoredBox(color: tone),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(child: _InlineMetric(label: 'Tasarruf oranı', value: '%${analytics.savingsRate.toStringAsFixed(0)}')),
              const SizedBox(width: 18),
              Expanded(child: _InlineMetric(label: 'Sende kalan', value: Formatters.money(analytics.savings))),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.analytics});
  final WalletAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, double>> entries = analytics.categoryTotals.entries.take(5).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          eyebrow: 'dağılım',
          title: 'Paranın dağılımı',
          subtitle: 'Toplam harcamanın hangi kategorilerde toplandığını gör.',
        ),
        const SizedBox(height: 16),
        PremiumSurface(
          elevated: true,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
          child: entries.isEmpty
              ? const Padding(
                  padding: EdgeInsets.fromLTRB(4, 18, 4, 22),
                  child: Text('Bu ay henüz kategori dağılımı yok. Harcama ekledikçe burada görünür.'),
                )
              : Column(
            children: <Widget>[
              SpendingCompositionChart(
                categoryTotals: analytics.categoryTotals,
                total: analytics.monthExpense,
              ),
              Divider(height: 1, thickness: 0.7, color: Theme.of(context).dividerColor),
              for (int i = 0; i < entries.length; i++) ...<Widget>[
                CategorySpendRow(
                  category: entries[i].key,
                  amount: entries[i].value,
                  share: analytics.monthExpense <= 0 ? 0 : entries[i].value / analytics.monthExpense,
                  rank: i + 1,
                ),
                if (i != entries.length - 1)
                  Divider(height: 1, thickness: 0.7, color: Theme.of(context).dividerColor.withValues(alpha: 0.7)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentSection extends StatelessWidget {
  const _RecentSection({required this.transactions});
  final List<TransactionRecord> transactions;

  @override
  Widget build(BuildContext context) {
    final List<TransactionRecord> recent = transactions.take(5).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Son işlemler',
          subtitle: 'Yakındaki hareketlerin.',
          trailing: TextButton(onPressed: () => context.go('/transactions'), child: const Text('Tümü')),
        ),
        const SizedBox(height: 12),
        PremiumSurface(
          elevated: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: recent.isEmpty
              ? const Padding(
                  padding: EdgeInsets.fromLTRB(8, 22, 8, 22),
                  child: Text('Henüz işlem yok. Fiş tarayarak, manuel girerek veya ekstre aktararak başlayabilirsin.'),
                )
              : Column(
            children: recent.map((TransactionRecord item) {
              final bool last = identical(item, recent.last);
              return Column(
                children: <Widget>[
                  TransactionRow(
                    transaction: item,
                    compact: true,
                    onTap: () => context.push('/transaction/${item.id}'),
                  ),
                  if (!last) Divider(height: 1, thickness: 0.7, color: Theme.of(context).dividerColor),
                ],
              );
            }).toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _QuickLinks extends StatelessWidget {
  const _QuickLinks({required this.wallet});
  final WalletSnapshot wallet;

  @override
  Widget build(BuildContext context) {
    final double monthlySubscriptions = wallet.subscriptions.fold<double>(
      0,
      (double total, SubscriptionRecord item) => total + item.monthlyAmount,
    );
    return Row(
      children: <Widget>[
        Expanded(
          child: _QuickLink(
            icon: Icons.donut_large_rounded,
            title: 'Bütçeler',
            value: '${wallet.budgets.length} aktif sınır',
            onTap: () => context.push('/budgets'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickLink(
            icon: Icons.repeat_rounded,
            title: 'Abonelikler',
            value: '${Formatters.money(monthlySubscriptions)} / ay',
            onTap: () => context.push('/subscriptions'),
          ),
        ),
      ],
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({required this.icon, required this.title, required this.value, required this.onTap});
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return PremiumSurface(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      radius: AppSpacing.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 19, color: AppColors.accent(theme.brightness)),
          const SizedBox(height: 14),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Shown before the wallet holds anything. Folio no longer fills a new install
/// with sample transactions, so the first screen has to offer a way in.
class _EmptyWallet extends StatelessWidget {
  const _EmptyWallet({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 20, AppSpacing.page, 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Align(alignment: Alignment.centerLeft, child: FolioWordmark()),
                const SizedBox(height: 34),
                Text(
                  userName.isEmpty ? 'Hoş geldin' : 'Hoş geldin, $userName',
                  style: theme.textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Cüzdanın henüz boş. Ekstreni aktardığında harcamaların, gelirlerin ve '
                  'tekrarlayan ödemelerin burada toplanır.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 26),
                PremiumSurface(
                  elevated: true,
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text('Başlamanın yolları', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                      _EmptyAction(
                        icon: Icons.trending_up_rounded,
                        title: 'Gelirini gir',
                        subtitle: 'Ay sonunda sende ne kaldığını görebilmek için tek kayıt yeter.',
                        onTap: () => showAddTransactionSheet(
                          context,
                          initialType: TransactionType.income,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _EmptyAction(
                        icon: Icons.file_upload_outlined,
                        title: 'Ekstre aktar',
                        subtitle: 'Bankandan indirdiğin CSV, XLSX veya PDF ekstreyi oku.',
                        onTap: () => context.push('/statement'),
                      ),
                      const SizedBox(height: 10),
                      _EmptyAction(
                        icon: Icons.document_scanner_outlined,
                        title: 'Fiş tara',
                        subtitle: 'Kameranla fişi okut, tutarı doğrula.',
                        onTap: () => context.push('/receipt'),
                      ),
                      const SizedBox(height: 10),
                      _EmptyAction(
                        icon: Icons.science_outlined,
                        title: 'Örnek veriyle gez',
                        subtitle: 'Profil › Verilerim bölümünden örnek cüzdanı yükle.',
                        onTap: () => context.go('/profile'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyAction extends StatelessWidget {
  const _EmptyAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.soft(theme.brightness),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 19, color: AppColors.accent(theme.brightness)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.tertiary(theme.brightness)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Görünüm yüklenemedi.', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Verilerini yeniden yüklemeyi deneyebilirsin.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 18),
            TextButton(onPressed: onRetry, child: const Text('Yeniden dene')),
          ],
        ),
      ),
    );
  }
}
