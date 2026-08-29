import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/transaction_record.dart';
import '../../domain/models/wallet_snapshot.dart';
import '../../state/wallet_controller.dart';
import '../widgets/brand_avatar.dart';
import '../widgets/folio_background.dart';
import '../widgets/loading_view.dart';
import '../widgets/premium_surface.dart';
import 'edit_transaction_sheet.dart';

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({required this.transactionId, super.key});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WalletSnapshot> wallet = ref.watch(walletProvider);
    return wallet.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (Object error, StackTrace stack) => const Scaffold(body: Center(child: Text('İşlem açılamadı.'))),
      data: (WalletSnapshot snapshot) {
        TransactionRecord? transaction;
        for (final TransactionRecord item in snapshot.transactions) {
          if (item.id == transactionId) {
            transaction = item;
            break;
          }
        }
        if (transaction == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            body: const Center(child: Text('İşlem bulunamadı.')),
          );
        }
        final TransactionRecord found = transaction;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            actions: <Widget>[
              IconButton(
                onPressed: () => showEditTransactionSheet(context, transaction: found),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'İşlemi düzenle',
              ),
            ],
          ),
          body: FolioBackground(
            child: _Detail(
              transaction: found,
              onEdit: () => showEditTransactionSheet(context, transaction: found),
              onDelete: () async {
                await ref.read(walletProvider.notifier).deleteTransaction(found.id);
                if (context.mounted) context.pop();
              },
            ),
          ),
        );
      },
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.transaction,
    required this.onEdit,
    required this.onDelete,
  });

  final TransactionRecord transaction;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tone = transaction.isIncome ? AppColors.sage : AppColors.category(transaction.category);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 46),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            children: <Widget>[
              PremiumSurface(
                elevated: true,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                child: Column(
                  children: <Widget>[
                    BrandAvatar(name: transaction.title, category: transaction.category, size: 72),
                    const SizedBox(height: 18),
                    Text(transaction.title, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    FittedBox(
                      child: Text(
                        Formatters.money(transaction.amount, decimals: transaction.amount % 1 != 0),
                        style: theme.textTheme.displayLarge?.copyWith(fontSize: 54, letterSpacing: -2.35),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${Formatters.fullDate(transaction.date)} · ${transaction.date.hour.toString().padLeft(2, '0')}:${transaction.date.minute.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        _MetaPill(label: transaction.isIncome ? 'Gelir' : 'Gider', tone: transaction.isIncome ? AppColors.sage : AppColors.terracotta),
                        const SizedBox(width: 8),
                        _MetaPill(label: transaction.category, tone: tone),
                        const SizedBox(width: 8),
                        _MetaPill(label: _sourceLabel(transaction.source), tone: AppColors.sand),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              PremiumSurface(
                elevated: true,
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
                child: Column(
                  children: <Widget>[
                    _DetailRow(icon: Icons.category_outlined, label: 'Kategori', value: transaction.category),
                    Divider(height: 1, thickness: 0.7, color: theme.dividerColor.withValues(alpha: 0.55)),
                    _DetailRow(icon: transaction.isIncome ? Icons.south_west_rounded : Icons.north_east_rounded, label: 'Tür', value: transaction.isIncome ? 'Gelir' : 'Gider'),
                    Divider(height: 1, thickness: 0.7, color: theme.dividerColor.withValues(alpha: 0.55)),
                    _DetailRow(icon: Icons.credit_card_outlined, label: 'Ödeme', value: transaction.paymentLabel ?? 'Belirtilmedi'),
                    Divider(height: 1, thickness: 0.7, color: theme.dividerColor.withValues(alpha: 0.55)),
                    _DetailRow(icon: Icons.input_rounded, label: 'Kaynak', value: _sourceLabel(transaction.source)),
                    if (transaction.note != null) ...<Widget>[
                      Divider(height: 1, thickness: 0.7, color: theme.dividerColor.withValues(alpha: 0.55)),
                      _DetailRow(icon: Icons.notes_rounded, label: 'Not', value: transaction.note!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                      ),
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 19),
                      label: const Text('Düzenle'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        side: BorderSide(color: AppColors.coral.withValues(alpha: 0.30)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                      ),
                      onPressed: () async {
                        final bool? confirmed = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            title: const Text('İşlem silinsin mi?'),
                            content: const Text('Bu hareket yerel kayıtlarından kaldırılacak.'),
                            actions: <Widget>[
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil', style: TextStyle(color: AppColors.coral))),
                            ],
                          ),
                        );
                        if (confirmed == true) await onDelete();
                      },
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.coral, size: 19),
                      label: const Text('Sil', style: TextStyle(color: AppColors.coral)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sourceLabel(TransactionSource source) => switch (source) {
        TransactionSource.manual => 'Manuel',
        TransactionSource.receipt => 'Fiş',
        TransactionSource.statement => 'Ekstre',
        TransactionSource.demo => 'Demo',
      };
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, required this.tone});
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tone)),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: AppColors.soft(theme.brightness), borderRadius: BorderRadius.circular(13)),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: AppColors.muted(theme.brightness)),
          ),
          const SizedBox(width: 13),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted(theme.brightness)))),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: theme.textTheme.titleMedium)),
        ],
      ),
    );
  }
}
