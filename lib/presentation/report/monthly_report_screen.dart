import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../domain/analytics/analytics_engine.dart';
import '../../domain/analytics/month_scope.dart';
import '../../domain/models/wallet_snapshot.dart';
import '../../state/month_scope_controller.dart';
import '../../state/wallet_controller.dart';
import '../widgets/folio_wordmark.dart';
import '../widgets/loading_view.dart';
import '../widgets/money_pulse.dart';

class MonthlyReportScreen extends ConsumerStatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  ConsumerState<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends ConsumerState<MonthlyReportScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<WalletSnapshot> wallet = ref.watch(walletProvider);
    final DateTime selectedMonth = ref.watch(selectedMonthProvider);
    return Scaffold(
      body: wallet.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace stack) => const Center(child: Text('Rapor açılamadı.')),
        data: (WalletSnapshot snapshot) {
          final WalletAnalytics analytics = AnalyticsEngine.compute(
            snapshot.transactions,
            now: MonthScope.anchorFor(selectedMonth, now: DateTime.now()),
          );
          final String topCategory = analytics.categoryTotals.keys.isEmpty ? '—' : analytics.categoryTotals.keys.first;
          final double topCategoryAmount = analytics.categoryTotals[topCategory] ?? 0;
          final String topMerchant = analytics.merchantTotals.keys.isEmpty ? '—' : analytics.merchantTotals.keys.first;
          final List<_StoryData> stories = <_StoryData>[
            _StoryData(
              eyebrow: Formatters.monthYear(selectedMonth).toUpperCase(),
              title: 'Ayın finansal hikâyesi.',
              body: 'Gelir, gider ve davranışlarının tek bir sakin özeti.',
              accent: AppColors.coffee,
              composition: _StoryComposition.intro,
            ),
            _StoryData(eyebrow: 'GELİR', metric: Formatters.money(analytics.monthIncome), title: 'bu dönemde geldi.', accent: AppColors.sage),
            _StoryData(
              eyebrow: 'HARCAMA',
              metric: Formatters.money(analytics.monthExpense),
              title: 'bu dönemde harcandı.',
              body: '${analytics.changePercent.abs().toStringAsFixed(1).replaceAll('.', ',')}% geçen aya göre ${analytics.changePercent <= 0 ? 'daha düşük' : 'daha yüksek'}.',
              accent: analytics.changePercent <= 0 ? AppColors.sage : AppColors.coral,
            ),
            _StoryData(
              eyebrow: 'EN BÜYÜK PAY',
              title: topCategory,
              metric: Formatters.money(topCategoryAmount),
              body: 'Bu dönemin harcama dağılımında ilk sırada.',
              accent: AppColors.category(topCategory),
              composition: _StoryComposition.offset,
            ),
            _StoryData(eyebrow: 'EN ÇOK HARCANAN YER', title: topMerchant, metric: Formatters.money(analytics.merchantTotals[topMerchant] ?? 0), accent: AppColors.sky),
            _StoryData(
              eyebrow: 'SENDE KALAN',
              metric: Formatters.money(analytics.savings),
              title: 'ayın sonunda sende kaldı.',
              body: 'Tasarruf payı %${analytics.savingsRate.toStringAsFixed(0)}.',
              accent: AppColors.mint,
              composition: _StoryComposition.offset,
            ),
          ];
          return Stack(
            children: <Widget>[
              PageView.builder(
                controller: _controller,
                itemCount: stories.length + 1,
                onPageChanged: (int value) {
                  HapticFeedback.selectionClick();
                  setState(() => _page = value);
                },
                itemBuilder: (BuildContext context, int index) {
                  if (index == stories.length) return _FinalStory(analytics: analytics, onDone: () => context.pop());
                  return _StoryPage(data: stories[index], index: index);
                },
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: List<Widget>.generate(stories.length + 1, (int index) {
                          return Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              height: 2,
                              margin: EdgeInsets.only(right: index == stories.length ? 0 : 6),
                              decoration: BoxDecoration(
                                color: index <= _page ? Theme.of(context).colorScheme.onSurface : Theme.of(context).dividerColor,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded), tooltip: 'Kapat'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _StoryComposition { standard, intro, offset }

class _StoryData {
  const _StoryData({required this.eyebrow, required this.title, required this.accent, this.metric, this.body, this.composition = _StoryComposition.standard});
  final String eyebrow;
  final String title;
  final String? metric;
  final String? body;
  final Color accent;
  final _StoryComposition composition;
}

class _StoryPage extends StatelessWidget {
  const _StoryPage({required this.data, required this.index});
  final _StoryData data;
  final int index;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Alignment glow = index.isEven ? const Alignment(0.9, -0.7) : const Alignment(-0.9, 0.7);
    final int topSpacer = data.composition == _StoryComposition.offset ? 2 : 3;

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 132, 28, 58),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        gradient: RadialGradient(
          center: glow,
          radius: 1.12,
          colors: <Color>[
            data.accent.withValues(alpha: dark ? 0.22 : 0.16),
            theme.scaffoldBackgroundColor.withValues(alpha: 0.98),
            theme.scaffoldBackgroundColor,
          ],
          stops: const <double>[0, 0.5, 1],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: data.composition == _StoryComposition.offset ? -60 : -90,
            bottom: data.composition == _StoryComposition.offset ? 110 : -40,
            child: _StoryHalo(color: data.accent, size: data.composition == _StoryComposition.offset ? 240 : 300),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (data.composition == _StoryComposition.intro) const FolioWordmark(),
              Spacer(flex: topSpacer),
              Text(data.eyebrow, style: theme.textTheme.labelMedium?.copyWith(color: data.accent)),
              const SizedBox(height: 22),
              if (data.metric != null) ...<Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(data.metric!, style: theme.textTheme.displayLarge?.copyWith(fontSize: 64, letterSpacing: -2.8)),
                ),
                const SizedBox(height: 18),
              ],
              Text(
                data.title,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontSize: data.metric == null ? 44 : 28,
                  height: 1.12,
                  letterSpacing: -1.05,
                ),
              ),
              if (data.body != null) ...<Widget>[
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Text(data.body!, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
                ),
              ],
              const Spacer(flex: 4),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoryHalo extends StatelessWidget {
  const _StoryHalo({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color.withValues(alpha: 0.20), color.withValues(alpha: 0.035), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _FinalStory extends StatelessWidget {
  const _FinalStory({required this.analytics, required this.onDone});
  final WalletAnalytics analytics;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.15),
          radius: 0.9,
          colors: <Color>[
            AppColors.pulseForScore(analytics.financialScore).withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.14 : 0.09),
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 132, 28, 48),
        child: Column(
          children: <Widget>[
            const Spacer(),
            MoneyPulse(score: analytics.financialScore, size: 218),
            const SizedBox(height: 28),
            Text('FİNANSAL DENGE', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 12),
            Text('${analytics.financialScore} / 100', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                analytics.financialScore >= 80 ? 'Gelir ve gider ritmin bu ay dengeli ilerledi.' : 'Bu ay birkaç kategori daha yakından izlenebilir.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const Spacer(),
            FilledButton(onPressed: onDone, child: const Text('Tamamla')),
          ],
        ),
      ),
    );
  }
}
