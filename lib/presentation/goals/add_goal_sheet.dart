import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/goal_record.dart';
import '../../state/wallet_controller.dart';
import '../widgets/folio_success.dart';

Future<void> showAddGoalSheet(
  BuildContext context, {
  GoalRecord? initialGoal,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (BuildContext context) => AddGoalSheet(initialGoal: initialGoal),
  );
}

class AddGoalSheet extends ConsumerStatefulWidget {
  const AddGoalSheet({this.initialGoal, super.key});

  final GoalRecord? initialGoal;

  @override
  ConsumerState<AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<AddGoalSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _targetAmountController;
  late final TextEditingController _savedAmountController;
  late final TextEditingController _noteController;
  late String _category;
  DateTime? _targetDate;
  bool _saving = false;
  bool _saved = false;

  static const List<String> _goalCategories = <String>[
    'Tasarruf',
    'Seyahat',
    'Teknoloji',
    'Ev',
    'Yatırım',
    'Eğitim',
    'Araç',
    'Diğer',
  ];

  @override
  void initState() {
    super.initState();
    final GoalRecord? goal = widget.initialGoal;
    _titleController = TextEditingController(text: goal?.title ?? '');
    _targetAmountController = TextEditingController(
      text: goal != null
          ? (goal.targetAmount % 1 == 0
              ? goal.targetAmount.toStringAsFixed(0)
              : goal.targetAmount.toStringAsFixed(2).replaceAll('.', ','))
          : '',
    );
    _savedAmountController = TextEditingController(
      text: goal != null
          ? (goal.savedAmount % 1 == 0
              ? goal.savedAmount.toStringAsFixed(0)
              : goal.savedAmount.toStringAsFixed(2).replaceAll('.', ','))
          : '0',
    );
    _noteController = TextEditingController(text: goal?.note ?? '');
    _category = goal?.category ?? _goalCategories.first;
    _targetDate = goal?.targetDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetAmountController.dispose();
    _savedAmountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String title = _titleController.text.trim();
    final double? target = Formatters.parseMoneyInput(_targetAmountController.text);
    final double saved = Formatters.parseMoneyInput(_savedAmountController.text) ?? 0.0;

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hedef için bir isim gir.')),
      );
      return;
    }
    if (target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir hedef tutarı gir.')),
      );
      return;
    }

    setState(() => _saving = true);
    final GoalRecord goal = GoalRecord(
      id: widget.initialGoal?.id ?? const Uuid().v4(),
      title: title,
      targetAmount: target,
      savedAmount: saved,
      category: _category,
      targetDate: _targetDate,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );

    await ref.read(walletProvider.notifier).saveGoal(goal);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _saving = false;
      _saved = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final ThemeData theme = Theme.of(context);
    final bool isEdit = widget.initialGoal != null;

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
            ? FolioSuccess(
                height: 380,
                title: isEdit ? 'Hedef Güncellendi' : 'Hedef Oluşturuldu',
                body: 'Birikim hedefin planına eklendi.',
              )
            : ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.94,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
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
                              isEdit ? 'Hedefi Düzenle' : 'Yeni Birikim Hedefi',
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
                        'Ulaşmak istediğin tutarı ve hedef tarihini belirle.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 22),
                      Text('HEDEF TUTAR', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 8),
                      Center(
                        child: TextField(
                          controller: _targetAmountController,
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
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text('HEDEF İSMİ', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          hintText: 'Örn: Acil Durum Fonu, Yaz Tatili, Yeni Bilgisayar',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('ŞU ANKİ BİRİKİM', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _savedAmountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          hintText: '0 ₺',
                          suffixText: '₺',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('KATEGORİ', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _goalCategories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (BuildContext context, int index) {
                            final String category = _goalCategories[index];
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
                      Text('HEDEF TARİHİ', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 90)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                          );
                          if (picked != null) setState(() => _targetDate = picked);
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
                              Text(
                                _targetDate == null
                                    ? 'Hedef tarihi belirle (isteğe bağlı)'
                                    : Formatters.fullDate(_targetDate!),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: _targetDate == null
                                      ? AppColors.muted(theme.brightness)
                                      : null,
                                ),
                              ),
                              if (_targetDate != null) ...<Widget>[
                                const Spacer(),
                                IconButton(
                                  onPressed: () => setState(() => _targetDate = null),
                                  icon: const Icon(Icons.close_rounded, size: 16),
                                ),
                              ],
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
                        decoration: const InputDecoration(hintText: 'Açıklama / hedef detayı'),
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
                            : Text(isEdit ? 'Hedefi Kaydet' : 'Hedefi Başlat'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
