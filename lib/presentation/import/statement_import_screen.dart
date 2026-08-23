import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../data/services/statement_parser.dart';
import '../../domain/models/transaction_record.dart';
import '../../state/wallet_controller.dart';
import '../widgets/brand_avatar.dart';
import '../widgets/folio_background.dart';
import '../widgets/folio_success.dart';
import '../widgets/premium_surface.dart';

class StatementImportScreen extends ConsumerStatefulWidget {
  const StatementImportScreen({super.key});

  @override
  ConsumerState<StatementImportScreen> createState() => _StatementImportScreenState();
}

enum _ImportStage { choose, parsing, review, imported }

class _StatementImportScreenState extends ConsumerState<StatementImportScreen> {
  final StatementParser _parser = const StatementParser();
  _ImportStage _stage = _ImportStage.choose;
  PlatformFile? _file;
  List<TransactionRecord> _transactions = <TransactionRecord>[];
  String _message = '';
  bool _demoFallback = false;

  Future<void> _pickFile() async {
    final PlatformFile? file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const <String>['csv', 'pdf', 'xlsx']);
    if (file == null || !mounted) return;
    setState(() {
      _file = file;
      _stage = _ImportStage.parsing;
    });
    final StatementParseResult parsed = await _parser.parse(file);
    if (!mounted) return;
    setState(() {
      _transactions = parsed.transactions;
      _message = parsed.message;
      _demoFallback = parsed.isDemoFallback;
      _stage = _ImportStage.review;
    });
  }

  Future<void> _import() async {
    if (_transactions.isEmpty) return;
    await ref.read(walletProvider.notifier).addTransactions(_transactions);
    if (!mounted) return;
    setState(() => _stage = _ImportStage.imported);
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (mounted) context.go('/transactions');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ekstre aktar'),
        leading: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded)),
      ),
      body: FolioBackground(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: switch (_stage) {
            _ImportStage.choose => _choose(context),
            _ImportStage.parsing => _parsing(context),
            _ImportStage.review => _review(context),
            _ImportStage.imported => _imported(context),
          },
        ),
      ),
    );
  }

  Widget _choose(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      key: const ValueKey<String>('choose'),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Ekstreni Folio’ya taşı', style: theme.textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text('Dosyanı seç; hareketleri ayrıştırıp içe aktarmadan önce sana göstereceğiz.', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 26),
              PremiumSurface(
                elevated: true,
                tint: AppColors.accent(theme.brightness).withValues(alpha: theme.brightness == Brightness.dark ? 0.08 : 0.035),
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(color: AppColors.accentSoft(theme.brightness), borderRadius: BorderRadius.circular(22)),
                      child: Icon(Icons.file_upload_outlined, color: AppColors.accent(theme.brightness), size: 28),
                    ),
                    const SizedBox(height: 20),
                    Text('CSV · XLSX · PDF', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 10),
                    Text('Kart veya banka ekstreni seç', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                    const SizedBox(height: 7),
                    Text('CSV ve XLSX cihazında ayrıştırılır. PDF dosyaları doğrulamalı önizlemeyle açılır.', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 22),
                    SizedBox(width: double.infinity, child: FilledButton(onPressed: _pickFile, child: const Text('Dosya seç'))),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              PremiumSurface(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.soft(theme.brightness), borderRadius: BorderRadius.circular(13)), alignment: Alignment.center, child: Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.muted(theme.brightness))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                      Text('Kontrol sende', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('İçe aktarmadan önce işlemleri inceleyebilir, kategorileri değiştirebilir ve istemediklerini kaldırabilirsin.', style: theme.textTheme.bodySmall),
                    ])),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _parsing(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      key: const ValueKey<String>('parsing'),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 410),
          child: PremiumSurface(
            elevated: true,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(width: 66, height: 66, decoration: BoxDecoration(color: AppColors.accentSoft(theme.brightness), borderRadius: BorderRadius.circular(22)), child: Icon(Icons.auto_awesome_rounded, color: AppColors.accent(theme.brightness), size: 25)),
                const SizedBox(height: 22),
                Text('Ekstre inceleniyor', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 7),
                Text(_file?.name ?? '', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                const SizedBox(height: 24),
                const _ProgressLine(label: 'Dosya açılıyor', done: true),
                const _ProgressLine(label: 'İşlemler ayrıştırılıyor', active: true),
                const _ProgressLine(label: 'Kategoriler hazırlanıyor'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _review(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double expenseTotal = _transactions.fold<double>(0, (double a, TransactionRecord b) => a + (b.isExpense ? b.amount : 0));
    final double incomeTotal = _transactions.fold<double>(0, (double a, TransactionRecord b) => a + (b.isIncome ? b.amount : 0));
    return Column(
      key: const ValueKey<String>('review'),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 14),
          child: PremiumSurface(
            elevated: true,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(children: <Widget>[
                  Expanded(child: Text('${_transactions.length} işlem bulundu', style: theme.textTheme.headlineMedium)),
                  TextButton(onPressed: _pickFile, child: const Text('Değiştir')),
                ]),
                const SizedBox(height: 6),
                Text(_message, style: theme.textTheme.bodySmall),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    SizedBox(width: 120, child: _ReviewMetric(label: 'İşlem', value: '${_transactions.length} adet')),
                    SizedBox(width: 150, child: _ReviewMetric(label: 'Gider', value: Formatters.money(expenseTotal))),
                    SizedBox(width: 150, child: _ReviewMetric(label: 'Gelir', value: Formatters.money(incomeTotal))),
                  ],
                ),
                if (_demoFallback) ...<Widget>[
                  const SizedBox(height: 12),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8), decoration: BoxDecoration(color: AppColors.amber.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(99)), child: Text('Önizleme modu', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.amber))),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 20),
            itemCount: _transactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              final TransactionRecord item = _transactions[index];
              return PremiumSurface(
                elevated: true,
                radius: 22,
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(children: <Widget>[
                  BrandAvatar(name: item.title, category: item.category),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Row(children: <Widget>[
                      Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium)),
                      Text(Formatters.money(item.amount), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 5),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: item.category,
                        isDense: true,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        style: theme.textTheme.bodySmall,
                        dropdownColor: AppColors.elevated(theme.brightness),
                        items: AppConstants.categories.map((String category) => DropdownMenuItem<String>(value: category, child: Text(category))).toList(growable: false),
                        onChanged: (String? value) {
                          if (value == null) return;
                          setState(() => _transactions[index] = item.copyWith(category: value));
                        },
                      ),
                    ),
                  ])),
                  IconButton(onPressed: () => setState(() => _transactions.removeAt(index)), icon: const Icon(Icons.close_rounded, size: 18), tooltip: 'İşlemi çıkar'),
                ]),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 18),
          child: FilledButton(onPressed: _transactions.isEmpty ? null : _import, child: Text('${_transactions.length} işlemi içe aktar')),
        ),
      ],
    );
  }

  Widget _imported(BuildContext context) {
    return const Center(key: ValueKey<String>('imported'), child: FolioSuccess(title: 'İçe aktarıldı', body: 'İşlemlerin görünümüne eklendi.'));
  }
}

class _ReviewMetric extends StatelessWidget {
  const _ReviewMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: AppColors.soft(theme.brightness), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 5),
        FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.label, this.done = false, this.active = false});
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = AppColors.accent(theme.brightness);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: <Widget>[
        SizedBox(width: 22, height: 22, child: done ? const Icon(Icons.check_rounded, size: 18, color: AppColors.sage) : active ? Padding(padding: const EdgeInsets.all(4), child: CircularProgressIndicator(strokeWidth: 1.7, color: accent)) : Icon(Icons.circle_outlined, size: 14, color: AppColors.tertiary(theme.brightness))),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
      ]),
    );
  }
}
