import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../state/settings_controller.dart';
import '../widgets/folio_background.dart';
import '../widgets/folio_wordmark.dart';
import '../widgets/money_pulse.dart';
import '../widgets/premium_surface.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).completeOnboarding();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final List<_OnboardingData> pages = <_OnboardingData>[
      _OnboardingData(
        eyebrow: 'FİNANSAL NETLİK',
        title: 'Paranı daha net gör.',
        body: 'Harcadığın, kazandığın ve sende kalan tek bir sakin görünümde.',
        visual: const MoneyPulse(score: 82, size: 220),
      ),
      _OnboardingData(
        eyebrow: 'DAHA AZ MANUEL İŞ',
        title: 'Fişi göster. Gerisini Folio toplasın.',
        body: 'Fiş ve ekstre akışları harcamalarını hızlıca görünür hale getirir.',
        visual: const _ReceiptVisual(),
      ),
      _OnboardingData(
        eyebrow: 'DAVRANIŞI GÖR',
        title: 'Rakam değil, değişim gör.',
        body: 'Tekrar eden giderleri ve harcama ritmini kısa, anlaşılır içgörülere çevir.',
        visual: const _InsightVisual(),
      ),
    ];

    return Scaffold(
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
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          SizedBox(height: 260, child: Center(child: data.visual)),
                          const SizedBox(height: 34),
                          Text(data.eyebrow, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium),
                          const SizedBox(height: 13),
                          Text(
                            data.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 35, height: 1.08),
                          ),
                          const SizedBox(height: 16),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 410),
                            child: Text(data.body, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 6, AppSpacing.page, 22),
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
                            color: selected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).dividerColor,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: () {
                        if (_page == pages.length - 1) {
                          _finish();
                        } else {
                          _controller.nextPage(duration: const Duration(milliseconds: 340), curve: Curves.easeOutCubic);
                        }
                      },
                      child: Text(_page == pages.length - 1 ? 'Folio’yu aç' : 'Devam et'),
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

class _OnboardingData {
  const _OnboardingData({required this.eyebrow, required this.title, required this.body, required this.visual});
  final String eyebrow;
  final String title;
  final String body;
  final Widget visual;
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
            children: <Widget>[
              Text('MİGROS', style: theme.textTheme.titleMedium),
              const SizedBox(height: 20),
              ...List<Widget>.generate(4, (int index) {
                return Container(
                  height: 4,
                  width: index == 3 ? 86 : double.infinity,
                  margin: const EdgeInsets.only(bottom: 9),
                  decoration: BoxDecoration(color: theme.dividerColor.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(99)),
                );
              }),
              const SizedBox(height: 14),
              Text('1.284,40 ₺', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.sage.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(99)),
                child: Text('Market', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.sage)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightVisual extends StatelessWidget {
  const _InsightVisual();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tone = AppColors.sage;
    return Container(
      width: 306,
      padding: const EdgeInsets.fromLTRB(22, 21, 22, 23),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[tone.withValues(alpha: 0.10), tone.withValues(alpha: 0.035)],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: tone.withValues(alpha: 0.08), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.auto_awesome_rounded, color: tone, size: 18),
          const SizedBox(height: 17),
          Text('Harcama ritmin yavaşladı.', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Bu ay giderin geçen aya göre daha düşük ilerliyor.', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text('−7,4%', style: theme.textTheme.headlineMedium?.copyWith(color: tone, letterSpacing: -0.7)),
        ],
      ),
    );
  }
}
