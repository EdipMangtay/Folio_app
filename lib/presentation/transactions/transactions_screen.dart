import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/transaction_record.dart';
import '../../domain/models/wallet_snapshot.dart';
import '../../state/wallet_controller.dart';
import '../widgets/folio_background.dart';
import '../widgets/folio_page.dart';
import '../widgets/loading_view.dart';
import '../widgets/premium_surface.dart';
import '../widgets/transaction_row.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'Tümü';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<WalletSnapshot> wallet = ref.watch(walletProvider);
    return wallet.when(
      loading: () => const LoadingView(),
      error: (Object error, StackTrace stack) => Center(
        child: FilledButton(
          onPressed: () => ref.read(walletProvider.notifier).refresh(),
          child: const Text('Tekrar dene'),
        ),
      ),
      data: (WalletSnapshot snapshot) {
        final List<TransactionRecord> filtered = _apply(snapshot.transactions);
        final double expense = filtered.where((TransactionRecord e) => e.isExpense).fold<double>(0, (double a, TransactionRecord b) => a + b.amount);
        final double income = filtered.where((TransactionRecord e) => e.isIncome).fold<double>(0, (double a, TransactionRecord b) => a + b.amount);

        return FolioBackground(
          accentAlignment: const Alignment(-0.95, -0.92),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: FolioPage(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, 18, AppSpacing.page, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('İşlemler', style: Theme.of(context).textTheme.headlineLarge),
                      const SizedBox(height: 7),
                      Text('Tüm para hareketlerin, arama ve filtrelerle tek akışta.', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 24),
                      Row(
                        children: <Widget>[
                          Expanded(child: _SummaryPill(label: 'Gider', value: Formatters.money(expense), tone: AppColors.coral)),
                          const SizedBox(width: 10),
                          Expanded(child: _SummaryPill(label: 'Gelir', value: Formatters.money(income), tone: AppColors.sage)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _SearchField(controller: _searchController, onChanged: (_) => setState(() {})),
                      const SizedBox(height: 14),
                      _FilterBar(selected: _filter, labels: _filters, onChanged: (String value) => setState(() => _filter = value)),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(color: AppColors.soft(Theme.of(context).brightness), borderRadius: BorderRadius.circular(18)),
                            child: Icon(Icons.search_off_rounded, size: 24, color: AppColors.tertiary(Theme.of(context).brightness)),
                          ),
                          const SizedBox(height: 16),
                          Text('Bu görünümde işlem yok.', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 5),
                          Text('Aramayı veya filtreyi değiştirebilirsin.', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (BuildContext context, int index) {
                    final TransactionRecord item = filtered[index];
                    final bool showHeader = index == 0 || !_sameDay(item.date, filtered[index - 1].date);
                    final bool nextDifferentDay = index == filtered.length - 1 || !_sameDay(item.date, filtered[index + 1].date);
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContent),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (showHeader) ...<Widget>[
                                SizedBox(height: index == 0 ? 18 : 24),
                                Text(_dayLabel(item.date), style: Theme.of(context).textTheme.labelMedium),
                                const SizedBox(height: 10),
                              ],
                              PremiumSurface(
                                elevated: true,
                                padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
                                radius: 22,
                                child: TransactionRow(
                                  transaction: item,
                                  onTap: () => context.push('/transaction/${item.id}'),
                                ),
                              ),
                              if (!nextDifferentDay) const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 44)),
            ],
          ),
        );
      },
    );
  }

  static const List<String> _filters = <String>['Tümü', 'Bu hafta', 'Bu ay', 'Gider', 'Gelir'];

  List<TransactionRecord> _apply(List<TransactionRecord> source) {
    final DateTime now = DateTime.now();
    final String query = _searchController.text.trim().toLowerCase();
    return source.where((TransactionRecord item) {
      final bool queryMatch = query.isEmpty || item.title.toLowerCase().contains(query) || item.category.toLowerCase().contains(query) || (item.merchant?.toLowerCase().contains(query) ?? false);
      if (!queryMatch) return false;
      switch (_filter) {
        case 'Bu hafta':
          final DateTime start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
          return !item.date.isBefore(start);
        case 'Bu ay':
          return item.date.year == now.year && item.date.month == now.month;
        case 'Gider':
          return item.isExpense;
        case 'Gelir':
          return item.isIncome;
        default:
          return true;
      }
    }).toList(growable: false);
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime date) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target = DateTime(date.year, date.month, date.day);
    final int diff = today.difference(target).inDays;
    if (diff == 0) return 'BUGÜN';
    if (diff == 1) return 'DÜN';
    return Formatters.fullDate(date).toUpperCase();
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.value, required this.tone});
  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: theme.brightness == Brightness.dark ? 0.12 : 0.075),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: 0.10), width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'İşlem, mağaza veya kategori ara',
        prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.muted(theme.brightness)),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.labels, required this.onChanged});
  final String selected;
  final List<String> labels;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final String label = labels[index];
          final bool isSelected = selected == label;
          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => onChanged(label),
            selectedColor: AppColors.accentSoft(theme.brightness),
            backgroundColor: AppColors.elevated(theme.brightness),
            side: BorderSide(color: isSelected ? AppColors.accent(theme.brightness).withValues(alpha: 0.18) : theme.dividerColor.withValues(alpha: 0.7)),
            labelStyle: theme.textTheme.labelLarge?.copyWith(
              color: isSelected ? AppColors.accent(theme.brightness) : theme.colorScheme.onSurface,
            ),
          );
        },
      ),
    );
  }
}
