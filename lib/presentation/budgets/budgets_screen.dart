import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/analytics/analytics_engine.dart';
import '../../domain/analytics/month_scope.dart';
import '../../domain/models/budget_record.dart';
import '../../domain/models/wallet_snapshot.dart';
import '../../state/month_scope_controller.dart';
import '../../state/wallet_controller.dart';
import '../widgets/category_detail_sheet.dart';
import '../widgets/folio_background.dart';
import '../widgets/folio_text_dialog.dart';
import '../widgets/loading_view.dart';
import '../widgets/premium_surface.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WalletSnapshot> wallet = ref.watch(walletProvider);
    final DateTime selectedMonth = ref.watch(selectedMonthProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bütçeler'),
        actions: <Widget>[
          IconButton(
            onPressed: () => _addNewBudget(context, ref, wallet.value),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Yeni Bütçe',
          ),
        ],
      ),
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
                Text('KATEGORİLER (${snapshot.budgets.length})', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 12),
                if (snapshot.budgets.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Henüz belirlenmiş bir bütçe sınırı yok.\nYukarıdaki + düğmesine basarak kategori limiti belirleyebilirsin.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  )
                else
                  ...snapshot.budgets.map((BudgetRecord budget) {
                    final double spent = analytics.categoryTotals[budget.category] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BudgetCard(
                        budget: budget,
                        spent: spent,
                        onTap: () {
                          showCategoryDetailSheet(
                            context,
                            category: budget.category,
                            amount: spent,
                            totalExpense: analytics.monthExpense,
                            transactions: snapshot.transactions,
                            budget: budget,
                          );
                        },
                        onEdit: () => _editBudget(context, ref, budget),
                        onDelete: () async {
                          final bool? confirmed = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) => AlertDialog(
                              title: Text('${budget.category} bütçesi silinsin mi?'),
                              content: const Text('Bu kategori limiti bütçe takip listenden kaldırılacak.'),
                              actions: <Widget>[
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Sil', style: TextStyle(color: AppColors.coral)),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await ref.read(walletProvider.notifier).deleteBudget(budget.id);
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

  Future<void> _addNewBudget(BuildContext context, WidgetRef ref, WalletSnapshot? snapshot) async {
    final Set<String> existingCategories = snapshot?.budgets.map((BudgetRecord b) => b.category).toSet() ?? <String>{};
    final List<String> available = AppConstants.expenseCategories
        .where((String c) => !existingCategories.contains(c))
        .toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tüm gider kategorileri için zaten bir bütçe sınırı var.')),
      );
      return;
    }

    final _NewBudgetResult? result = await showDialog<_NewBudgetResult>(
      context: context,
      builder: (BuildContext context) => _NewBudgetDialog(categories: available),
    );
    if (result == null) return;
    HapticFeedback.mediumImpact();
    await ref.read(walletProvider.notifier).saveBudget(
      BudgetRecord(
        id: const Uuid().v4(),
        category: result.category,
        limitAmount: result.limit,
      ),
    );
  }

  Future<void> _editBudget(BuildContext context, WidgetRef ref, BudgetRecord budget) async {
    final double? value = await showFolioMoneyPrompt(
      context,
      title: '${budget.category} limiti',
      initial: budget.limitAmount.toStringAsFixed(0),
    );
    if (value == null || value <= 0) return;
    await ref.read(walletProvider.notifier).saveBudget(
      BudgetRecord(id: budget.id, category: budget.category, limitAmount: value),
    );
  }
}

class _NewBudgetResult {
  const _NewBudgetResult({required this.category, required this.limit});
  final String category;
  final double limit;
}

class _NewBudgetDialog extends StatefulWidget {
  const _NewBudgetDialog({required this.categories});

  final List<String> categories;

  @override
  State<_NewBudgetDialog> createState() => _NewBudgetDialogState();
}

class _NewBudgetDialogState extends State<_NewBudgetDialog> {
  late String _selectedCat = widget.categories.first;
  late final TextEditingController _controller = TextEditingController(text: '3000');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni Kategori Bütçesi'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Kategori seç:'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedCat,
            items: widget.categories
                .map((String cat) => DropdownMenuItem<String>(value: cat, child: Text(cat)))
                .toList(),
            onChanged: (String? val) {
              if (val != null) setState(() => _selectedCat = val);
            },
          ),
          const SizedBox(height: 16),
          const Text('Aylık Harcama Limiti:'),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(suffixText: '₺'),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: () {
            final double? parsed = Formatters.parseMoneyInput(_controller.text);
            if (parsed != null && parsed > 0) {
              Navigator.pop(context, _NewBudgetResult(category: _selectedCat, limit: parsed));
            }
          },
          child: const Text('Oluştur'),
        ),
      ],
    );
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
  const _BudgetCard({
    required this.budget,
    required this.spent,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final BudgetRecord budget;
  final double spent;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double ratio = budget.limitAmount <= 0 ? 0 : spent / budget.limitAmount;
    final double remaining = budget.limitAmount - spent;
    final Color color = ratio >= 0.9 ? AppColors.coral : AppColors.category(budget.category);

    return PremiumSurface(
      onTap: onTap,
      elevated: true,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.wallet_outlined, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(budget.category, style: theme.textTheme.headlineSmall),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: AppColors.muted(theme.brightness),
                ),
                onSelected: (String val) {
                  if (val == 'edit') onEdit();
                  if (val == 'delete') onDelete();
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(value: 'edit', child: Text('Limiti Düzenle')),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Bütçeyi Sil', style: TextStyle(color: AppColors.coral)),
                  ),
                ],
              ),
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
                  FractionallySizedBox(
                    widthFactor: ratio.clamp(0.0, 1.0).toDouble(),
                    child: ColoredBox(color: color.withValues(alpha: 0.78)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text(
                remaining >= 0
                    ? '${Formatters.money(remaining)} kaldı'
                    : '${Formatters.money(remaining.abs())} limit üzerinde',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: remaining >= 0 ? null : AppColors.coral,
                ),
              ),
              const Spacer(),
              Text(
                '%${(ratio * 100).clamp(0, 999).toStringAsFixed(0)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
