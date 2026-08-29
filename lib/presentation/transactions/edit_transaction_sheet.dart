import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/transaction_record.dart';
import '../../state/wallet_controller.dart';
import '../widgets/folio_success.dart';

Future<void> showEditTransactionSheet(
  BuildContext context, {
  required TransactionRecord transaction,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    builder: (BuildContext context) => EditTransactionSheet(transaction: transaction),
  );
}

class EditTransactionSheet extends ConsumerStatefulWidget {
  const EditTransactionSheet({required this.transaction, super.key});

  final TransactionRecord transaction;

  @override
  ConsumerState<EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends ConsumerState<EditTransactionSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late TransactionType _type;
  late String _category;
  late DateTime _date;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.transaction.amount % 1 == 0
          ? widget.transaction.amount.toStringAsFixed(0)
          : widget.transaction.amount.toStringAsFixed(2).replaceAll('.', ','),
    );
    _titleController = TextEditingController(text: widget.transaction.title);
    _noteController = TextEditingController(text: widget.transaction.note ?? '');
    _type = widget.transaction.type;
    _category = widget.transaction.category;
    _date = widget.transaction.date;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double? get _amount => Formatters.parseMoneyInput(_amountController.text);
  List<String> get _categoryOptions =>
      _type == TransactionType.expense ? AppConstants.expenseCategories : AppConstants.incomeCategories;

  Future<void> _save() async {
    final double? amount = _amount;
    final String title = _titleController.text.trim();
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir tutar gir.')),
      );
      return;
    }
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bir başlık veya mağaza adı gir.')),
      );
      return;
    }

    setState(() => _saving = true);
    final TransactionRecord updated = widget.transaction.copyWith(
      title: title,
      merchant: title,
      category: _category,
      amount: amount,
      date: _date,
      type: _type,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );

    await ref.read(walletProvider.notifier).updateTransaction(updated);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _saving = false;
      _saved = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final ThemeData theme = Theme.of(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
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
        child: _saved
            ? const FolioSuccess(
                height: 400,
                title: 'Güncellendi',
                body: 'İşlem detayları başarıyla kaydedildi.',
              )
            : ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.94,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 26),
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
                              'İşlemi Düzenle',
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
                      const SizedBox(height: 18),
                      SegmentedButton<TransactionType>(
                        showSelectedIcon: false,
                        segments: const <ButtonSegment<TransactionType>>[
                          ButtonSegment<TransactionType>(
                            value: TransactionType.expense,
                            label: Text('Gider'),
                            icon: Icon(Icons.arrow_upward_rounded),
                          ),
                          ButtonSegment<TransactionType>(
                            value: TransactionType.income,
                            label: Text('Gelir'),
                            icon: Icon(Icons.arrow_downward_rounded),
                          ),
                        ],
                        selected: <TransactionType>{_type},
                        onSelectionChanged: (Set<TransactionType> selection) {
                          if (selection.isNotEmpty) {
                            setState(() {
                              _type = selection.first;
                              if (!_categoryOptions.contains(_category)) {
                                _category = _categoryOptions.first;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 22),
                      Text('TUTAR', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 8),
                      Center(
                        child: TextField(
                          controller: _amountController,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                          ],
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontSize: 52,
                            letterSpacing: -2.2,
                          ),
                          decoration: InputDecoration(
                            hintText: '0 ₺',
                            hintStyle: theme.textTheme.displayLarge?.copyWith(
                              fontSize: 52,
                              color: AppColors.tertiary(theme.brightness).withValues(alpha: 0.58),
                            ),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('BAŞLIK / MAĞAZA', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(hintText: 'İşlem başlığı'),
                      ),
                      const SizedBox(height: 20),
                      Text('KATEGORİ', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categoryOptions.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (BuildContext context, int index) {
                            final String category = _categoryOptions[index];
                            final bool selected = category == _category;
                            final Color tone = AppColors.category(category);
                            return ChoiceChip(
                              label: Text(category),
                              selected: selected,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                setState(() => _category = category);
                              },
                              showCheckmark: false,
                              side: BorderSide(
                                color: selected
                                    ? tone.withValues(alpha: 0.40)
                                    : theme.dividerColor.withValues(alpha: 0.75),
                              ),
                              selectedColor: tone.withValues(
                                alpha: theme.brightness == Brightness.dark ? 0.18 : 0.12,
                              ),
                              backgroundColor: AppColors.elevated(theme.brightness),
                              labelStyle: theme.textTheme.labelLarge?.copyWith(
                                color: selected ? tone : theme.colorScheme.onSurface,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('TARİH', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setState(() => _date = picked);
                        },
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.elevated(theme.brightness),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            border: Border.all(
                              color: theme.dividerColor.withValues(alpha: 0.78),
                              width: 0.75,
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: AppColors.muted(theme.brightness),
                              ),
                              const SizedBox(width: 10),
                              Text(Formatters.fullDate(_date), style: theme.textTheme.labelLarge),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('NOT', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _noteController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(hintText: 'Açıklama veya not'),
                      ),
                      const SizedBox(height: 26),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.scaffoldBackgroundColor,
                                ),
                              )
                            : const Text('Değişiklikleri Kaydet'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
