import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/subscription_record.dart';
import '../../domain/models/wallet_snapshot.dart';
import '../../state/wallet_controller.dart';
import '../widgets/brand_avatar.dart';
import '../widgets/folio_background.dart';
import '../widgets/loading_view.dart';
import '../widgets/premium_surface.dart';

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WalletSnapshot> wallet = ref.watch(walletProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Abonelikler')),
      body: FolioBackground(
        accentAlignment: const Alignment(0.92, -0.78),
        child: wallet.when(
          loading: () => const LoadingView(),
          error: (Object error, StackTrace stack) => const Center(child: Text('Abonelikler açılamadı.')),
          data: (WalletSnapshot snapshot) {
            final double monthly = snapshot.subscriptions.fold<double>(0, (double total, SubscriptionRecord item) => total + item.monthlyAmount);
            final List<SubscriptionRecord> sorted = List<SubscriptionRecord>.from(snapshot.subscriptions)..sort((SubscriptionRecord a, SubscriptionRecord b) => b.monthlyAmount.compareTo(a.monthlyAmount));
            final SubscriptionRecord? largest = sorted.isEmpty ? null : sorted.first;
            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 44),
              children: <Widget>[
                Text('Tekrarlayan giderler', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text('Aylık yükü ve yıllık karşılığını tek bakışta gör.', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 24),
                _Hero(monthly: monthly, count: snapshot.subscriptions.length, largest: largest),
                const SizedBox(height: 30),
                Text('${snapshot.subscriptions.length} AKTİF ABONELİK', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 12),
                PremiumSurface(
                  elevated: true,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < sorted.length; i++) ...<Widget>[
                        _SubscriptionRow(item: sorted[i]),
                        if (i != sorted.length - 1) Divider(height: 1, thickness: 0.7, color: Theme.of(context).dividerColor.withValues(alpha: 0.55)),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.monthly, required this.count, required this.largest});
  final double monthly;
  final int count;
  final SubscriptionRecord? largest;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return PremiumSurface(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AYLIK TOPLAM', style: theme.textTheme.labelMedium),
          const SizedBox(height: 12),
          FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text(Formatters.money(monthly), style: theme.textTheme.displayLarge)),
          const SizedBox(height: 8),
          Text('${Formatters.money(monthly * 12)} / yıl', style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted(theme.brightness))),
          const SizedBox(height: 22),
          Row(
            children: <Widget>[
              Expanded(child: _HeroMetric(label: 'Aktif', value: '$count abonelik')),
              const SizedBox(width: 10),
              Expanded(child: _HeroMetric(label: 'En yüksek', value: largest == null ? '—' : Formatters.money(largest!.monthlyAmount))),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: AppColors.soft(theme.brightness), borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 7),
        FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class _SubscriptionRow extends StatelessWidget {
  const _SubscriptionRow({required this.item});
  final SubscriptionRecord item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: <Widget>[
          BrandAvatar(name: item.merchant, category: 'Abonelik', size: 46),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(item.merchant, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('${item.category} · sonraki ${Formatters.shortDate(item.nextBillingDate)}', style: theme.textTheme.bodySmall),
          ])),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
            Text(Formatters.money(item.monthlyAmount), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('/ ay', style: theme.textTheme.bodySmall),
          ]),
        ],
      ),
    );
  }
}
