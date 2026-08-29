import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/goal_record.dart';
import '../../domain/models/wallet_snapshot.dart';
import '../../state/wallet_controller.dart';
import '../widgets/folio_background.dart';
import '../widgets/folio_text_dialog.dart';
import '../widgets/loading_view.dart';
import '../widgets/premium_surface.dart';
import 'add_goal_sheet.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WalletSnapshot> wallet = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Birikim Hedefleri'),
        actions: <Widget>[
          IconButton(
            onPressed: () => showAddGoalSheet(context),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Yeni Hedef',
          ),
        ],
      ),
      body: FolioBackground(
        child: wallet.when(
          loading: () => const LoadingView(),
          error: (Object error, StackTrace stack) => const Center(child: Text('Hedefler açılamadı.')),
          data: (WalletSnapshot snapshot) {
            final List<GoalRecord> goals = snapshot.goals;
            if (goals.isEmpty) {
              return _EmptyGoals(onAdd: () => showAddGoalSheet(context));
            }

            final double totalTarget = goals.fold<double>(
              0,
              (double sum, GoalRecord item) => sum + item.targetAmount,
            );
            final double totalSaved = goals.fold<double>(
              0,
              (double sum, GoalRecord item) => sum + item.savedAmount,
            );
            final double totalProgress = totalTarget <= 0 ? 0 : totalSaved / totalTarget;

            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 44),
              children: <Widget>[
                Text(
                  'Tasarruf Kasası',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Gelecek planların ve büyük hedeflerin için birikimlerini organize et.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                _GoalsOverview(
                  totalTarget: totalTarget,
                  totalSaved: totalSaved,
                  progress: totalProgress,
                  count: goals.length,
                ),
                const SizedBox(height: 30),
                Text(
                  '${goals.length} AKTİF HEDEF',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 12),
                ...goals.map((GoalRecord goal) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _GoalCard(
                      goal: goal,
                      onContribute: (double delta) {
                        ref.read(walletProvider.notifier).contributeToGoal(goal.id, delta);
                      },
                      onEdit: () => showAddGoalSheet(context, initialGoal: goal),
                      onDelete: () async {
                        final bool? confirmed = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            title: Text('${goal.title} silinsin mi?'),
                            content: const Text('Bu birikim hedefi kayıtlardan kaldırılacak.'),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Vazgeç'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Sil',
                                  style: TextStyle(color: AppColors.coral),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ref.read(walletProvider.notifier).deleteGoal(goal.id);
                        }
                      },
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GoalsOverview extends StatelessWidget {
  const _GoalsOverview({
    required this.totalTarget,
    required this.totalSaved,
    required this.progress,
    required this.count,
  });

  final double totalTarget;
  final double totalSaved;
  final double progress;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double remaining = totalTarget - totalSaved;

    return PremiumSurface(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('TOPLAM BİRİKİM', style: theme.textTheme.labelMedium),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.16 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '%${(progress * 100).clamp(0, 100).toStringAsFixed(0)} Tamamlandı',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.sage,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              Formatters.money(totalSaved),
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Toplam Hedef: ${Formatters.money(totalTarget)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.muted(theme.brightness),
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: <Widget>[
                  ColoredBox(
                    color: AppColors.soft(theme.brightness),
                    child: const SizedBox.expand(),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: const ColoredBox(color: AppColors.sage),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Text(
                remaining > 0
                    ? '${Formatters.money(remaining)} kaldı'
                    : 'Tüm hedeflere ulaşıldı 🎉',
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              Text('$count hedef', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.onContribute,
    required this.onEdit,
    required this.onDelete,
  });

  final GoalRecord goal;
  final ValueChanged<double> onContribute;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tone = AppColors.category(goal.category);
    final double ratio = goal.progressRatio;
    final int? days = goal.daysRemaining;

    return PremiumSurface(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tone.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.16 : 0.11,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  goal.isCompleted ? Icons.check_circle_outline_rounded : Icons.savings_outlined,
                  color: tone,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(goal.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      goal.note ?? goal.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: AppColors.muted(theme.brightness),
                ),
                onSelected: (String action) {
                  if (action == 'edit') onEdit();
                  if (action == 'delete') onDelete();
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(value: 'edit', child: Text('Düzenle')),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Sil', style: TextStyle(color: AppColors.coral)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      Formatters.money(goal.savedAmount),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hedef: ${Formatters.money(goal.targetAmount)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: tone.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.16 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '%${(ratio * 100).round()}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 7,
              child: Stack(
                children: <Widget>[
                  ColoredBox(
                    color: AppColors.soft(theme.brightness),
                    child: const SizedBox.expand(),
                  ),
                  FractionallySizedBox(
                    widthFactor: ratio,
                    child: ColoredBox(color: tone),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text(
                goal.isCompleted
                    ? 'Hedefe ulaşıldı! 🚀'
                    : days != null
                        ? (days > 0 ? '$days gün kaldı' : 'Hedef süresi doldu')
                        : '${Formatters.money(goal.remainingAmount)} kaldı',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: goal.isCompleted ? AppColors.sage : null,
                ),
              ),
              const Spacer(),
              _DepositButton(
                label: '+ Ekle',
                tone: tone,
                onTap: () => _showQuickDepositDialog(context, isDeposit: true),
              ),
              const SizedBox(width: 8),
              _DepositButton(
                label: '− Çıkar',
                tone: AppColors.muted(theme.brightness),
                onTap: () => _showQuickDepositDialog(context, isDeposit: false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showQuickDepositDialog(BuildContext context, {required bool isDeposit}) async {
    final double? amount = await showFolioMoneyPrompt(
      context,
      title: isDeposit ? '${goal.title} için Para Ekle' : '${goal.title} fonundan Para Çıkar',
      hint: 'Tutar gir',
      confirmLabel: isDeposit ? 'Ekle' : 'Çıkar',
    );
    if (amount != null && amount > 0) {
      HapticFeedback.lightImpact();
      onContribute(isDeposit ? amount : -amount);
    }
  }
}

class _DepositButton extends StatelessWidget {
  const _DepositButton({
    required this.label,
    required this.tone,
    required this.onTap,
  });

  final String label;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.soft(theme.brightness),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.6),
            width: 0.6,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: tone,
          ),
        ),
      ),
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: PremiumSurface(
            elevated: true,
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.soft(theme.brightness),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.savings_outlined,
                    size: 26,
                    color: AppColors.accent(theme.brightness),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Henüz Birikim Hedefin Yok',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tasarruflarını hedeflere ayırarak motivasyonunu artır. Acil durum fonu, tatil veya yeni bir alım için hedef oluşturabilirsin.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('İlk Hedefini Belirle'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
