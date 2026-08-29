import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../domain/analytics/weekly_analytics.dart';
import '../../domain/models/wallet_snapshot.dart';
import '../../state/wallet_controller.dart';
import '../widgets/brand_avatar.dart';
import '../widgets/folio_wordmark.dart';
import '../widgets/loading_view.dart';
import '../widgets/premium_surface.dart';

class WeeklyReportScreen extends ConsumerStatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  ConsumerState<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends ConsumerState<WeeklyReportScreen> {
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

    return Scaffold(
      body: wallet.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace stack) =>
            const Center(child: Text('Rapor açılamadı.')),
        data: (WalletSnapshot snapshot) {
          final WeeklyAnalytics weekly =
              WeeklyAnalyticsEngine.compute(snapshot.transactions);

          final List<_WeeklyStoryData> stories = <_WeeklyStoryData>[
            _WeeklyStoryData(
              eyebrow: 'BU HAFTANIN HİKÂYESİ',
              title: weekly.summaryHeadline,
              body: weekly.summaryMessage,
              accent: AppColors.coffee,
              type: _WeeklyStoryType.intro,
            ),
            _WeeklyStoryData(
              eyebrow: 'HAFTALIK HARCAMA',
              metric: Formatters.money(weekly.weekExpense),
              title: 'bu hafta harcandı.',
              body: weekly.previousWeekExpense > 0
                  ? 'Geçen haftaya göre %${weekly.changePercent.abs().toStringAsFixed(0)} ${weekly.changePercent <= 0 ? 'daha tasarruflu' : 'daha yüksek'}.'
                  : 'Bu haftanın günlük ortalama harcaması: ${Formatters.money(weekly.dailyAverage)}.',
              accent: weekly.changePercent <= 0 ? AppColors.sage : AppColors.coral,
              type: _WeeklyStoryType.metric,
            ),
            _WeeklyStoryData(
              eyebrow: 'HAFTANIN LİDER KATEGORİSİ',
              title: weekly.topCategory,
              metric: Formatters.money(weekly.topCategoryAmount),
              body: 'Haftalık toplam harcamanın en büyük kısmı bu kategoriye ait.',
              accent: AppColors.category(weekly.topCategory),
              type: _WeeklyStoryType.category,
              categoryName: weekly.topCategory,
            ),
            if (weekly.topTransaction != null)
              _WeeklyStoryData(
                eyebrow: 'HAFTANIN EN YÜKSEK İŞLEMİ',
                title: weekly.topTransaction!.title,
                metric: Formatters.money(weekly.topTransaction!.amount),
                body:
                    '${Formatters.relativeDate(weekly.topTransaction!.date)} • ${weekly.topTransaction!.category}',
                accent: AppColors.sky,
                type: _WeeklyStoryType.transaction,
              ),
            _WeeklyStoryData(
              eyebrow: 'GÜNLÜK HARCAMA RİTMİ',
              title: weekly.busiestDay == '—'
                  ? 'Dengeli Günler'
                  : 'En yoğun gün: ${weekly.busiestDay}',
              body: 'Haftalık harcamalarının 7 günlük seyri.',
              accent: AppColors.accent(Theme.of(context).brightness),
              type: _WeeklyStoryType.dailyRhythm,
              dailySeries: weekly.dailySeries,
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
                  if (index == stories.length) {
                    return _WeeklyFinalStory(
                      weekly: weekly,
                      onDone: () => context.pop(),
                    );
                  }
                  return _WeeklyStoryPage(
                    data: stories[index],
                    index: index,
                  );
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
                              height: 2.5,
                              margin: EdgeInsets.only(
                                right: index == stories.length ? 0 : 6,
                              ),
                              decoration: BoxDecoration(
                                color: index <= _page
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context).dividerColor.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Kapat',
                        ),
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

enum _WeeklyStoryType { intro, metric, category, transaction, dailyRhythm }

class _WeeklyStoryData {
  const _WeeklyStoryData({
    required this.eyebrow,
    required this.title,
    required this.accent,
    required this.type,
    this.metric,
    this.body,
    this.categoryName,
    this.dailySeries,
  });

  final String eyebrow;
  final String title;
  final Color accent;
  final _WeeklyStoryType type;
  final String? metric;
  final String? body;
  final String? categoryName;
  final List<DaySpendPoint>? dailySeries;
}

class _WeeklyStoryPage extends StatelessWidget {
  const _WeeklyStoryPage({required this.data, required this.index});

  final _WeeklyStoryData data;
  final int index;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Alignment glow =
        index.isEven ? const Alignment(0.85, -0.65) : const Alignment(-0.85, 0.65);

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 132, 28, 58),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        gradient: RadialGradient(
          center: glow,
          radius: 1.15,
          colors: <Color>[
            data.accent.withValues(alpha: dark ? 0.22 : 0.15),
            theme.scaffoldBackgroundColor.withValues(alpha: 0.98),
            theme.scaffoldBackgroundColor,
          ],
          stops: const <double>[0, 0.5, 1],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (data.type == _WeeklyStoryType.intro) const FolioWordmark(),
          const Spacer(flex: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: data.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              data.eyebrow,
              style: theme.textTheme.labelMedium?.copyWith(
                color: data.accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 22),
          if (data.categoryName != null) ...<Widget>[
            BrandAvatar(
              name: data.categoryName!,
              category: data.categoryName!,
              size: 54,
            ),
            const SizedBox(height: 18),
          ],
          if (data.metric != null) ...<Widget>[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                data.metric!,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 58,
                  letterSpacing: -2.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            data.title,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: data.metric == null ? 40 : 26,
              height: 1.14,
              letterSpacing: -0.9,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (data.body != null) ...<Widget>[
            const SizedBox(height: 18),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                data.body!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                  color: AppColors.ink(theme.brightness).withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
          if (data.type == _WeeklyStoryType.dailyRhythm && data.dailySeries != null) ...<Widget>[
            const SizedBox(height: 28),
            _WeeklyBarVisualizer(series: data.dailySeries!, accent: data.accent),
          ],
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _WeeklyBarVisualizer extends StatelessWidget {
  const _WeeklyBarVisualizer({required this.series, required this.accent});

  final List<DaySpendPoint> series;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double max = series.fold(
      1.0,
      (double prev, DaySpendPoint p) => p.amount > prev ? p.amount : prev,
    );

    return PremiumSurface(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('GÜNLERE GÖRE DAĞILIM', style: theme.textTheme.labelSmall),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: series.map((DaySpendPoint item) {
              final double ratio = max <= 0 ? 0 : (item.amount / max).clamp(0.06, 1.0);
              final bool isPositive = item.amount > 0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        height: 70 * ratio,
                        decoration: BoxDecoration(
                          color: isPositive
                              ? accent
                              : AppColors.tertiary(theme.brightness).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.weekdayName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isPositive
                              ? AppColors.ink(theme.brightness)
                              : AppColors.tertiary(theme.brightness),
                          fontWeight: isPositive ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _WeeklyFinalStory extends StatelessWidget {
  const _WeeklyFinalStory({required this.weekly, required this.onDone});

  final WeeklyAnalytics weekly;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tone = weekly.isFrugal
        ? AppColors.sage
        : weekly.isAccelerated
            ? AppColors.terracotta
            : AppColors.coffee;

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 132, 28, 48),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 0.95,
          colors: <Color>[
            tone.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.16 : 0.10,
            ),
            theme.scaffoldBackgroundColor,
          ],
        ),
      ),
      child: Column(
        children: <Widget>[
          const Spacer(),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.check_rounded,
              size: 48,
              color: tone,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'HAFTALIK ÖZET TAMAMLANDI',
            style: theme.textTheme.labelMedium?.copyWith(
              color: tone,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Haftalık Raporun',
            style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              'Her Pazar akşamı haftalık finansal özet bildirimi alarak bütçe ritmini koruyabilirsin.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.45,
                color: AppColors.ink(theme.brightness).withValues(alpha: 0.85),
              ),
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: onDone,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Tamamla'),
          ),
        ],
      ),
    );
  }
}
