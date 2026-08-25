import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/motion/folio_motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/transaction_record.dart';
import '../../state/settings_controller.dart';
import '../../state/wallet_controller.dart';
import '../widgets/folio_background.dart';
import '../widgets/folio_wordmark.dart';
import '../widgets/money_pulse.dart';
import '../widgets/premium_surface.dart';

/// The first run: what Folio does, how to get data in, where to read it, and
/// one figure to start from.
///
/// The last step asks for income because every "what is left" number in the app
/// is income minus expense. A wallet holding only expenses reports a negative
/// balance and a savings rate of zero, which is not the user's situation — it
/// is just a number nobody gave it.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _controller = PageController();

  /// Plays once at launch so the first slide arrives too. Later slides are
  /// driven by their own position, by which time this has finished.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: FolioMotion.standard + _SlideIn.gap * _SlideIn.steps,
  )..forward();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  int _page = 0;
  bool _saving = false;
  String? _amountError;

  @override
  void dispose() {
    _intro.dispose();
    _controller.dispose();
    _amountController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).completeOnboarding();
    if (mounted) context.go('/');
  }

  Future<void> _saveIncomeAndFinish() async {
    if (_saving) return;

    // The refusal belongs under the field it is about. A snackbar sits over the
    // bottom of the screen, which is exactly where "Şimdilik geç" lives — it
    // hid the button it was telling the user to press.
    final bool blank = _amountController.text.trim().isEmpty;
    final double? amount = Formatters.parseMoneyInput(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _amountError = blank ? 'Bir tutar gir.' : 'Geçerli bir tutar gir.');
      return;
    }

    setState(() {
      _amountError = null;
      _saving = true;
    });
    final String source = _sourceController.text.trim();
    final String title = source.isEmpty ? 'Maaş' : source;

    await ref.read(walletProvider.notifier).addTransaction(
          TransactionRecord(
            id: const Uuid().v4(),
            title: title,
            merchant: title,
            category: _categoryFor(source),
            amount: amount,
            date: DateTime.now(),
            type: TransactionType.income,
            source: TransactionSource.manual,
            paymentLabel: AppConstants.defaultIncomeLabel,
          ),
        );
    await _finish();
  }

  /// Names the record after the source when the user typed one Folio knows.
  static String _categoryFor(String source) {
    if (source.isEmpty) return 'Maaş';
    final String canonical = source.toLowerCase();
    for (final String category in AppConstants.incomeCategories) {
      if (canonical.contains(category.toLowerCase())) return category;
    }
    return 'Maaş';
  }

  @override
  Widget build(BuildContext context) {
    final List<_OnboardingData> pages = <_OnboardingData>[
      const _OnboardingData(
        eyebrow: 'FOLİO NE YAPAR',
        title: 'Paranın nereye gittiğini gör.',
        body: 'Harcadığın, kazandığın ve ay sonunda sende kalan tek bir sakin '
            'görünümde toplanır.',
        visual: MoneyPulse(score: 82, size: 220),
      ),
      const _OnboardingData(
        eyebrow: 'VERİYİ NASIL EKLERSİN',
        title: 'Ekstreni aktar, fişini tarat.',
        body: 'Bankandan indirdiğin CSV, XLSX veya PDF ekstreyi okut; fişi '
            'kameraya göster; ya da alttaki + ile elle ekle.',
        visual: _ReceiptVisual(),
      ),
      const _OnboardingData(
        eyebrow: 'NEREDE OKURSUN',
        title: 'Doğru dönemi seç.',
        body: 'Ekstre çoğunlukla kapanmış bir dönemi kapsar. Üstteki dönem '
            'düğmesinden o aya geçince gelirin ve giderin oradadır.',
        visual: _PeriodVisual(),
      ),
      _OnboardingData(
        eyebrow: 'SON ADIM',
        title: 'Gelirini gir.',
        body: 'Tek bir gelir kaydı, sende ne kaldığını hesaplayabilmek için '
            'yeter. Sonra istediğin zaman değiştirebilirsin.',
        visual: _IncomeForm(
          amountController: _amountController,
          sourceController: _sourceController,
          errorText: _amountError,
          onAmountChanged: () {
            if (_amountError != null) setState(() => _amountError = null);
          },
        ),
      ),
    ];

    final bool onLastPage = _page == pages.length - 1;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: FolioBackground(
        accentAlignment: Alignment(_page.isEven ? 0.92 : -0.92, -0.78),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 0),
                child: Row(
                  children: <Widget>[
                    const FolioWordmark(),
                    const Spacer(),
                    TextButton(onPressed: _finish, child: const Text('Geç')),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (int value) {
                    HapticFeedback.selectionClick();
                    setState(() => _page = value);
                  },
                  itemBuilder: (BuildContext context, int index) {
                    final _OnboardingData data = pages[index];
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          _SlideIn(
                            page: _controller,
                            intro: _intro,
                            index: index,
                            step: 0,
                            child: SizedBox(height: 250, child: Center(child: data.visual)),
                          ),
                          const SizedBox(height: 30),
                          _SlideIn(
                            page: _controller,
                            intro: _intro,
                            index: index,
                            step: 1,
                            child: Text(
                              data.eyebrow,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                          const SizedBox(height: 13),
                          _SlideIn(
                            page: _controller,
                            intro: _intro,
                            index: index,
                            step: 2,
                            child: Text(
                              data.title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(fontSize: 35, height: 1.08),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SlideIn(
                            page: _controller,
                            intro: _intro,
                            index: index,
                            step: 3,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 410),
                              child: Text(
                                data.body,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 6, AppSpacing.page, 16),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(pages.length, (int index) {
                        final bool selected = index == _page;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: selected ? 22 : 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: selected
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).dividerColor,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _saving
                          ? null
                          : () {
                              if (onLastPage) {
                                _saveIncomeAndFinish();
                              } else {
                                _controller.nextPage(
                                  duration: const Duration(milliseconds: 340),
                                  curve: Curves.easeOutCubic,
                                );
                              }
                            },
                      child: Text(onLastPage ? 'Kaydet ve başla' : 'Devam et'),
                    ),
                    SizedBox(
                      height: 44,
                      child: onLastPage
                          ? TextButton(
                              onPressed: _saving ? null : _finish,
                              child: const Text('Şimdilik geç'),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fades and lifts one element of a slide into place.
///
/// Progress comes from how near the slide is to being centred, not from a
/// discrete "is showing" flag. A flag leaves the page the PageView has already
/// built sitting at zero opacity — a blank sheet for the whole of a swipe
/// towards it — and snaps it into view when the index finally flips. Reading
/// the position instead means an element is exactly as arrived as its slide is.
///
/// The pieces land in reading order: visual, label, headline, paragraph.
///
/// Only paint is animated, never layout, so nothing reflows mid-slide.
class _SlideIn extends StatelessWidget {
  const _SlideIn({
    required this.child,
    required this.page,
    required this.intro,
    required this.index,
    required this.step,
  });

  final Widget child;
  final PageController page;

  /// One-shot launch animation, so the first slide arrives rather than
  /// simply being there.
  final Animation<double> intro;

  /// Which slide this element belongs to.
  final int index;

  /// Position in the stagger, counted from the top of the slide.
  final int step;

  /// How much of the travel each following element waits out.
  static const double phase = 0.08;
  static const int steps = 3;
  static const Duration gap = Duration(milliseconds: 40);

  double _progress() {
    final double current = page.hasClients && page.positions.length == 1
        ? (page.page ?? page.initialPage.toDouble())
        : page.initialPage.toDouble();
    final double distance = (current - index).abs().clamp(0.0, 1.0);
    return 1 - distance;
  }

  @override
  Widget build(BuildContext context) {
    if (FolioMotion.reduce(context)) return child;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[page, intro]),
      child: child,
      builder: (BuildContext context, Widget? inner) {
        final double base = _progress() < intro.value ? _progress() : intro.value;
        final double start = step * phase;
        final double local = ((base - start) / (1 - start)).clamp(0.0, 1.0);
        final double eased = FolioMotion.enter.transform(local);

        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * 16),
            child: inner,
          ),
        );
      },
    );
  }
}

class _OnboardingData {
  const _OnboardingData({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.visual,
  });

  final String eyebrow;
  final String title;
  final String body;
  final Widget visual;
}

/// The one step of the tour that is a control rather than a picture.
class _IncomeForm extends StatelessWidget {
  const _IncomeForm({
    required this.amountController,
    required this.sourceController,
    required this.onAmountChanged,
    this.errorText,
  });

  final TextEditingController amountController;
  final TextEditingController sourceController;
  final VoidCallback onAmountChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: PremiumSurface(
        elevated: true,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Aylık gelirin', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              style: theme.textTheme.headlineSmall,
              onChanged: (_) => onAmountChanged(),
              decoration: InputDecoration(
                hintText: '0',
                suffixText: '₺',
                errorText: errorText,
              ),
            ),
            const SizedBox(height: 18),
            Text('Kaynak', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            TextField(
              controller: sourceController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(hintText: 'Maaş'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the period control, because an imported statement usually lands on a
/// month the dashboard is not showing and that is where people get lost.
class _PeriodVisual extends StatelessWidget {
  const _PeriodVisual();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 306),
      child: PremiumSurface(
        elevated: true,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.chevron_left_rounded,
                    size: 20, color: AppColors.muted(theme.brightness)),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
                  decoration: BoxDecoration(
                    color: AppColors.soft(theme.brightness),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    border: Border.all(color: theme.dividerColor, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('Temmuz 2026',
                          style: theme.textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 2),
                      Icon(Icons.expand_more_rounded,
                          size: 18, color: AppColors.ink(theme.brightness)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.muted(theme.brightness)),
              ],
            ),
            const SizedBox(height: 20),
            Text('66.200 ₺', style: theme.textTheme.displaySmall),
            const SizedBox(height: 4),
            Text('bu dönemde harcadın', style: theme.textTheme.bodySmall),
            const SizedBox(height: 18),
            Divider(height: 1, thickness: 0.7, color: theme.dividerColor),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Gelir', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text('62.000 ₺',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: AppColors.sage)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Sende kaldı', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text('−4.200 ₺', style: theme.textTheme.titleMedium),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptVisual extends StatelessWidget {
  const _ReceiptVisual();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Transform.rotate(
      angle: -0.045,
      child: PremiumSurface(
        elevated: true,
        radius: 22,
        padding: const EdgeInsets.fromLTRB(22, 23, 22, 24),
        child: SizedBox(
          width: 174,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('MİGROS', style: theme.textTheme.titleMedium),
              const SizedBox(height: 20),
              ...List<Widget>.generate(4, (int index) {
                return Container(
                  height: 4,
                  width: index == 3 ? 86 : double.infinity,
                  margin: const EdgeInsets.only(bottom: 9),
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
              const SizedBox(height: 14),
              Text('1.284,40 ₺', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('Market',
                    style: theme.textTheme.labelLarge?.copyWith(color: AppColors.sage)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
