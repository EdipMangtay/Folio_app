import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/analytics/analytics_engine.dart';
import 'premium_surface.dart';

Future<void> showFinancialScoreSheet(
  BuildContext context, {
  required WalletAnalytics analytics,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (BuildContext context) => FinancialScoreSheet(analytics: analytics),
  );
}

class FinancialScoreSheet extends StatelessWidget {
  const FinancialScoreSheet({required this.analytics, super.key});

  final WalletAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tone = AppColors.pulseForScore(analytics.financialScore);

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
                  Expanded(
                    child: Text(
                      'Finansal Denge Analizi',
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Kapat',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Gelir, harcama ritmi ve tasarruf dengenin puanlanmış özeti.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              PremiumSurface(
                elevated: true,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: tone.withValues(
                          alpha: theme.brightness == Brightness.dark ? 0.16 : 0.10,
                        ),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '${analytics.financialScore}',
                            style: theme.textTheme.displayMedium?.copyWith(
                              color: tone,
                              fontWeight: FontWeight.w700,
                              fontSize: 32,
                            ),
                          ),
                          Text(
                            '/ 100',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: tone.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            analytics.financialScore >= 80
                                ? 'Yüksek Denge'
                                : analytics.financialScore >= 65
                                    ? 'Dengeli Seyir'
                                    : 'Gözlem Gerekli',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: tone,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            analytics.financialScore >= 80
                                ? 'Gelirinin sağlıklı bir kısmı sende kalıyor ve harcama ritmin dengeli.'
                                : analytics.financialScore >= 65
                                    ? 'Genel görünüm olumlu; değişken harcamalara dikkat ederek tasarruf payını artırabilirsin.'
                                    : 'Bu dönem gider yoğunluğun gelirine oranla daha yüksek ilerliyor.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text('PUAN BİLEŞENLERİ', style: theme.textTheme.labelMedium),
              const SizedBox(height: 12),
              _ScoreFactorCard(
                icon: Icons.savings_outlined,
                title: 'Tasarruf Oranı',
                subtitle: 'Gelirinden geriye kalan tutarın oranı.',
                metric: '%${analytics.savingsRate.toStringAsFixed(0)}',
                status: analytics.savingsRate >= 20
                    ? 'Güçlü'
                    : analytics.savingsRate >= 10
                        ? 'İyi'
                        : 'Düşük',
                statusTone: analytics.savingsRate >= 20
                    ? AppColors.sage
                    : analytics.savingsRate >= 10
                        ? AppColors.coffee
                        : AppColors.terracotta,
              ),
              const SizedBox(height: 10),
              _ScoreFactorCard(
                icon: Icons.speed_rounded,
                title: 'Harcama Ritmi',
                subtitle: 'Geçen aya kıyasla toplam gider değişimi.',
                metric: '${analytics.changePercent <= 0 ? '−' : '+'}${analytics.changePercent.abs().toStringAsFixed(1).replaceAll('.', ',')}%',
                status: analytics.changePercent <= 0 ? 'İdeal' : 'Hızlanmış',
                statusTone: analytics.changePercent <= 0
                    ? AppColors.sage
                    : AppColors.terracotta,
              ),
              const SizedBox(height: 10),
              _ScoreFactorCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Nakit Fazlası',
                subtitle: 'Bu dönem sende kalan net nakit.',
                metric: Formatters.money(analytics.savings),
                status: analytics.savings >= 0 ? 'Pozitif' : 'Açık',
                statusTone: analytics.savings >= 0
                    ? AppColors.sage
                    : AppColors.terracotta,
              ),
              const SizedBox(height: 24),
              Text('ÖNERİLER', style: theme.textTheme.labelMedium),
              const SizedBox(height: 12),
              ...analytics.insights.map((insight) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PremiumSurface(
                      elevated: true,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 18,
                            color: AppColors.accent(theme.brightness),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  insight.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  insight.body,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreFactorCard extends StatelessWidget {
  const _ScoreFactorCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.metric,
    required this.status,
    required this.statusTone,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String metric;
  final String status;
  final Color statusTone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return PremiumSurface(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.soft(theme.brightness),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: AppColors.muted(theme.brightness)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                metric,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusTone.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.16 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  status,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusTone,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
