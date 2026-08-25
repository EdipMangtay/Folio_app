import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../data/services/merchant_normalizer.dart';
import '../../domain/models/transaction_record.dart';
import '../../state/wallet_controller.dart';
import '../widgets/folio_success.dart';

Future<void> showAddTransactionSheet(
  BuildContext context, {
  TransactionType initialType = TransactionType.expense,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    builder: (BuildContext context) => AddTransactionSheet(initialType: initialType),
  );
}

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({
    super.key,
    this.initialType = TransactionType.expense,
  });

  /// Which side of the ledger the sheet opens on.
  ///
  /// Anything that offers to record income specifically — the income figure on
  /// the dashboard, the empty wallet — lands on the income form rather than
  /// making the user find the segmented control first.
  final TransactionType initialType;

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  late TransactionType _type = widget.initialType;
  late String _category = _defaultCategoryFor(widget.initialType);
  bool _categoryTouched = false;
  bool _saving = false;
  bool _saved = false;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  static String _defaultCategoryFor(TransactionType type) =>
      type == TransactionType.expense ? 'Diğer' : AppConstants.incomeCategories.first;

  double? get _amount => Formatters.parseMoneyInput(_amountController.text);
  List<String> get _categoryOptions => _type == TransactionType.expense ? AppConstants.expenseCategories : AppConstants.incomeCategories;
  String get _sheetTitle => _type == TransactionType.expense ? 'Yeni gider' : 'Yeni gelir';
  String get _ctaLabel => _type == TransactionType.expense ? 'Gideri ekle' : 'Geliri ekle';
  String get _merchantLabel => _type == TransactionType.expense ? 'Nerede?' : 'Kaynak / açıklama';
  String get _merchantHint => _type == TransactionType.expense ? 'Migros, Starbucks, Trendyol...' : 'Maaş, freelance, satış, nakit girişi...';
  String get _helperText => _type == TransactionType.expense
      ? 'Tutarı pozitif gir, Folio mağazaya göre kategori önersin.'
      : 'Geliri pozitif değerle gir. Ay sonu dengesi gelir ve giderden otomatik hesaplanır.';

  Future<void> _save() async {
    final double? amount = _amount;
    final String merchant = MerchantNormalizer.normalize(_merchantController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli bir tutar gir.')));
      return;
    }
    if (_merchantController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_type == TransactionType.expense ? 'Gideri yaptığın yeri ekle.' : 'Gelir kaynağını ekle.')),
      );
      return;
    }

    setState(() => _saving = true);
    const Uuid uuid = Uuid();
    await ref.read(walletProvider.notifier).addTransaction(
          TransactionRecord(
            id: uuid.v4(),
            title: merchant,
            merchant: merchant,
            category: _category,
            amount: amount,
            date: _date,
            type: _type,
            source: TransactionSource.manual,
            paymentLabel: _type == TransactionType.expense ? AppConstants.defaultPaymentLabel : AppConstants.defaultIncomeLabel,
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          ),
        );
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _saving = false;
      _saved = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 880));
    if (mounted) Navigator.of(context).pop();
  }

  void _setType(TransactionType type) {
    if (_type == type) return;
    setState(() {
      _type = type;
      _categoryTouched = false;
      _category = _defaultCategoryFor(type);
      if (_type == TransactionType.expense && _merchantController.text.trim().isNotEmpty) {
        _category = MerchantNormalizer.categoryFor(_merchantController.text);
      }
    });
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusSheet)),
          border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.80), width: 0.75)),
        ),
        child: _saved ? _success(context) : _form(context),
      ),
    );
  }

  Widget _success(BuildContext context) {
    return FolioSuccess(
      height: 430,
      title: 'Kaydedildi',
      body: '${_type == TransactionType.expense ? 'Gider' : 'Gelir'} kaydın görünümüne eklendi.',
    );
  }

  Widget _form(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color muted = AppColors.muted(theme.brightness);
    final String suggested = _type == TransactionType.expense && _merchantController.text.trim().isNotEmpty ? MerchantNormalizer.categoryFor(_merchantController.text) : '';

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.94),
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
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                  color: AppColors.tertiary(theme.brightness).withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: <Widget>[
                Expanded(child: Text(_sheetTitle, style: theme.textTheme.headlineMedium)),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded), tooltip: 'Kapat'),
              ],
            ),
            const SizedBox(height: 18),
            SegmentedButton<TransactionType>(
              showSelectedIcon: false,
              segments: const <ButtonSegment<TransactionType>>[
                ButtonSegment<TransactionType>(value: TransactionType.expense, label: Text('Gider'), icon: Icon(Icons.arrow_upward_rounded)),
                ButtonSegment<TransactionType>(value: TransactionType.income, label: Text('Gelir'), icon: Icon(Icons.arrow_downward_rounded)),
              ],
              selected: <TransactionType>{_type},
              onSelectionChanged: (Set<TransactionType> selection) {
                if (selection.isNotEmpty) _setType(selection.first);
              },
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: AppColors.soft(theme.brightness).withValues(alpha: 0.64),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: <Widget>[
                  Icon(_type == TransactionType.expense ? Icons.bolt_rounded : Icons.savings_outlined, size: 18, color: _type == TransactionType.expense ? AppColors.accent(theme.brightness) : AppColors.sage),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_helperText, style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('TUTAR', style: theme.textTheme.labelMedium),
            const SizedBox(height: 10),
            Center(
              child: TextField(
                controller: _amountController,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                style: theme.textTheme.displayLarge?.copyWith(fontSize: 56, letterSpacing: -2.45),
                decoration: InputDecoration(
                  hintText: '0 ₺',
                  hintStyle: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 56,
                    letterSpacing: -2.45,
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
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Pozitif tutar gir. ${_type == TransactionType.expense ? 'Gider listesinde' : 'Gelir listesinde'} işaret yerine tür bilgisi kullanılır.',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),
            _FieldLabel(label: _merchantLabel),
            const SizedBox(height: 8),
            TextField(
              controller: _merchantController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(hintText: _merchantHint),
              onChanged: (String value) {
                if (_type == TransactionType.expense && !_categoryTouched && value.trim().isNotEmpty) {
                  setState(() => _category = MerchantNormalizer.categoryFor(value));
                } else {
                  setState(() {});
                }
              },
            ),
            if (_type == TransactionType.expense && suggested.isNotEmpty) ...<Widget>[
              const SizedBox(height: 9),
              Row(
                children: <Widget>[
                  Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.accent(theme.brightness)),
                  const SizedBox(width: 6),
                  Text('Önerilen kategori: $suggested', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
            const SizedBox(height: 24),
            _FieldLabel(label: 'Kategori', trailing: _category),
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
                      setState(() {
                        _category = category;
                        _categoryTouched = true;
                      });
                    },
                    showCheckmark: false,
                    side: BorderSide(color: selected ? tone.withValues(alpha: 0.40) : theme.dividerColor.withValues(alpha: 0.75)),
                    selectedColor: tone.withValues(alpha: theme.brightness == Brightness.dark ? 0.18 : 0.12),
                    backgroundColor: AppColors.elevated(theme.brightness),
                    labelStyle: theme.textTheme.labelLarge?.copyWith(
                      color: selected ? tone : theme.colorScheme.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetaButton(
                    icon: Icons.calendar_today_outlined,
                    label: Formatters.relativeDate(_date),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetaButton(
                    icon: _type == TransactionType.expense ? Icons.credit_card_outlined : Icons.account_balance_wallet_outlined,
                    label: _type == TransactionType.expense ? '•••• 4832' : 'Banka hesabı',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _noteController,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Not · isteğe bağlı'),
            ),
            const SizedBox(height: 26),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: theme.scaffoldBackgroundColor),
                    )
                  : Text(_ctaLabel),
            ),
            const SizedBox(height: 9),
            Center(
              child: Text('Finansal kayıt cihazında saklanır.', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.trailing});
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        if (trailing != null) ...<Widget>[
          const Spacer(),
          Text(trailing!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _MetaButton extends StatelessWidget {
  const _MetaButton({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Ink(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: AppColors.elevated(theme.brightness),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.78), width: 0.75),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: AppColors.muted(theme.brightness)),
              const SizedBox(width: 9),
              Flexible(child: Text(label, style: theme.textTheme.labelLarge)),
            ],
          ),
        ),
      ),
    );
  }
}
